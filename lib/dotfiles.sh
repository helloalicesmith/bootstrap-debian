#!/usr/bin/env bash

collect_dotfiles() {
  local source="$ROOT/home"
  local rel file parent target

  local -a roots=(
    .zshrc
    .tmux.conf
    .config/sway
    .config/kitty
    .config/waybar
    .config/mako
    .config/fuzzel
  )

  local -a required=(
    .zshrc
    .tmux.conf
    .config/sway/config
    .config/sway/wallpapers/default.jpeg
    .config/kitty/kitty.conf
    .config/waybar/config.jsonc
    .config/waybar/style.css
    .config/mako/config
    .config/fuzzel/fuzzel.ini
  )

  for rel in "${required[@]}"; do
    [[ -f "$source/$rel" ]] ||
      die "Required file is missing: home/$rel"
  done

  LINKS=()

  for rel in "${roots[@]}"; do
    [[ ! -L "$source/$rel" ]] ||
      die "Store actual files instead of source symlinks: home/$rel"

    if [[ -f "$source/$rel" ]]; then
      LINKS+=("$rel")

    elif [[ -d "$source/$rel" ]]; then
      while IFS= read -r -d '' file; do
        [[ ! -L "$file" ]] ||
          die "Source symlinks are not supported: $file"

        [[ -f "$file" ]] || continue

        LINKS+=("${file#"$source/"}")
      done < <(
        find "$source/$rel" \
          \( -type f -o -type l \) \
          -print0
      )
    fi
  done

  for rel in "${LINKS[@]}"; do
    target="$HOME/$rel"
    parent=$(dirname -- "$target")

    while [[ "$parent" != "$HOME" && "$parent" != / ]]; do
      [[ ! -L "$parent" ]] ||
        die "A destination parent is a symlink: $parent"

      [[ ! -e "$parent" || -d "$parent" ]] ||
        die "A destination parent is not a directory: $parent"

      parent=$(dirname -- "$parent")
    done

    if [[ -L "$target" ]] &&
      [[ "$(readlink -- "$target")" == "$source/$rel" ]]; then
      continue
    fi

    [[ ! -e "$target" && ! -L "$target" ]] ||
      die "Destination already exists: $target. Move it manually before installation."
  done

  if [[ -e "$HOME/.oh-my-zsh" || -L "$HOME/.oh-my-zsh" ]]; then
    [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]] ||
      die 'The existing Oh My Zsh installation is incomplete.'
  fi

  # Match an active wallpaper directive with a literal tilde.
  # This intentionally requires the documented wallpaper path.
  if ! awk '
        $1 == "output" &&
        $2 == "*" &&
        $3 == "bg" &&
        $4 == "~/.config/sway/wallpapers/default.jpeg" &&
        $5 == "fill" {
            found = 1
        }

        END {
            exit !found
        }
    ' "$source/.config/sway/config"; then
    die 'Add the documented default.jpeg wallpaper directive to the Sway config.'
  fi
}

validate_sources() {
  log 'Checking Zsh syntax'

  zsh -n "$ROOT/home/.zshrc"

  log 'Checking the source Sway configuration'

  sway --validate \
    --config "$ROOT/home/.config/sway/config"
}

link_dotfiles() {
  log 'Deploying configuration symlinks'

  local rel source target

  for rel in "${LINKS[@]}"; do
    source="$ROOT/home/$rel"
    target="$HOME/$rel"

    if [[ -L "$target" ]] &&
      [[ "$(readlink -- "$target")" == "$source" ]]; then
      printf 'Already linked: %s\n' "$target"
      continue
    fi

    # Check again immediately before creating the link.
    [[ ! -e "$target" && ! -L "$target" ]] ||
      die "A destination conflict appeared during installation: $target"

    mkdir -p -- "$(dirname -- "$target")"

    # GNU ln -T prevents treating an existing directory as a target folder.
    ln -sT -- "$source" "$target"

    printf 'Linked: %s\n' "$target"
  done
}

configure_user() {
  log 'Configuring user directories and fonts'

  xdg-user-dirs-update

  mkdir -p "$HOME/Pictures/Screenshots"

  fc-cache -f

  local current_shell

  current_shell=$(getent passwd "$(id -un)" | cut -d: -f7)

  case "$current_shell" in
  /bin/zsh | /usr/bin/zsh)
    log 'Zsh is already the login shell'
    ;;
  *)
    log 'Setting Zsh as the login shell'
    chsh -s /usr/bin/zsh
    ;;
  esac
}
