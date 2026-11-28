{
  description = "minimal NixOS workstation configuration (MangoWM + Noctalia)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # No nixpkgs.follows: the Noctalia Cachix cache only matches its own pin.
    noctalia.url = "github:noctalia-dev/noctalia";
    noctalia_official_plugins = {
      url = "github:noctalia-dev/official-plugins";
      flake = false;
    };
    noctalia_community_plugins = {
      url = "github:noctalia-dev/community-plugins";
      flake = false;
    };
    # hylki (mail client), packaged like the main repo (pkgs/hylki). lock-sync
    # pins it to the main repo's revision, so the derivation is identical and
    # comes from the nixbox-m cache instead of a local Rust build.
    hylki-src = {
      url = "github:hyprlab/hylki";
      flake = false;
    };
    # Prebuilt nix-index database for `, <program>` (comma) and command-not-found.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      vars = import ./common/vars.nix;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # One directory per installation: hosts/<hostname>/ holds the generated
      # hardware-configuration.nix and optionally host.nix (settings for that
      # stick only). install.sh creates it, so installing a second stick never
      # touches the files of the first one.
      hostNames = builtins.attrNames (
        lib.filterAttrs (
          name: type:
          type == "directory" && builtins.pathExists (./hosts + "/${name}/hardware-configuration.nix")
        ) (builtins.readDir ./hosts)
      );

      # Only for the `-eval` output: stands in for the generated hardware
      # module so the checkout evaluates without it (CI, `nix flake check`).
      # It is never part of the real configuration, so a missing hardware
      # module there fails loudly instead of producing an unbootable system.
      evaluationHardware = {
        fileSystems = lib.genAttrs vars.btrfsMounts (_: {
          device = "/dev/null";
          fsType = "btrfs";
        });
        boot.initrd.luks.devices.cryptroot.device = "/dev/null";
      };

      mkSystem =
        {
          # null: the evaluation twin (no hardware module, name vars.project).
          host ? null,
        }:
        let
          hostDir = ./hosts + "/${host}";
          hostModule = hostDir + "/host.nix";
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs vars; };
          modules = [
            ./nixos-mango/configuration.nix
            (if host == null then evaluationHardware else hostDir + "/hardware-configuration.nix")
            {
              # `nh os switch` / `nixos-rebuild --flake .` pick the entry by hostname.
              networking.hostName = if host == null then vars.project else host;
            }
            home-manager.nixosModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                backupFileExtension = "bak";
                extraSpecialArgs = { inherit inputs vars; };
                users.${vars.user} = ./nixos-mango/home.nix;
              };
            }
          ]
          ++ lib.optional (host != null && builtins.pathExists hostModule) hostModule;
        };

    in
    {
      formatter.${system} = pkgs.nixfmt-tree;

      nixosConfigurations =
        # One real configuration per installed stick in hosts/.
        lib.genAttrs hostNames (host: mkSystem { inherit host; })
        # Evaluation-only twin for CI and `nix eval`; never deploy this.
        // {
          "${vars.project}-eval" = mkSystem { };
        };

      # Tools for working on this repository: `nix develop`.
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          deadnix
          nixfmt
          shellcheck
          shfmt
          statix
        ];
      };

      checks.${system}.lint =
        pkgs.runCommandLocal "lint"
          {
            nativeBuildInputs = with pkgs; [
              deadnix
              shellcheck
              shfmt
              statix
            ];
          }
          ''
            cd ${self}
            statix check .
            deadnix --fail --exclude "**/hardware-configuration.nix" .
            shellcheck install.sh scripts/*.sh docs/tips/*.sh
            shfmt -d -i 2 -ci install.sh scripts/*.sh docs/tips/*.sh
            touch $out
          '';
    };
}
