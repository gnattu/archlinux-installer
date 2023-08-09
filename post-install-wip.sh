#!/bin/bash

################################################################
#                                                              #
#    Arch Linux post installation tool for Rock 5B / RK3588    #
#                                                              #
################################################################

echo "---------------------------------------------------------------------"
echo "Arch Linux Post Install for Rock 5B / RK3588"
echo "---------------------------------------------------------------------"
echo "Starting post installation ..."

# The fix for some Bluetooth Modules (A8, AX210, etc.)
echo "Applying bluetooth fix for some Bluetooth Modules (A8, AX210, etc.) ..."
echo "blacklist pgdrv" >> sudo tee /etc/modprobe.d/blacklist.conf
echo "blacklist btusb" >> sudo tee /etc/modprobe.d/blacklist.conf
echo "blacklist btrtl" >> sudo tee /etc/modprobe.d/blacklist.conf
echo "blacklist btbcm" >> sudo tee /etc/modprobe.d/blacklist.conf
echo "#blacklist btintel" >> sudo tee /etc/modprobe.d/blacklist.conf

#For AX210 Wifi and BT to Work
sudo pacman -Sy wget --noconfirm
echo "Installing WiFi driver for AX210 ..."
sudo wget -P /lib/firmware https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/iwlwifi-ty-a0-gf-a0-59.ucode
sudo mv /lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm /lib/firmware/iwlwifi-ty-a0-gf-a0.pnvm.bak

echo "Installing Bluetooth driver for AX210 ..."
sudo wget -P /lib/firmware/intel https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/intel/ibt-0041-0041.sfi
sudo wget -P /lib/firmware/intel https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/intel/ibt-0041-0041.ddc

# Network Manager, WiFi, Bluetooth
echo "Installing network manager ..."
sudo pacman -S networkmanager iw --noconfirm
sudo systemctl enable NetworkManager.service
sudo systemctl start NetworkManager.service

# RK3588 Profile
# Define the alias lines
performance_alias="alias performance=\"echo performance | sudo tee /sys/bus/cpu/devices/cpu[046]/cpufreq/scaling_governor /sys/class/devfreq/dmc/governor /sys/class/devfreq/fb000000.gpu/governor\""
ondemand_alias="alias ondemand=\"echo ondemand | sudo tee /sys/bus/cpu/devices/cpu[046]/cpufreq/scaling_governor && echo dmc_ondemand | sudo tee /sys/class/devfreq/dmc/governor && echo simple_ondemand | sudo tee /sys/class/devfreq/fb000000.gpu/governor\""
powersave_alias="alias powersave=\"echo powersave | sudo tee /sys/bus/cpu/devices/cpu[046]/cpufreq/scaling_governor /sys/class/devfreq/dmc/governor /sys/class/devfreq/fb000000.gpu/governor\""

# Append alias lines to ~/.bash_aliases
echo "$performance_alias" >> sudo tee ~/.bash_aliases
echo "$ondemand_alias" >> sudo tee  ~/.bash_aliases
echo "$powersave_alias" >> sudo tee ~/.bash_aliases

# Source the updated ~/.bash_aliases
source ~/.bash_aliases
echo "SoC Performance Profile Added. You may change your SoC Performance Profile by running performance, ondemand or powersave."

# TODO: Add support for pwm fan control
sudo pacman -S dtc --noconfirm
echo "Getting PWM Fan Control DTS File"
curl -LJO https://raw.githubusercontent.com/amazingfate/radxa-rock5b-overlays/main/pwm-fan.dts
echo "Compiling pwm-fan.dts to rock5b-pwm-fan.dtb"
dtc -O dtb -o "rock5b-pwm-fan.dtb" "pwm-fan.dts"
sudo mv rock5b-pwm-fan.dtb /boot/dtbs/rockchip/rock5b-pwm-fan.dtb
sudo rm -rf pwm-fan.dts

# Install Mesa and Desktop Environment
echo "---------------------------------------------------------------------"
echo "Install desktop environment"
echo "---------------------------------------------------------------------"
echo ""
echo "Select a desktop environment to install :"
echo "1. Gnome"
echo "2. KDE Plasma" 
echo "3. Budgie"
#echo "4. XFCE"
#echo "5. LXQt"
#echo "6. Cinnamon"
#echo "7. Cutefish"
#echo "8. Deepin"
#echo "9. MATE"
#echo "10. Sway"
# TO BE ADDED

echo "Input anything else to Install GPU acceleration only"
echo ""
echo "Pick an option to install :"
read de_options

