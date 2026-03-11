# Rodecaster Pro II: Virtual Audio Devices for PipeWire
This repository provides a simple configuration script that automatically sets up virtual audio devices for the 
Rodecaster Pro II using PipeWire. 

Please [create an issue](https://github.com/parzival-space/rodecaster-pro-2-virtual-devices-pipewire/issues/new) if you 
notice any missing channels or have any suggestions for improvement.

> [!WARNING]
> RODE broke this **configuration** with their 1.7.3 update.
> There is currently no way of knowing the exact channel configuration and their correct mappings of the RODECaster device since it now changes based on what the user configures.
>
> **THIS CONFIGURATION IS INCOMPATIBLE WITH FIRMWARE VERSION 1.7.3**
> If you are able to, please stay on version 1.6.8.

![Image of the qpwgraph with mapped virtual devices](.github/assets/mappings.png)

> [!IMPORTANT]
> The ALSA usecase config for the RODECaster Pro II has been merged with [PR #656](https://github.com/alsa-project/alsa-ucm-conf/pull/656) into the [alsa-ucm-conf repository](https://github.com/alsa-project/alsa-ucm-conf/), which means that this repository will become obsolete with the next release of alsa-ucm-conf. This configuration is also only compatible with Firmware version <= 1.6.8.
>   
> Arch Linux users can already install the new UCM config using the following command:
> ```bash
> yay -S alsa-ucm-conf-git
> ```
>   
> You can uninstall this configuration using the following command:
> ```bash
> curl -sfL https://parzival-space.github.io/rodecaster-pro-2-virtual-devices-pipewire/configure.sh | sh -s - --uninstall
> ```

## Installing the Configuration
You can install this configuration by using one of the following methods.

> [!IMPORTANT]  
> You need to select the 'Pro Audio' profile for your device for the virtual devices to work correctly.

> [!WARNING]
> If you are using Ubuntu 25.04 or earlier (or any Ubuntu based distribution on this verson),
> the devices ``RODECaster Pro II Pro`` and ``RODECaster Pro II Pro 1`` will not be correctly renamed to
> ``RODECaster Pro II Microphone`` and ``RODECaster Pro II Multi-Channel``.  
> This happens because only Ubuntu 25.10 and later contain the required ACM configuration for the Rodecaster Pro II.
>
> The virtual Channels will work regardless of this issue.

### Method 1: Using the installation script
Run the provided installation script to set up the virtual audio devices automatically:
```bash
curl -sfL https://parzival-space.github.io/rodecaster-pro-2-virtual-devices-pipewire/configure.sh | sh -s - --install
```

### Method 2: Cloning the repository
Alternatively, you can clone the repository and run the configuration script locally:
```bash
git clone https://github.com/parzival-space/rodecaster-pro-2-virtual-devices-pipewire.git
cd rodecaster-pro-2-virtual-devices-pipewire
./configure.sh --install
```

### Method 3: Manual installation
If you don't want to use the script, you can manually copy the configuration files to your PipeWire configuration directory:
```bash
git clone https://github.com/parzival-space/rodecaster-pro-2-virtual-devices-pipewire.git
cd rodecaster-pro-2-virtual-devices-pipewire

sudo mkdir -p /usr/share/pipewire/pipewire.conf.d
sudo cp ./rodecaster-pro-2.template.conf /usr/share/pipewire/pipewire.conf.d/rodecaster-pro-2.conf

# you need to replace "__REPLACE_WITH_YOUR_SERIAL__" with your Rodecaster Pro II's serial number
sudo sed -i "s/{{DEVICE_SERIAL}}/__REPLACE_WITH_YOUR_SERIAL__-00/g" /usr/share/pipewire/pipewire.conf.d/rodecaster-pro-2.conf

systemctl --user restart pipewire
```

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
