#!/usr/bin/env bash
# Debian 13 workstation bootstrap. Run from a permanent local Git clone.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
DRY_RUN=0
case "${1:-}" in
'') ;;
--dry-run) DRY_RUN=1 ;;
--help | -h)
  printf '%s\n' 'Usage: bash bootstrap.sh [--dry-run]' 'Run as a regular user. Requires Debian 13, Internet, Git and working sudo.' 'No backups or dotfile overwrites. Installs upstream Neovim and deploys its config.'
  exit 0
  ;;
*)
  printf 'Unknown option: %s\n' "$1" >&2
  exit 2
  ;;
esac
(($# <= 1)) || {
  printf 'Too many arguments.\n' >&2
  exit 2
}
# shellcheck source=lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=lib/packages.sh
source "$ROOT/lib/packages.sh"
# shellcheck source=lib/dotfiles.sh
source "$ROOT/lib/dotfiles.sh"
# shellcheck source=lib/services.sh
source "$ROOT/lib/services.sh"
# shellcheck source=lib/neovim.sh
source "$ROOT/lib/neovim.sh"
trap cleanup EXIT
trap 'printf "\nInstallation failed at line %s in %s. Earlier changes remain; no automatic rollback.\n" "$LINENO" "${BASH_SOURCE[0]}" >&2' ERR
preflight
collect_dotfiles
check_services
check_neovim
build_packages
log 'Installation plan'
printf 'Repository: %s\nUser: %s\n' "$ROOT" "$(id -un)"
printf 'Packages: %s\n' "${PACKAGES[*]}"
printf 'Link: %s\n' "${LINKS[@]}"
printf '%s\n' 'Configure greetd/tuigreet, PipeWire, NetworkManager and Bluetooth; set Zsh.' 'Install latest stable Neovim into ~/.local/opt/neovim.'
if ((DRY_RUN)); then
  log 'Dry run complete: no sudo, downloads, file writes or service changes.'
  printf '%s\n' 'Local checks only: package availability and runtime behavior are not verified.'
  exit 0
fi
read -r -p 'Install on this Debian 13 system? [y/N] ' answer
[[ "$answer" == y || "$answer" == Y ]] || exit 0
sudo -v
mkdir -p "$HOME/.local/state/bootstrap-debian"
LOG="$HOME/.local/state/bootstrap-debian/install-$(date +%Y%m%d-%H%M%S)-$$.log"
(
  umask 077
  : >"$LOG"
)
exec > >(tee -a "$LOG") 2>&1
log "Installation log: $LOG"
install_packages
install_ohmyzsh
install_neovim
link_dotfiles
configure_user
configure_services
log 'Installation complete'
printf '%s\n' 'Reboot when convenient and log in through tuigreet.' 'Keep this repository in place: your dotfiles are symlinks into home/.' 'No NVM, Node.js, .vimrc deployment or shared theme generator.' 'Repeated runs keep the managed Neovim version; no automatic upgrades.' 'No automatic reboot. Package installation may start services.'
printf 'Log: %s\n' "$LOG"