echo "---------------------------------------------------------------------"
echo "Install Mesa / GPU acceleration"
echo "---------------------------------------------------------------------"
echo ""
echo "Select a package to install :"
echo "1. mesa-panfork-git - Panfork Mesa driver for Radxa BSP Kernel (rkbsp5) (linux 5.10.x)"
echo "2. mesa-pancsf-git - Pancsf Mesa driver for Googulator's Midstream kernel (linux-rk3588-midstream) (linux 6.2.x)"
echo ""
echo "Pick an option to install :"
read answer

# tmp dir folder name
tmp_repo_dir="tmp-repo-dir"

# Install required package
sudo pacman -S git --noconfirm
sudo pacman -S --needed base-devel --noconfirm

# create and cd to a directory
cd ~/
mkdir $tmp_repo_dir
cd $tmp_repo_dir

if [ "$answer" = 1 ]; then
    #Install mesa-panfork-git
    echo "Downloading mesa-panfork-git ..."
    git clone https://aur.archlinux.org/mesa-panfork-git.git
    cd mesa-panfork-git
    makepkg -si
    cd ..
    echo "Installed mesa-panfork-git"

elif [ "$answer" = 2 ]; then
    #Install mesa-pancsf-git
    echo "Downloading mesa-pancsf-git ..."
    git clone https://github.com/hbiyik/hw_necromancer.git
    cd hw_necromancer/rock5b/mesa-pancsf-git
    makepkg -si
    cd ..
    cd ..
    cd ..
    echo "Installed mesa-pancsf-git"
else
    echo "invalid option, exiting .."
    sudo rm -rf ~/$tmp_repo_dir
    exit 1
fi

# Remove temp dir folder
echo "Installed successfully. Cleaning up installation files ..."
sudo rm -rf ~/$tmp_repo_dir

# Install desktop environment
if [ "$de_options" = 1 ]; then
    # Install Gnome and perform a full upgrade
    sudo pacman -Syyu gnome
    sudo systemctl enable gdm
elif [ "$de_options" = 2 ]; then
    # Install KDE Plasma and perform a full upgrade
    sudo pacman -Syyu plasma-desktop lightdm
    sudo systemctl enable lightdm.service
elif [ "$de_options" = 3 ]; then
    # Install KDE Plasma and perform a full upgrade
    sudo pacman -Syyu budgie-desktop gdm gnome-control-center gnome-terminal gnome-tweak-tool nautilus
    sudo systemctl enable gdm
fi

echo "---------------------------------------------------------------------"
echo "Install Video Accelaration"
echo "---------------------------------------------------------------------"

# tmp dir folder name
tmp_repo_dir="tmp-repo-dir"

# create and cd to a directory
cd ~/
mkdir $tmp_repo_dir
cd $tmp_repo_dir

# install from AUR
echo "Getting ffmpeg, rkmpp, and kodi from AUR ..."

# setup mpp-git
git clone https://aur.archlinux.org/mpp-git.git
cd mpp-git
makepkg -si
cd ..
echo "Installed mpp-git"

# setup ffmpeg4.4-mpp
git clone https://aur.archlinux.org/ffmpeg4.4-mpp.git
cd ffmpeg4.4-mpp
makepkg -si
cd ..
echo "Installed ffmpeg4.4-mpp"

# setup ffmpeg-mpp
git clone https://aur.archlinux.org/ffmpeg-mpp.git
cd ffmpeg-mpp
makepkg -si
cd ..
echo "Installed ffmpeg-mpp"

# setup kodi-stable-mpp-git
git clone https://aur.archlinux.org/kodi-stable-mpp-git.git
cd kodi-stable-mpp-git
makepkg -si
cd ..
echo "Installed kodi-stable-mpp-git"

# Add user to video group
current_user=$(whoami)
sudo usermod -A -g video $current_user

# Remove temp dir folder
echo "Installed successfully. Cleaning up installation files ..."
sudo rm -rf ~/$tmp_repo_dir

echo "---------------------------------------------------------------------"
echo "Install additional packages"
echo "---------------------------------------------------------------------"
echo ""
echo "Select a package to install :"
echo "1. Browser / Media"
echo "2. Gaming / Virtualization" 
echo "3. Misc / Tools"
echo "4. Others"
echo ""
echo "Pick an option (Enter 'done' when you finish) :"
#read answer
echo "This feature is not implemented / WIP, skipping ..."

echo "Setting up Browser Acceleration"

echo "This feature is not implemented / WIP, skipping ..."

# Prompt user if they want to reboot
read -t 5 -p "Changes have been made. We will reboot your system in 5 seconds. Do you want to reboot now? (y/n): " reboot_choice

if [[ "$reboot_choice" == "n" || "$reboot_choice" == "N" ]]; then
    echo "You can manually reboot later to apply the changes."
else
    echo "Done. Rebooting..."
    sudo reboot
fi