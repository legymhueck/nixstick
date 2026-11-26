#!/usr/bin/env bash
# Set up the Debian VM of Android's Linux Terminal (Pixel 6). Idempotent: safe to run again.
# Copy it to the phone:       adb push docs/tips/phone-debian-setup.sh /sdcard/Download/vm/setup.sh
# Start inside the terminal:  bash /mnt/shared/Download/vm/setup.sh
# Log: /mnt/shared/Download/vm/setup.log (phone: Download/vm/setup.log)
# Afterwards, once:           sudo tailscale up --hostname=pixel-debian  (open the printed link)
# and add ~/.ssh/id_ed25519.pub to ~/.ssh/authorized_keys of michael on the Pi.
# Guide: docs/tips/phone.typ, section "Linux Terminal (Debian)".
set -uo pipefail

log=/mnt/shared/Download/vm/setup.log
exec > >(tee "$log") 2>&1
step() { printf '\n==> %s\n' "$*"; }
export DEBIAN_FRONTEND=noninteractive

step "Basics"
date
cat /etc/debian_version
uname -rm
id
if sudo -n true; then
  echo "sudo: ok without password"
else
  echo "sudo needs a password, stopping"
  exit 1
fi
ps -p 1 -o comm=
ls -l /dev/net/tun 2>&1

step "apt update + full-upgrade"
sudo apt-get update
sudo apt-get -y -o Dpkg::Options::=--force-confold full-upgrade

step "Packages"
sudo apt-get -y install --no-install-recommends \
  git curl wget rsync ca-certificates gnupg \
  tmux htop ncdu tree less man-db bash-completion \
  neovim ripgrep fd-find jq unzip zip \
  python3 python3-venv python3-pip \
  dnsutils iputils-ping openssh-client \
  locales tzdata unattended-upgrades
# Debian names fd "fdfind"
mkdir -p ~/.local/bin
ln -sf /usr/bin/fdfind ~/.local/bin/fd

step "Locale (English, German formats) and time zone"
sudo sed -i -E 's/^# *(en_US.UTF-8|de_DE.UTF-8)/\1/' /etc/locale.gen
sudo locale-gen
sudo update-locale LANG=en_US.UTF-8 LC_TIME=de_DE.UTF-8 LC_NUMERIC=de_DE.UTF-8 \
  LC_MEASUREMENT=de_DE.UTF-8 LC_PAPER=de_DE.UTF-8
sudo ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
echo Europe/Berlin | sudo tee /etc/timezone >/dev/null
date

step "Automatic security updates"
echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
systemctl is-enabled apt-daily-upgrade.timer 2>&1

step "Tailscale (official repository)"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg |
    sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list |
    sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
  sudo apt-get update
  sudo apt-get -y install tailscale
fi
if [[ ! -c /dev/net/tun ]]; then
  echo "no /dev/net/tun: tailscaled in userspace mode"
  sudo sed -i 's/^FLAGS=.*/FLAGS="--tun=userspace-networking"/' /etc/default/tailscaled
fi
sudo systemctl enable --now tailscaled
sudo systemctl restart tailscaled
sleep 2
tailscale version | head -1
tailscale status 2>&1 | head -3

step "SSH key and ssh rpi"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
[[ -f ~/.ssh/id_ed25519 ]] || ssh-keygen -t ed25519 -N '' -C 'droid@pixel-debian' -f ~/.ssh/id_ed25519
proxy=""
[[ -c /dev/net/tun ]] || proxy="  ProxyCommand tailscale nc %h %p"
cat >~/.ssh/config <<EOF
# Raspberry Pi over Tailscale (main repo nixos: docs/setup/raspberry-pi.typ)
Host rpi
  HostName rpi.bone-vibes.ts.net
  User michael
$proxy
EOF
chmod 600 ~/.ssh/config
echo "public key:"
cat ~/.ssh/id_ed25519.pub

step "Shell"
if ! grep -q 'pixel-debian setup' ~/.bashrc; then
  cat >>~/.bashrc <<'EOF'

# --- pixel-debian setup ---
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nvim VISUAL=nvim
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
alias ll='ls -alh --color=auto'
alias ..='cd ..'
alias vim=nvim
alias update='sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y'
# the phone's storage
alias phone='cd /mnt/shared'
EOF
fi

step "Clean up"
sudo apt-get -y autoremove
sudo apt-get clean
df -h /
free -h
echo "DONE"
