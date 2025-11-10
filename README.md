# Rodecaster Pro II: Virtual Audio Devices for PipeWire
This repository provides a simple configuration script that automatically sets up virtual audio devices for the 
Rodecaster Pro II using PipeWire. 

![Image of the Virtual Audio Devices in KDE System Settings](.github/assets/devices.png)

## Installing the Configuration
You can install this configuration by using one of the following methods.

> [!IMPORTANT]  
> You need to select the 'Pro Audio' profile for your device for the virtual devices to work correctly.

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

sudo systemctl --user restart pipewire
```

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.