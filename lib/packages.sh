#!/usr/bin/env bash

build_packages() {
  PACKAGES=(
    ca-certificates
    curl

    sway
    swaybg
    swayidle
    swaylock
    greetd
    tuigreet

    kitty
    fuzzel
    fzf
    waybar
    xwayland

    xdg-desktop-portal
    xdg-desktop-portal-wlr
    xdg-desktop-portal-gtk

    mate-polkit
    libnotify-bin
    mako-notifier

    grim
    slurp
    wl-clipboard
    brightnessctl
    wev

    fonts-font-awesome
    fonts-dejavu-core
    fonts-noto-color-emoji
    fontconfig
    adwaita-icon-theme

    pipewire-audio
    wireplumber
    pavucontrol
    alsa-utils

    network-manager
    network-manager-gnome
    tlp
    bluez
    blueman

    dbus-user-session
    libpam-systemd
    xdg-utils
    xdg-user-dirs

    vim
    tmux
    lazygit
    zsh
    less
    unzip
    file
    ripgrep
    fd-find

    firefox-esr
    thunar
    gvfs
    gvfs-backends
    tumbler

    jq
    tar
    gzip
    build-essential
    python3-venv
  )
}

install_packages() {
  log 'Updating APT package indexes'

  sudo apt-get update

  # Prevent a newly installed greetd from starting before configuration.
  local state

  state=$(systemctl is-enabled greetd.service 2>/dev/null || true)

  case "$state" in
  masked | masked-runtime)
    die 'greetd is already masked. Review the existing administrator configuration.'
    ;;
  esac

  sudo systemctl mask --runtime greetd.service
  GREETD_MASKED_BY_US=1

  log 'Installing packages'

  # Stop rather than automatically remove conflicting packages.
  sudo apt-get --no-remove install "${PACKAGES[@]}"
}

install_ohmyzsh() {
  if [[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    log 'Keeping the existing Oh My Zsh installation'
    return
  fi

  log 'Installing Oh My Zsh'

  # Do not run the upstream installer or overwrite .zshrc.
  git clone --depth 1 \
    https://github.com/ohmyzsh/ohmyzsh.git \
    "$HOME/.oh-my-zsh"
}

install_catppuccin_tmux() {
  local plugin="$HOME/.config/tmux/plugins/catppuccin/tmux"
  local version=v2.3.2
  local parent

  for parent in "$HOME/.config/tmux" "$HOME/.config/tmux/plugins" "$HOME/.config/tmux/plugins/catppuccin"; do
    [[ ! -L "$parent" ]] || die "Installation parent is a symlink: $parent"
    [[ ! -e "$parent" || -d "$parent" ]] || die "Not a directory: $parent"
  done

  if [[ -e "$plugin" || -L "$plugin" ]]; then
    [[ -d "$plugin" && ! -L "$plugin" &&
      -f "$plugin/catppuccin.tmux" &&
      "$(git -C "$plugin" remote get-url origin 2>/dev/null)" == https://github.com/catppuccin/tmux.git &&
      "$(git -C "$plugin" describe --tags --exact-match --match "$version" 2>/dev/null)" == "$version" ]] ||
      die "Conflicting or incomplete Catppuccin tmux installation: $plugin"
    log "Keeping Catppuccin tmux $version"
    return
  fi

  log "Installing Catppuccin tmux $version (recommended manual method)"
  mkdir -p -- "$(dirname -- "$plugin")"
  git clone --depth 1 --branch "$version" \
    https://github.com/catppuccin/tmux.git \
    "$plugin"
}
