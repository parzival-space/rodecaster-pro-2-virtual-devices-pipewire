#!/bin/sh

check_requirements() {
  # check if command 'pw-cli' exists
  if ! command -v pw-cli >/dev/null 2>&1; then
    echo "PipeWire CLI (pw-cli) is not installed. Please install PipeWire and its development tools."
    exit 1
  fi

  # check if command 'pw-cli info 0' fails
  if ! pw-cli info 0 >/dev/null 2>&1; then
    echo "PipeWire does not seem to be running or accessible. Please ensure PipeWire is installed and running."
    exit 1
  fi

  # install curl if missing
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl could not be found, installing..."
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y curl
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y curl
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy curl
    else
      echo "Package manager not supported. Please install curl manually."
      exit 1
    fi
  fi
}

write_config_file() {
  device_serial="$1"
  output_file="$2"
  useSudo="$3"

  # copy template file, if it exists in the current directory
  if [ -f "$TEMPLATE_FILE" ]; then
    if [ "$useSudo" = "true" ]; then
      sudo cp "$TEMPLATE_FILE" "$output_file"
    else
      cp "$TEMPLATE_FILE" "$output_file"
    fi
  else
    # download template file, fail on 404
    if [ "$useSudo" = "true" ]; then
      sudo curl -fSL "$TEMPLATE_DOWNLOAD_URL" -o "$output_file"
    else
      curl -fSL "$TEMPLATE_DOWNLOAD_URL" -o "$output_file"
    fi
    if [ $? -ne 0 ]; then
      echo "Failed to download template file from $TEMPLATE_DOWNLOAD_URL"
      exit 1
    fi
  fi

  # replace placeholder with actual device serial
  if [ "$useSudo" = "true" ]; then
    sudo sed -i "s/${TEMPLATE_STRING_DEVICE_SERIAL}/${device_serial}/g" "$output_file"
  else
    sed -i "s/${TEMPLATE_STRING_DEVICE_SERIAL}/${device_serial}/g" "$output_file"
  fi
}

install() {
  useUserContext="$1"
  noRestartAfterInstall="$2"

  # Get list of device serials
  DEVICE_SERIALS_TMP=$(pw-cli ls Device | grep 'alsa_card.usb-R__DE_RODECaster_Pro_II_' | sed 's/.*alsa_card\.usb-R__DE_RODECaster_Pro_II_//' | sed 's/".*//')
  DEVICE_COUNT=0

  CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
  if [ "$useUserContext" = "true" ]; then
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_USER"
    if [ ! -d "$CONFIG_DIR" ]; then
      echo "Creating user PipeWire config directory at $CONFIG_DIR"
      mkdir -p "$CONFIG_DIR"
    fi
  else
    if [ ! -d "$CONFIG_DIR" ]; then
      echo "Creating system-wide PipeWire config directory at $CONFIG_DIR"
      sudo mkdir -p "$CONFIG_DIR"
    fi
  fi

  echo "$DEVICE_SERIALS_TMP" | while IFS= read -r SERIAL; do
    [ -z "$SERIAL" ] && continue
    DEVICE_COUNT=$((DEVICE_COUNT + 1))
    echo "Installing virtual devices for Rodecaster Pro II with serial: $SERIAL"
    OUTPUT_FILE="${CONFIG_DIR}/rodecaster-pro-2-${SERIAL}.conf"
    if [ "$useUserContext" = "true" ]; then
      write_config_file "$SERIAL" "$OUTPUT_FILE" "false"
    else
      write_config_file "$SERIAL" "$OUTPUT_FILE" "true"
    fi
  done

  echo "Installation complete. Restarting PipeWire..."
  if command -v systemctl >/dev/null 2>&1; then
    if [ "$noRestartAfterInstall" != "true" ]; then
      systemctl --user restart pipewire 2>/dev/null || true
      systemctl --user restart pipewire-pulse 2>/dev/null || true
    else
      echo "Skipping PipeWire restart as per --no-restart flag."
    fi
  else
    echo "systemctl not found. Please restart PipeWire manually."
  fi
}

uninstall() {
  useUserContext="$1"
  noRestartAfterUninstall="$2"

  CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
  if [ "$useUserContext" = "true" ]; then
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_USER"
  fi

  if [ -d "$CONFIG_DIR" ]; then
    echo "Removing virtual device configuration files from $CONFIG_DIR"
    if [ "$useUserContext" = "true" ]; then
      rm -f "${CONFIG_DIR}/rodecaster-pro-2-"*.conf
    else
      sudo rm -f "${CONFIG_DIR}/rodecaster-pro-2-"*.conf
    fi

    echo "Uninstallation complete. Restarting PipeWire..."
    if command -v systemctl >/dev/null 2>&1; then
      if [ "$noRestartAfterUninstall" != "true" ]; then
        systemctl --user restart pipewire 2>/dev/null || true
        systemctl --user restart pipewire-pulse 2>/dev/null || true
      else
        echo "Skipping PipeWire restart as per --no-restart flag."
      fi
    else
      echo "systemctl not found. Please restart PipeWire manually."
    fi
  else
    echo "Configuration directory $CONFIG_DIR does not exist. Nothing to uninstall."
  fi
}

# DO NOT EDIT THESE VARIABLES BELOW
TEMPLATE_FILE="rodecaster-pro-2.template.conf"
TEMPLATE_DOWNLOAD_URL="https://parzival-space.github.io/rodecaster-pro-2-virtual-devices-pipewire/${TEMPLATE_FILE}"
TEMPLATE_STRING_DEVICE_SERIAL="{{DEVICE_SERIAL}}"
PIPEWIRE_CONFIG_DIR_SYSTEM="/usr/share/pipewire/pipewire.conf.d"
PIPEWIRE_CONFIG_DIR_USER="$HOME/.config/pipewire/pipewire.conf.d"

# cli flags
FLAG_USER_INSTALL=false
FLAG_INSTALL=false
FLAG_UNINSTALL=false
FLAG_NO_RESTART=false

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      FLAG_USER_INSTALL=true
      ;;
    --install)
      FLAG_INSTALL=true
      FLAG_UNINSTALL=false
      ;;
    --uninstall)
      FLAG_UNINSTALL=true
      FLAG_INSTALL=false
      ;;
    --no-restart)
      FLAG_NO_RESTART=true
      ;;
    --help)
      FLAG_INSTALL=false
      FLAG_UNINSTALL=false
      ;;
  esac
  shift
done

if [ "$FLAG_INSTALL" = "true" ]; then
  check_requirements
  install "$FLAG_USER_INSTALL" "$FLAG_NO_RESTART"
elif [ "$FLAG_UNINSTALL" = "true" ]; then
  uninstall "$FLAG_USER_INSTALL" "$FLAG_NO_RESTART"
else
  echo "Usage: $0 [--install | --uninstall] [--user]"
  echo "  --install    Install the virtual devices."
  echo "  --uninstall  Uninstall the virtual devices."
  echo "  --no-restart Do not restart PipeWire after installation/uninstallation."
  echo "  --user       Install for the current user only."
  echo "  --help       Show this help message."
fi