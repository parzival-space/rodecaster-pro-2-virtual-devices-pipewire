#!/usr/bin/env bash

check_requirements() {
  # check if command 'pw-cli' exists
  if ! command -v pw-cli &> /dev/null; then
    echo "PipeWire CLI (pw-cli) is not installed. Please install PipeWire and its development tools."
    exit 1
  fi

  # check if command 'pw-cli info 0' fails
  if ! pw-cli info 0 &> /dev/null; then
    echo "PipeWire does not seem to be running or accessible. Please ensure PipeWire is installed and running."
    exit 1
  fi

  # install curl if missing
  if ! command -v curl &> /dev/null; then
    echo "curl could not be found, installing..."
    if command -v apt-get &> /dev/null; then
      sudo apt-get update
      sudo apt-get install -y curl
    elif command -v yum &> /dev/null; then
      sudo yum install -y curl
    elif command -v pacman &> /dev/null; then
      sudo pacman -Sy curl
    else
      echo "Package manager not supported. Please install curl manually."
      exit 1
    fi
  fi
}

write_config_file() {
  local device_serial="$1"
  local output_file="$2"
  local useSudo="$3"

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
  local useUserContext="$1"

  # gets a list of device serials from the devices matching "alsa_card.usb-R__DE_RODECaster_Pro_II_(.*)"
  DEVICE_SERIALS=($(pw-cli ls Device | grep -oP 'alsa_card.usb-R__DE_RODECaster_Pro_II_\K[^"]+'))
  echo "Found ${#DEVICE_SERIALS[@]} Rodecaster Pro II device(s)."

  # create config directory if it doesn't exist
  CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
  if [ "$useUserContext" = "true" ]; then
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_USER"
    if [ ! -d "$CONFIG_DIR" ]; then
      echo "Creating user PipeWire config directory at $CONFIG_DIR"
      mkdir -p "$CONFIG_DIR"
    fi
  else
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
    if [ ! -d "$CONFIG_DIR" ]; then
      echo "Creating system-wide PipeWire config directory at $CONFIG_DIR"
      sudo mkdir -p "$CONFIG_DIR"
    fi
  fi

  # install for each device serial
  for SERIAL in "${DEVICE_SERIALS[@]}"; do
    echo "Installing virtual devices for Rodecaster Pro II with serial: $SERIAL"
    OUTPUT_FILE="${CONFIG_DIR}/rodecaster-pro-2-${SERIAL}.conf"

    if [ "$useUserContext" = "true" ]; then
      write_config_file "$SERIAL" "$OUTPUT_FILE" "false"
    else
      write_config_file "$SERIAL" "$OUTPUT_FILE" "true"
    fi
  done

  echo "Installation complete. Restarting PipeWire..."
  if command -v systemctl &> /dev/null; then
    systemctl --user restart pipewire
    systemctl --user restart pipewire-pulse
  else
    echo "systemctl not found. Please restart PipeWire manually."
  fi
}

uninstall() {
  local useUserContext="$1"

  # remove config files for each device serial (rodecaster-pro-2-*.conf)
  CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
  if [ "$useUserContext" = "true" ]; then
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_USER"
  else
    CONFIG_DIR="$PIPEWIRE_CONFIG_DIR_SYSTEM"
  fi

  if [ -d "$CONFIG_DIR" ]; then
    echo "Removing virtual device configuration files from $CONFIG_DIR"
    if [ "$useUserContext" = "true" ]; then
      rm -f "${CONFIG_DIR}/rodecaster-pro-2-"*.conf
    else
      sudo rm -f "${CONFIG_DIR}/rodecaster-pro-2-"*.conf
    fi
    echo "Uninstallation complete. Restarting PipeWire..."
    if command -v systemctl &> /dev/null; then
      systemctl --user restart pipewire
      systemctl --user restart pipewire-pulse
    else
      echo "systemctl not found. Please restart PipeWire manually."
    fi
  else
    echo "Configuration directory $CONFIG_DIR does not exist. Nothing to uninstall."
  fi
}

# DO NOT EDIT THESE VARIABLES BELOW
TEMPLATE_FILE="rodecaster-pro-2.template.conf"
TEMPLATE_DOWNLOAD_URL="https://parival-space.github.io/rodecaster-pro-2-virtual-devices-pipewire/${TEMPLATE_FILE}"
TEMPLATE_STRING_DEVICE_SERIAL="{{DEVICE_SERIAL}}"
PIPEWIRE_CONFIG_DIR_SYSTEM="/usr/share/pipewire/pipewire.conf.d"
PIPEWIRE_CONFIG_DIR_USER="$HOME/.config/pipewire/pipewire.conf.d"

# cli flags
FLAG_USER_INSTALL="false"
FLAG_INSTALL="false"
FLAG_UNINSTALL="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --user)
      FLAG_USER_INSTALL="true"
      shift
      ;;
    --install)
      FLAG_INSTALL="true"
      FLAG_UNINSTALL="false"
      shift
      ;;
    --uninstall)
      FLAG_UNINSTALL="true"
      FLAG_INSTALL="false"
      shift
      ;;
    --help)
      FLAG_INSTALL="false"
      FLAG_UNINSTALL="false"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [ "$FLAG_INSTALL" = "true" ]; then
  install "$FLAG_USER_INSTALL"
elif [ "$FLAG_UNINSTALL" = "true" ]; then
  uninstall "$FLAG_USER_INSTALL"
else
  echo "Usage: $0 [--install | --uninstall] [--user]"
  echo "  --install    Install the virtual devices."
  echo "  --uninstall  Uninstall the virtual devices."
  echo "  --user       Install for the current user only."
  echo "  --help       Show this help message."
fi