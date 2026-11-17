#!/usr/bin/env bash

greetd_config() {
  cat <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --cmd /usr/bin/sway"
user = "sway-greeter"
EOF
}

check_services() {
  local dm=''

  if [[ -L /etc/systemd/system/display-manager.service ]]; then
    dm=$(basename \
      "$(readlink -f /etc/systemd/system/display-manager.service)")

  elif [[ -e /etc/systemd/system/display-manager.service ]]; then
    die 'A nonstandard display-manager.service already exists.'
  fi

  [[ -z "$dm" || "$dm" == greetd.service ]] ||
    die "Another display manager is configured: $dm. Automatic migration is not supported."

  if [[ "$dm" == greetd.service ]]; then
    [[ -r /etc/greetd/config.toml ]] ||
      die 'The existing greetd configuration is missing or unreadable.'

    cmp -s \
      /etc/greetd/config.toml \
      <(greetd_config) ||
      die 'The existing greetd configuration differs from the installer configuration.'

  elif [[ -e /etc/greetd/config.toml ]]; then
    die 'An existing greetd configuration was found. Review it before installation.'
  fi

  if getent passwd sway-greeter >/dev/null; then
    local greeter_uid
    greeter_uid=$(id -u sway-greeter)

    [[ "$greeter_uid" != 0 ]] ||
      die 'The greeter account must not be root.'

    local greeter_home greeter_shell

    greeter_home=$(getent passwd sway-greeter | cut -d: -f6)
    greeter_shell=$(getent passwd sway-greeter | cut -d: -f7)

    [[ "$greeter_home" == /var/lib/sway-greeter &&
      "$greeter_shell" == /usr/sbin/nologin ]] ||
      die 'The existing sway-greeter account has unexpected settings.'
  fi
}

configure_services() {
  log 'Configuring greetd and tuigreet'

  [[ -x /usr/bin/tuigreet && -x /usr/bin/sway ]] ||
    die 'The tuigreet or Sway executable is missing.'

  if ! getent passwd sway-greeter >/dev/null; then
    sudo useradd \
      --system \
      --user-group \
      --home-dir /var/lib/sway-greeter \
      --create-home \
      --shell /usr/sbin/nologin \
      sway-greeter
  fi

  [[ "$(id -u sway-greeter)" != 0 ]] ||
    die 'The greeter must not run as root.'

  sudo install -d -m 0755 /etc/greetd

  greetd_config |
    sudo tee /etc/greetd/config.toml >/dev/null

  sudo chmod 0644 /etc/greetd/config.toml

  sudo systemctl unmask --runtime greetd.service
  GREETD_MASKED_BY_US=0

  sudo systemctl enable greetd.service

  # Set the display-manager alias explicitly.
  local unit

  unit=$(systemctl show greetd.service \
    --property=FragmentPath \
    --value)

  [[ -n "$unit" && -f "$unit" ]] ||
    die 'The greetd systemd unit was not found.'

  sudo ln -sfnT "$unit" \
    /etc/systemd/system/display-manager.service

  sudo systemctl daemon-reload
  sudo systemctl set-default graphical.target

  log 'Enabling network and Bluetooth services for the next boot'

  sudo systemctl enable \
    NetworkManager.service \
    bluetooth.service

  # Do not restart the active network connection.
  log 'Enabling user audio services'

  if systemctl --user show-environment >/dev/null 2>&1; then
    systemctl --user enable \
      pipewire.socket \
      pipewire-pulse.socket \
      wireplumber.service
  else
    printf '%s\n' \
      'The user systemd bus is unavailable.' \
      'Check PipeWire and WirePlumber after a fresh login.'
  fi
}
