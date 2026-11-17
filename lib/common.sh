#!/usr/bin/env bash

GREETD_MASKED_BY_US=0

log() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if ((GREETD_MASKED_BY_US)); then
    sudo systemctl unmask --runtime greetd.service || true
  fi
}

preflight() {
  ((EUID != 0)) ||
    die 'Run as a regular user, not as root or through sudo.'

  [[ -r /etc/os-release ]] ||
    die '/etc/os-release was not found.'

  # shellcheck disable=SC1091
  source /etc/os-release

  [[ "${ID:-}" == debian && "${VERSION_ID:-}" == 13 ]] ||
    die 'Only Debian 13 (trixie) is supported.'

  [[ -d /run/systemd/system ]] ||
    die 'A normally booted systemd installation is required.'

  local command

  for command in sudo git flock; do
    command -v "$command" >/dev/null ||
      die "Required command was not found: $command"
  done

  [[ "${XDG_CONFIG_HOME:-$HOME/.config}" == "$HOME/.config" ]] ||
    die 'A custom XDG_CONFIG_HOME is not supported.'

  [[ "${ZDOTDIR:-$HOME}" == "$HOME" ]] ||
    die 'A custom ZDOTDIR is not supported.'

  [[ -d "$ROOT/home" && ! -L "$ROOT/home" ]] ||
    die 'The repository must contain a regular home/ directory.'

  # Lock the script inode without creating a lock file.
  exec 9<"$ROOT/bootstrap.sh"

  flock -n 9 ||
    die 'Another installer instance is already running.'

  # Do not migrate existing ifupdown connections automatically.
  local file
  local -a network_files=()

  if [[ -f /etc/network/interfaces ]]; then
    network_files+=(/etc/network/interfaces)
  fi

  if [[ -d /etc/network/interfaces.d ]]; then
    while IFS= read -r -d '' file; do
      network_files+=("$file")
    done < <(
      find /etc/network/interfaces.d \
        -maxdepth 1 \
        -type f \
        -print0
    )
  fi

  for file in "${network_files[@]}"; do
    [[ -r "$file" ]] ||
      if [[ ! -r "$file" ]]; then
        if ((DRY_RUN)); then
            printf 'WARNING: Cannot inspect %s without elevated permissions; network checks are incomplete.\n' \
                "$file" >&2
            continue
        fi

        printf 'Checking network configuration with sudo: %s\n' "$file"

        sudo test -r "$file" ||
            die "Cannot read the network configuration: $file"

        if sudo awk '
            $1 == "iface" && $2 != "lo" {
                found = 1
            }

            END {
                exit !found
            }
        ' "$file"; then
            die "An ifupdown interface exists in $file. Review its NetworkManager migration first."
        fi

        continue
    fi

    if awk '
            $1 == "iface" && $2 != "lo" {
                found = 1
            }

            END {
                exit !found
            }
        ' "$file"; then
      printf 'WARNING: An ifupdown interface exists in %s. Its configuration will be preserved.\n' \
        "$file" >&2
    fi
  done
}
