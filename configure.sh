#!/bin/sh

device_pid_present() {
  pid="$1"
  lsusb | grep -E "${RODE_VID}:${pid}" >/dev/null 2>&1
}

get_device_name() {
  case "$1" in
    pro2)
      echo "Rodecaster Pro II"
      ;;
    duo)
      echo "Rodecaster Duo"
      ;;
    *)
      echo "Rodecaster"
      ;;
  esac
}

get_config_prefix() {
  case "$1" in
    pro2)
      echo "rodecaster-pro-2"
      ;;
    duo)
      echo "rodecaster-duo"
      ;;
  esac
}

get_template_file() {
  device_model="$1"

  case "$device_model" in
    duo)
      if device_pid_present "$RODECASTER_DUO_PID_1_7_3"; then
        echo "$TEMPLATE_FILE_DUO_1_7_3"
        return 0
      fi
      ;;
    pro2)
      if device_pid_present "$RODECASTER_PRO_2_PID_1_7_3"; then
        echo "$TEMPLATE_FILE_1_7_3"
        return 0
      fi

      if device_pid_present "$RODECASTER_PRO_2_PID_1_6_8"; then
        echo "$TEMPLATE_FILE_1_6_8"
        return 0
      fi
      ;;
  esac

  return 1
}

list_connected_devices() {
  pw-cli ls Device | awk '
    /alsa_card\.usb-R__DE_RODECaster_Pro_II_/ {
      line = $0
      sub(/.*alsa_card\.usb-R__DE_RODECaster_Pro_II_/, "", line)
      sub(/".*/, "", line)
      print "pro2|" line
      next
    }
    /alsa_card\.usb-R__DE_RODECaster_Duo_/ {
      line = $0
      sub(/.*alsa_card\.usb-R__DE_RODECaster_Duo_/, "", line)
      sub(/".*/, "", line)
      print "duo|" line
    }
  '
}

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

  # check if one of the supported Rodecaster devices is present using lsusb
  if ! device_pid_present "$RODECASTER_PRO_2_PID_1_6_8" \
    && ! device_pid_present "$RODECASTER_PRO_2_PID_1_7_3" \
    && ! device_pid_present "$RODECASTER_DUO_PID_1_7_3"; then
    echo "No supported Rodecaster multitrack device detected. Please connect your Rodecaster Pro II or Rodecaster Duo and ensure it is in Multitrack (Input + Output) mode."
    exit 1
  fi

}

write_config_file() {
  device_model="$1"
  device_serial="$2"
  output_file="$3"
  useSudo="$4"
  device_name=$(get_device_name "$device_model")
  TEMPLATE_FILE=$(get_template_file "$device_model")

  if [ -z "$TEMPLATE_FILE" ]; then
    echo "No compatible ${device_name} template found. Please verify the connected device firmware is supported."
    exit 1
  fi

  echo "Detected ${device_name}. Using template ${TEMPLATE_FILE}."
  TEMPLATE_DOWNLOAD_URL="${TEMPLATE_DOWNLOAD_URL_BASE}${TEMPLATE_FILE}"

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
  CONNECTED_DEVICES=$(list_connected_devices)

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

  if [ -z "$CONNECTED_DEVICES" ]; then
    echo "No supported Rodecaster devices were found in PipeWire. Please ensure the device is connected and in Multitrack (Input + Output) mode."
    exit 1
  fi

  echo "$CONNECTED_DEVICES" | while IFS='|' read -r DEVICE_MODEL SERIAL; do
    [ -z "$SERIAL" ] && continue
    DEVICE_NAME=$(get_device_name "$DEVICE_MODEL")
    CONFIG_PREFIX=$(get_config_prefix "$DEVICE_MODEL")
    echo "Installing virtual devices for ${DEVICE_NAME} with serial: $SERIAL"
    OUTPUT_FILE="${CONFIG_DIR}/${CONFIG_PREFIX}-${SERIAL}.conf"
    if [ "$useUserContext" = "true" ]; then
      write_config_file "$DEVICE_MODEL" "$SERIAL" "$OUTPUT_FILE" "false"
    else
      write_config_file "$DEVICE_MODEL" "$SERIAL" "$OUTPUT_FILE" "true"
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
      rm -f "${CONFIG_DIR}/rodecaster-duo-"*.conf
    else
      sudo rm -f "${CONFIG_DIR}/rodecaster-pro-2-"*.conf
      sudo rm -f "${CONFIG_DIR}/rodecaster-duo-"*.conf
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
TEMPLATE_FILE_1_6_8="rodecaster-pro-2-1.6.8.template.conf"
TEMPLATE_FILE_1_7_3="rodecaster-pro-2-1.7.3.template.conf"
TEMPLATE_FILE_DUO_1_7_3="rodecaster-duo-1.7.3.template.conf"
TEMPLATE_DOWNLOAD_URL_BASE="https://parzival-space.github.io/rodecaster-pro-2-virtual-devices-pipewire/"
TEMPLATE_STRING_DEVICE_SERIAL="{{DEVICE_SERIAL}}"
PIPEWIRE_CONFIG_DIR_SYSTEM="/usr/share/pipewire/pipewire.conf.d"
PIPEWIRE_CONFIG_DIR_USER="$HOME/.config/pipewire/pipewire.conf.d"

# Rodecaster Pro II PIDs
RODE_VID="19f7"
RODECASTER_PRO_2_PID_1_6_8="0072"
RODECASTER_PRO_2_PID_1_7_3="0094"
RODECASTER_DUO_PID_1_7_3="0095"


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