#!/usr/bin/env bash
# Debian 13 dotfiles bootstrap. Run as the desktop user, NOT with sudo.
# Layout: REPO/home/.zshrc, REPO/home/.config/sway/config, etc.
# Usage: bash bootstrap.sh [--repo-dir PATH] [--with-nvm] [--set-zsh]
# Existing clones are intentionally NOT pulled automatically.
set -Eeuo pipefail
trap 'printf "\nERROR at line %s. Setup stopped; existing backups are retained.\n" "$LINENO" >&2' ERR

REPO_URL='https://github.com/helloalicesmith/bootstrap-debian.git'
REPO_DIR="$HOME/.local/share/bootstrap-debian"
WITH_NVM=0
SET_ZSH=0
NVM_VERSION='v0.41.0'

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}
help_text() {
  cat <<'HELP'
Usage: bash bootstrap.sh [options]
  --repo-dir PATH  Use/clone the dotfiles repository here (absolute path).
  --with-nvm      Install NVM v0.41.0 if absent; does not install Node.js.
  --set-zsh       Change your login shell to Zsh after deployment.
  --help          Show this help.

Run as your normal desktop user. Sudo is used only for APT.
Default clone: ~/.local/share/bootstrap-debian
No git pull, distro upgrade, GNOME removal, display-manager changes,
automatic Sway reload, or automatic execution of deployed shell configs.
Review repository contents before running. Dotfiles execute code when used.
HELP
}
while (($#)); do
  case "$1" in
  --repo-dir)
    (($# >= 2)) || die '--repo-dir requires a path'
    REPO_DIR="$2"
    shift 2
    ;;
  --with-nvm)
    WITH_NVM=1
    shift
    ;;
  --set-zsh)
    SET_ZSH=1
    shift
    ;;
  --help | -h)
    help_text
    exit 0
    ;;
  *) die "Unknown argument: $1" ;;
  esac
done

