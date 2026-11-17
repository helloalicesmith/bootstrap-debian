#!/usr/bin/env bash
# Debian 13 workstation bootstrap. Run from a permanent local Git clone.
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
case "${1:-}" in
'') ;;
--help | -h)
  printf '%s\n' 'Usage: bash bootstrap.sh' 'Run as a regular user. Requires Debian 13, Internet, Git and working sudo.' 'No backups or dotfile overwrites. Installs upstream Neovim and Yazi, then deploys configuration.'
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
# shellcheck source=lib/yazi.sh
source "$ROOT/lib/yazi.sh"
trap cleanup EXIT
trap 'printf "\nInstallation failed at line %s in %s. Earlier changes remain; no automatic rollback.\n" "$LINENO" "${BASH_SOURCE[0]}" >&2' ERR
preflight
collect_dotfiles
check_services
check_neovim
check_yazi
build_packages
log 'Installation plan'
printf 'Repository: %s\nUser: %s\n' "$ROOT" "$(id -un)"
printf 'Packages: %s\n' "${PACKAGES[*]}"
printf 'Link: %s\n' "${LINKS[@]}"
printf '%s\n' 'Configure greetd/tuigreet, PipeWire, NetworkManager and Bluetooth; set Zsh.' 'Install latest stable Neovim into ~/.local/opt/neovim and Yazi into ~/.local/opt/yazi.'
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
install_yazi
link_dotfiles
configure_user
configure_services
log 'Installation complete'
printf '%s\n' 'Reboot when convenient and log in through tuigreet.' 'No automatic reboot. Package installation may start services.'
printf 'Log: %s\n' "$LOG"
