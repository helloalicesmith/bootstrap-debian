# Debian Workstation Bootstrap

https://www.debian.org/distrib/netinst

A personal workstation installer for Debian 13 (trixie).

The installer deploys configuration files using symlinks from a permanent
local repository clone. It does not create backups or overwrite conflicting
user configuration files.

## Included software

- Sway with swaybg, swayidle and swaylock.
- greetd with tuigreet as the login manager.
- Kitty terminal and Fuzzel application launcher.
- Waybar and Mako notifications.
- PipeWire audio, WirePlumber and pavucontrol.
- NetworkManager and Bluetooth utilities.
- Zsh with Oh My Zsh.
- tmux and Vim as a fallback editor.
- Neovim from the latest stable upstream release.
- Yazi terminal file manager from the latest stable upstream release.
- Firefox ESR and Thunar.
- Screenshot, clipboard and brightness utilities.
- Desktop portals, fonts and an authentication agent.

Neovim is downloaded from its official GitHub release and verified against
the SHA-256 digest in release metadata. The managed installation is retained
on repeated runs and is not automatically upgraded.
Yazi is installed and verified in the same way.

## Requirements

- Debian 13 (trixie) amd64 with systemd, installed from the netinst image.
- A regular user with working sudo.
- Internet access.
- Git and CA certificates.
- Reviewed configuration files in the repository.

The installer targets a minimal Debian installation. It does not
automatically migrate another display manager or existing ifupdown
network connections.

## Repository layout

```text
bootstrap.sh
lib/
  common.sh
  packages.sh
  dotfiles.sh
  services.sh
  neovim.sh
  yazi.sh
home/
  .zshrc
  .tmux.conf
  .config/
    sway/
      config
      wallpapers/default.jpeg
    kitty/kitty.conf
    waybar/config.jsonc
    waybar/style.css
    mako/config
    fuzzel/fuzzel.ini
    nvim/
      init.lua
```

Neovim may use init.vim instead of init.lua.

The installer deploys the configurations as-is. Keep required application
autostart commands in the Sway configuration; installing a package alone
does not enable its Sway autostart.

## Installation

Install the initial prerequisites:

```bash
sudo apt update
sudo apt install git ca-certificates
```

Clone the repository into a permanent location:

```bash
mkdir -p ~/.local/share

git clone https://github.com/helloalicesmith/bootstrap-debian.git \
  ~/.local/share/bootstrap-debian

cd ~/.local/share/bootstrap-debian
```

Install:

```bash
bash bootstrap.sh
```

Run the installer as your regular user, not with sudo.

Reboot after successful installation and log in through tuigreet.

## Configuration

User configurations are symlinked into the home directory.

Do not delete or move the repository after installation.
Editing a deployed file also changes its source in the Git working tree.

Add the following to home/.zshrc:

```zsh
typeset -U path
path=("$HOME/.local/bin" $path)
export PATH

export EDITOR=nvim
export VISUAL=nvim
```

Neovim is installed into ~/.local/opt/neovim.
Its launcher is placed in ~/.local/bin, and its configuration is symlinked
from home/.config/nvim.
Yazi and its helper `ya` are installed into ~/.local/opt/yazi, with launchers
in ~/.local/bin. The `file` utility is installed as a Yazi prerequisite.

Editor plugins may be downloaded by your configuration on first launch.
The bootstrap does not automatically execute the Neovim configuration.

## Safety and limitations

- Existing conflicting dotfiles cause installation to stop.
- Correct existing symlinks are skipped.
- No backup or automatic rollback is provided.
- APT is not allowed to automatically remove conflicting packages.
- Package installation may start system services.
- No automatic reboot or explicit network restart is performed.
- Installation logs are stored in ~/.local/state/bootstrap-debian/.
- Firmware, suspend, brightness and other hardware-specific behavior
  must be tested on the actual computer.

Test the installer in a Debian 13 virtual machine before using it
on a primary workstation.

## Development checks

```bash
bash -n bootstrap.sh

for file in lib/*.sh; do
    bash -n "$file" || break
done

shellcheck -x bootstrap.sh lib/*.sh
```