((EUID != 0)) || die 'Do not run this script as root or with sudo.'
[[ "$REPO_DIR" = /* ]] || die '--repo-dir must be an absolute path.'
[[ -r /etc/os-release ]] || die '/etc/os-release not found.'
# shellcheck disable=SC1091
. /etc/os-release
[[ "${ID:-}" = debian && "${VERSION_ID:-}" = 13 ]] || die 'This script supports Debian 13 (trixie) only.'
command -v sudo >/dev/null || die 'sudo is required. Ask the administrator to install/configure it.'
[[ "${XDG_CONFIG_HOME:-$HOME/.config}" = "$HOME/.config" ]] || die 'Custom XDG_CONFIG_HOME is not supported by this home/ layout.'
[[ "${ZDOTDIR:-$HOME}" = "$HOME" ]] || die 'Custom ZDOTDIR is not supported by this layout.'

log 'Install basic Git/HTTPS dependencies (APT will ask for confirmation)'
sudo apt-get update
sudo apt-get --no-remove install git ca-certificates curl

if [[ -e "$REPO_DIR" || -L "$REPO_DIR" ]]; then
  [[ -d "$REPO_DIR/.git" ]] || die "Not a regular Git clone: $REPO_DIR"
  origin=$(git -C "$REPO_DIR" remote get-url origin)
  case "$origin" in
  https://github.com/helloalicesmith/bootstrap-debian | https://github.com/helloalicesmith/bootstrap-debian.git | git@github.com:helloalicesmith/bootstrap-debian.git) ;;
  *) die "Unexpected origin: $origin" ;;
  esac
  log 'Using existing clone without pulling or overwriting local changes'
else
  mkdir -p -- "$(dirname -- "$REPO_DIR")"
  git clone -- "$REPO_URL" "$REPO_DIR"
fi
REPO_DIR=$(realpath -- "$REPO_DIR")
SOURCE="$REPO_DIR/home"
[[ -d "$SOURCE" && ! -L "$SOURCE" ]] || die 'Missing home/ directory. Populate and push the repository first (see chat instructions).'

# Only these known config locations may be deployed. No .ssh, tokens or history.
ROOTS=(.zshrc .tmux.conf .vimrc .config/sway .config/waybar .config/mako .config/kitty .config/fuzzel .config/nvim)
FILES=()
for rel in "${ROOTS[@]}"; do
  src="$SOURCE/$rel"
  if [[ -L "$src" ]]; then
    die "Source symlink not accepted: $src. Store actual file contents in Git."
  elif [[ -f "$src" ]]; then
    FILES+=("$rel")
  elif [[ -d "$src" ]]; then
    while IFS= read -r -d '' item; do
      [[ ! -L "$item" ]] || die "Source symlink not accepted: $item"
      [[ -f "$item" ]] || continue
      FILES+=("${item#"$SOURCE/"}")
    done < <(find "$src" \( -type f -o -type l \) -print0)
  fi
done
((${#FILES[@]})) || die 'No supported configuration files in home/.'
[[ -f "$SOURCE/.config/sway/config" ]] || die 'home/.config/sway/config is required.'
# Refuse linked parent directories to avoid writing through unrelated links.
for rel in "${FILES[@]}"; do
  parent=$(dirname -- "$HOME/$rel")
  while [[ "$parent" != "$HOME" && "$parent" != / ]]; do
    [[ ! -L "$parent" ]] || die "Destination parent is a symlink: $parent. Review/migrate it manually first."
    [[ ! -e "$parent" || -d "$parent" ]] || die "Destination parent is not a directory: $parent"
    parent=$(dirname -- "$parent")
  done
done

log 'Files to deploy as symlinks'
printf '  %s\n' "${FILES[@]}"
printf '\nRepository: %s\n' "$REPO_DIR"
read -r -p 'Install packages and deploy these configs? [y/N] ' answer
[[ "$answer" = y || "$answer" = Y ]] || exit 0

# Debian 13: mate-polkit replaces unavailable policykit-1-gnome.
# Waybar is installed as a package, not compiled: no Meson/-dev packages needed.
PACKAGES=(
  sway swaybg swayidle swaylock
  kitty fuzzel waybar xwayland
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk
  mate-polkit libnotify-bin mako-notifier
  grim slurp wl-clipboard brightnessctl wev
  fonts-font-awesome fonts-dejavu-core fontconfig pavucontrol
  wireplumber libpam-systemd
  vim tmux zsh
)
# Neovim is optional: install the Debian version only if its config is present.
if [[ -d "$SOURCE/.config/nvim" ]]; then
  PACKAGES+=(neovim ripgrep fd-find unzip build-essential)
fi
log 'Install desktop/editor packages; removal of packages is prohibited'
sudo apt-get --no-remove install "${PACKAGES[@]}"

if [[ -f "$SOURCE/.zshrc" ]]; then
  if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    log 'Keeping existing Oh My Zsh'
  elif [[ -e "$HOME/.oh-my-zsh" || -L "$HOME/.oh-my-zsh" ]]; then
    die '~/.oh-my-zsh exists but does not contain oh-my-zsh.sh; review manually.'
  else
    log 'Clone Oh My Zsh without running its installer or changing .zshrc'
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi
  zsh -n "$SOURCE/.zshrc"
fi

if ((WITH_NVM)); then
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    log 'Keeping existing NVM (no automatic upgrade)'
  elif [[ -e "$HOME/.nvm" || -L "$HOME/.nvm" ]]; then
    die '~/.nvm already exists but nvm.sh is missing; review manually.'
  else
    log "Install NVM $NVM_VERSION without modifying shell configs"
    git clone --depth 1 --branch "$NVM_VERSION" https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
  fi
fi

# Each replaced file/directory is moved to a private, unique backup folder.
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/bootstrap-debian"
mkdir -p -- "$STATE_ROOT"
BACKUP=$(mktemp -d "$STATE_ROOT/backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")
chmod 700 "$BACKUP"
printf 'destination\tsource\tprevious_location\n' >"$BACKUP/manifest.tsv"
log "Deploy configs. Backup and manifest: $BACKUP"
for rel in "${FILES[@]}"; do
  src="$SOURCE/$rel"
  dst="$HOME/$rel"
  if [[ -L "$dst" ]] && [[ "$(readlink -- "$dst")" = "$src" ]]; then
    printf 'Already linked: %s\n' "$dst"
    continue
  fi
  old='-'
  if [[ -e "$dst" || -L "$dst" ]]; then
    old="$BACKUP/home/$rel"
    mkdir -p -- "$(dirname -- "$old")"
    mv -- "$dst" "$old"
  fi
  mkdir -p -- "$(dirname -- "$dst")"
  if ! ln -s -- "$src" "$dst"; then
    if [[ "$old" != '-' ]]; then mv -- "$old" "$dst"; fi
    die "Failed to link $dst; earlier changes are recorded in $BACKUP"
  fi
  printf '%s\t%s\t%s\n' "$dst" "$src" "$old" >>"$BACKUP/manifest.tsv"
  printf 'Linked: %s\n' "$dst"
done

fc-cache -f
log 'Validate Sway config (no reload)'
if ! sway --validate --config "$HOME/.config/sway/config" >"$BACKUP/sway-validation.log" 2>&1; then
  cat "$BACKUP/sway-validation.log" >&2
  printf '\nWARNING: Sway validation failed. Do NOT reload until fixed.\nBackups: %s\n' "$BACKUP" >&2
  exit 1
fi

if ((SET_ZSH)); then
  [[ -f "$HOME/.zshrc" ]] || die 'Cannot set Zsh: .zshrc was not deployed.'
  log 'Change login shell to Zsh (may request your password)'
  chsh -s /usr/bin/zsh
fi

log 'Deployment complete'
printf 'Repository: %s\nBackups: %s\n' "$REPO_DIR" "$BACKUP"
printf '%s\n' \
  'GNOME/GDM, APT sources and running desktop services were not changed.' \
  'Existing files not listed above were left untouched.' \
  'Review the configs, then log out and select Sway at the login screen.' \
  'Do not delete or move the clone: your config symlinks point into it.' \
  'Changes made through these symlinks modify the local Git working tree.' \
  'Nerd Fonts, Vim/Neovim plugins and external tmux plugins are not installed.' \
  'A PATH entry for /opt/nvim-linux-x86_64 does not install that Neovim build.'
if [[ -f "$HOME/.zshrc" && ! -s "$HOME/.nvm/nvm.sh" ]]; then
  printf '%s\n' 'NVM was not installed. Use --with-nvm if needed; guarded .zshrc lines are safe without it.'
fi
