#!/usr/bin/env bash

build_packages() {
  PACKAGES=(
    git
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
    bluez
    blueman

    dbus-user-session
    libpam-systemd
    xdg-utils
    xdg-user-dirs

    vim
    tmux
    zsh
    less
    unzip
    ripgrep
    fd-find

    firefox-esr
    thunar
    gvfs
    gvfs-backends
    tumbler
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
