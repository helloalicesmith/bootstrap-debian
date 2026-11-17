#!/usr/bin/env bash
# Save as lib/neovim.sh. Sourced by bootstrap.sh.
check_neovim() {
  case "$(uname -m)" in
  x86_64) NVIM_PLATFORM=linux-x86_64 ;;
  aarch64 | arm64) NVIM_PLATFORM=linux-arm64 ;;
  *) die "Unsupported Neovim architecture: $(uname -m)" ;;
  esac
  NVIM_DIR="$HOME/.local/opt/neovim"
  NVIM_LINK="$HOME/.local/bin/nvim"
  local parent
  for parent in "$HOME/.local" "$HOME/.local/opt" "$HOME/.local/bin"; do
    [[ ! -L "$parent" ]] || die "Installation parent is a symlink: $parent"
    [[ ! -e "$parent" || -d "$parent" ]] || die "Not a directory: $parent"
  done
  if [[ -e "$NVIM_DIR" || -L "$NVIM_DIR" ]]; then
    [[ -d "$NVIM_DIR" && ! -L "$NVIM_DIR" && -f "$NVIM_DIR/.bootstrap-managed" && -x "$NVIM_DIR/bin/nvim" ]] || die "Unmanaged or incomplete Neovim installation: $NVIM_DIR"
  fi
  if [[ -e "$NVIM_LINK" || -L "$NVIM_LINK" ]]; then
    [[ -L "$NVIM_LINK" && "$(readlink -- "$NVIM_LINK")" == "$NVIM_DIR/bin/nvim" ]] || die "Conflicting launcher: $NVIM_LINK"
  fi
  [[ -f "$ROOT/home/.config/nvim/init.lua" || -f "$ROOT/home/.config/nvim/init.vim" ]] || die 'Missing home/.config/nvim/init.lua or init.vim.'
}
install_neovim() {
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
  if [[ -f "$NVIM_DIR/.bootstrap-managed" ]]; then
    log 'Keeping the existing managed Neovim installation'
    if [[ ! -L "$NVIM_LINK" ]]; then ln -sT -- "$NVIM_DIR/bin/nvim" "$NVIM_LINK"; fi
    return
  fi
  log 'Installing the latest stable upstream Neovim release'
  (
    set -Eeuo pipefail
    work=$(mktemp -d "$HOME/.local/opt/.neovim-install-XXXXXX")
    trap 'rm -rf -- "$work"' EXIT
    curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 120 --proto '=https' \
      https://api.github.com/repos/neovim/neovim/releases/latest -o "$work/release.json"
    tag=$(jq -er '.tag_name' "$work/release.json")
    name="nvim-${NVIM_PLATFORM}.tar.gz"
    url=$(jq -er --arg name "$name" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
    digest=$(jq -r --arg name "$name" '.assets[] | select(.name == $name) | .digest // empty' "$work/release.json")
    case "$url" in
    https://github.com/neovim/neovim/releases/download/*) ;;
    *) die 'Unexpected Neovim download URL.' ;;
    esac
    printf 'Neovim release: %s\n' "$tag"
    curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 900 --proto '=https' "$url" -o "$work/archive.tar.gz"
    if [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
      printf '%s  %s\n' "${digest#sha256:}" "$work/archive.tar.gz" | sha256sum --check -
    else
      die 'No SHA-256 digest was provided by GitHub; refusing an unverified installation.'
    fi
    mkdir "$work/extracted"
    tar --extract --gzip --file "$work/archive.tar.gz" --directory "$work/extracted" --no-same-owner --no-same-permissions
    extracted="$work/extracted/nvim-${NVIM_PLATFORM}"
    [[ -x "$extracted/bin/nvim" ]] || die 'Unexpected Neovim archive layout.'
    "$extracted/bin/nvim" --version
    printf '%s\n' "$tag" >"$extracted/.bootstrap-managed"
    [[ ! -e "$NVIM_DIR" && ! -L "$NVIM_DIR" ]] || die "Destination appeared during installation: $NVIM_DIR"
    mv -T -- "$extracted" "$NVIM_DIR"
    if [[ ! -L "$NVIM_LINK" ]]; then ln -sT -- "$NVIM_DIR/bin/nvim" "$NVIM_LINK"; fi
  )
}
