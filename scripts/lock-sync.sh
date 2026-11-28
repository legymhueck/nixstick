#!/usr/bin/env bash
# Update all flake inputs of ~/nixos, then pin nixpkgs, Mango and hylki to the
# revisions in the main repo's flake.lock (legymhueck/nixos). Its CI pushes
# Mango for exactly that lock to the Cachix cache nixbox-m (common/base.nix),
# so the stick downloads Mango instead of compiling it. Then switches.
#
#   lock-sync                     # main repo's lock from GitHub (gh), then switch
#   lock-sync --no-switch         # only update flake.lock
#   lock-sync ~/GitHub/nixos/flake.lock   # use a local copy of the main lock
set -euo pipefail

switch=1
lock=""
for arg in "$@"; do
  case $arg in
    --no-switch) switch=0 ;;
    -h | --help)
      echo "usage: lock-sync [--no-switch] [path/to/main/flake.lock]"
      exit 0
      ;;
    *) lock=$arg ;;
  esac
done

repo="$HOME/nixos"
cd "$repo" || exit 1
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

if [[ -n $lock ]]; then
  cp -- "$lock" "$tmp"
elif ! gh api -H 'Accept: application/vnd.github.raw' repos/legymhueck/nixos/contents/flake.lock >"$tmp" 2>/dev/null; then
  if [[ -f $HOME/GitHub/nixos/flake.lock ]]; then
    echo "GitHub not reachable (gh auth login?), using ~/GitHub/nixos/flake.lock" >&2
    cp -- "$HOME/GitHub/nixos/flake.lock" "$tmp"
  else
    echo "cannot read the main repo's flake.lock (gh auth login, or pass a path)" >&2
    exit 1
  fi
fi

# github:<owner>/<repo>/<rev> of a root input in the main lock.
pin() {
  jq -er --arg n "$1" \
    '.nodes[.nodes.root.inputs[$n]].locked | "github:\(.owner)/\(.repo)/\(.rev)"' "$tmp"
}
nixpkgs=$(pin nixpkgs)
mango=$(pin mango)
hylki=$(pin hylki-src)

echo "==> Updating all inputs"
nix flake update
echo "==> Pinning nixpkgs, Mango and hylki to the main repo (cached builds)"
echo "    $nixpkgs"
echo "    $mango"
echo "    $hylki"
nix flake lock --override-input nixpkgs "$nixpkgs" --override-input mango "$mango" \
  --override-input hylki-src "$hylki"

if ((switch)); then
  nh os switch
else
  echo "flake.lock updated; apply with: rebuild"
fi
