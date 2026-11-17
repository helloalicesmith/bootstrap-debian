#!/usr/bin/env bash

check_yazi() {
  YAZI_DIR="$HOME/.local/opt/yazi"
  YAZI_LINK="$HOME/.local/bin/yazi"
  YA_LINK="$HOME/.local/bin/ya"

  local parent link target

  for parent in "$HOME/.local" "$HOME/.local/opt" "$HOME/.local/bin"; do
    [[ ! -L "$parent" ]] || die "Installation parent is a symlink: $parent"
    [[ ! -e "$parent" || -d "$parent" ]] || die "Not a directory: $parent"
  done

  if [[ -e "$YAZI_DIR" || -L "$YAZI_DIR" ]]; then
    [[ -d "$YAZI_DIR" && ! -L "$YAZI_DIR" &&
      -f "$YAZI_DIR/.bootstrap-managed" &&
      -x "$YAZI_DIR/yazi" && -x "$YAZI_DIR/ya" ]] ||
      die "Unmanaged or incomplete Yazi installation: $YAZI_DIR"
  fi

  for link in "$YAZI_LINK" "$YA_LINK"; do
    target="$YAZI_DIR/${link##*/}"
    if [[ -e "$link" || -L "$link" ]]; then
      [[ -L "$link" && "$(readlink -- "$link")" == "$target" ]] ||
        die "Conflicting launcher: $link"
    fi
  done
}

install_yazi() {
  mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"

  if [[ -f "$YAZI_DIR/.bootstrap-managed" ]]; then
    log 'Keeping the existing managed Yazi installation'
    [[ -L "$YAZI_LINK" ]] || ln -sT -- "$YAZI_DIR/yazi" "$YAZI_LINK"
    [[ -L "$YA_LINK" ]] || ln -sT -- "$YAZI_DIR/ya" "$YA_LINK"
    return
  fi

  log 'Installing the latest stable upstream Yazi release'

  (
    set -Eeuo pipefail
    work=$(mktemp -d "$HOME/.local/opt/.yazi-install-XXXXXX")
    trap 'rm -rf -- "$work"' EXIT

    curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 120 --proto '=https' \
      https://api.github.com/repos/sxyazi/yazi/releases/latest -o "$work/release.json"
    tag=$(jq -er '.tag_name' "$work/release.json")
    name='yazi-x86_64-unknown-linux-gnu.zip'
    url=$(jq -er --arg name "$name" '.assets[] | select(.name == $name) | .browser_download_url' "$work/release.json")
    digest=$(jq -r --arg name "$name" '.assets[] | select(.name == $name) | .digest // empty' "$work/release.json")

    case "$url" in
    https://github.com/sxyazi/yazi/releases/download/*) ;;
    *) die 'Unexpected Yazi download URL.' ;;
    esac

    printf 'Yazi release: %s\n' "$tag"
    curl --fail --silent --show-error --location --retry 3 --connect-timeout 20 --max-time 900 --proto '=https' "$url" -o "$work/archive.zip"
    if [[ "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
      printf '%s  %s\n' "${digest#sha256:}" "$work/archive.zip" | sha256sum --check -
    else
      die 'No SHA-256 digest was provided by GitHub; refusing an unverified installation.'
    fi

    mkdir "$work/extracted"
    unzip -q "$work/archive.zip" -d "$work/extracted"
    extracted="$work/extracted/yazi-x86_64-unknown-linux-gnu"
    [[ -x "$extracted/yazi" && -x "$extracted/ya" ]] ||
      die 'Unexpected Yazi archive layout.'
    "$extracted/yazi" --version
    "$extracted/ya" --version
    printf '%s\n' "$tag" >"$extracted/.bootstrap-managed"

    [[ ! -e "$YAZI_DIR" && ! -L "$YAZI_DIR" ]] ||
      die "Destination appeared during installation: $YAZI_DIR"
    mv -T -- "$extracted" "$YAZI_DIR"

    [[ ! -e "$YAZI_LINK" && ! -L "$YAZI_LINK" ]] ||
      die "Launcher appeared during installation: $YAZI_LINK"
    ln -sT -- "$YAZI_DIR/yazi" "$YAZI_LINK"
    [[ ! -e "$YA_LINK" && ! -L "$YA_LINK" ]] ||
      die "Launcher appeared during installation: $YA_LINK"
    ln -sT -- "$YAZI_DIR/ya" "$YA_LINK"
  )
}
