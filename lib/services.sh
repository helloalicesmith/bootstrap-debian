#!/usr/bin/env bash

# Sourced by bootstrap.sh.

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

    # Accept our configuration when resuming or repeating an installation.
    if [[ -e /etc/greetd/config.toml ]]; then
        [[ -r /etc/greetd/config.toml ]] ||
            die 'The existing greetd configuration is unreadable.'

        cmp -s \
            /etc/greetd/config.toml \
            <(greetd_config) ||
            die 'The existing greetd configuration differs from the installer configuration.'
    fi

    if getent passwd sway-greeter >/dev/null; then
        local greeter_uid
        local greeter_home
        local greeter_shell

        greeter_uid=$(id -u sway-greeter)
        greeter_home=$(getent passwd sway-greeter | cut -d: -f6)
        greeter_shell=$(getent passwd sway-greeter | cut -d: -f7)

        [[ "$greeter_uid" != 0 ]] ||
            die 'The greeter account must not be root.'

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

    log 'Reserving tty1 for greetd'

    # Do not use --now: installation may be running on tty1.
    # Leave all other virtual terminals available.
    sudo systemctl disable getty@tty1.service
    sudo systemctl mask getty@tty1.service

    log 'Configuring greetd terminal ownership'

    sudo install -d -m 0755 \
        /etc/systemd/system/greetd.service.d

    sudo tee \
        /etc/systemd/system/greetd.service.d/tty.conf \
        >/dev/null <<'EOF'
[Unit]
Conflicts=getty@tty1.service
After=getty@tty1.service
EOF

    sudo systemctl daemon-reload

    sudo systemctl unmask --runtime greetd.service
    GREETD_MASKED_BY_US=0

    # Enable for the next boot without stopping the current session.
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

    # Do not restart the active network connection.
    sudo systemctl enable \
        NetworkManager.service \
        bluetooth.service \
        tlp.service

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