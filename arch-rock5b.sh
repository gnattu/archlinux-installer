#!/bin/bash

################################################################
#                                                              #
#  Arch Linux image / disk creation tool for Rock 5B / RK3588  #
#                                                              #
################################################################

# Function to display a list of available disks
list_disks() {
  echo "Available disks:"
  disks=($(lsblk -rdno NAME,SIZE,MODEL))
  for ((i=0; i<${#disks[@]}; i+=3)); do
    model=${disks[i+2]//\\x20/ }  # Replace escaped spaces with actual spaces
    echo "$((i/3+1))) /dev/${disks[i]} - $model (${disks[i+1]})"
  done
  echo "$((i/3+1))) Create an (.img) image"
  echo "$((i/3+2))) Enter disk path manually"
}

# Function to prompt user for disk selection
select_disk() {
  read -p "Select a disk or enter path: " choice
  if [[ $choice =~ ^[0-9]+$ && $choice -ge 1 && $choice -le $((i/3+2)) ]]; then
    if [[ $choice -le $((i/3)) ]]; then
      selected_disk="/dev/${disks[((choice-1)*3)]}"
      echo "Selected disk $selected_disk."
    elif [[ $choice -eq $((i/3+1)) ]]; then
      selected_disk="/out/archlinux.img"
      echo "Creating an (.img) image at $selected_disk."
    else
      read -p "Enter the disk path: " selected_disk
      echo "Manually entered disk path $selected_disk."
    fi
  else
    echo "Invalid choice. Please select a valid option."
    select_disk
  fi
}

# Sees if it is a help command or normal command with parameters
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage : To be written"
  exit 1
else
  echo "---------------------------------------------------------------------"
  echo "Welcome to Arch Linux image / disk creation tool for Rock 5B / RK3588"
  echo "---------------------------------------------------------------------"
  drive=$1
fi

# Check if parted is installed
if ! [ -x "$(command -v parted)" ]; then
  # Check Linux distribution
  echo "Parted is not found, trying to install..."
  if [ -f /etc/lsb-release ] || [ -x "$(command -v apt-get)" ]; then
    # Debian/Ubuntu-based
    sudo apt-get update
    sudo apt-get install -y parted libarchive-tools
  elif [ -f /etc/redhat-release ]; then
    # Red Hat-based
    sudo yum update
    sudo yum install -y parted libarchive-tools
  elif [ -f /etc/arch-release ]; then
    # Arch Linux
    sudo pacman -S parted --noconfirm
  elif [ -x "$(command -v apk)" ]; then
    # Alphine-based
    apk add parted libarchive-tools
  else
    echo "Error : We cant find or install parted on your system. Exiting..."
    exit 1
  fi

# Verify if it is installed
echo "---------------------------------------------------------------------"
if [ -x "$(command -v parted)" ]; then
  echo "Package installed, continuing..."
  echo "---------------------------------------------------------------------"
else
  echo "Error : Package not installed, please check your package manager / internet connection / system. Exiting..."
  exit 1
fi
fi

# This runs when there is no parameters specified
# Choose drive to install / create .img image
if [ -z $drive ]; then
  echo "Choose drive to install or create an image:"
  list_disks
  select_disk
  if [ $selected_disk == "/out/archlinux.img" ]; then
    if [ ! -d "./out" ]; then
      sudo mkdir ./out
    fi
    drive=./out/archlinux.img
    sudo dd if=/dev/zero of=$drive bs=1M count=4096
  else
    drive=$selected_disk
    echo "Are you sure to set up disk $selected_disk (WARNING : all data of the disk will be deleted) ? (y/n)"
    read answer
    if [ $answer = "n" ]; then
      echo "Aborted. Exiting ..."
      exit 1
    fi
  fi
fi

# boot partition image if not specified
boot_image=$2

if [ -z $boot_image ]; then
  if [ -z $2 ]; then
    echo "Do you want to download the required boot partition image? (Leave empty or enter "y" to download automatically or Enter the path if you have your own boot image instead (e.g. /path/to/boot.tar.gz or /path/to/boot.img)"
    read answer
    if [ "$answer" = "y" ] || [ "$answer" = "yes" ] || [ "$answer" = "" ] || [ ! "$answer" ]; then
      curl -LJO https://github.com/kwankiu/archlinux-installer-rock5/releases/download/latest/boot-arch-rkbsp-latest.tar.gz
      boot_image="boot-arch-rkbsp-latest.tar.gz"
    else
      boot_image=answer
    fi
   else
    echo "Please specify a boot image (e.g. /path/to/boot.tar.gz or /path/to/boot.img)"
    exit 1
   fi
fi

root_mount_dir=$(mktemp -d)
boot_mount_dir=$(mktemp -d)
boot_img_mount_dir=$(mktemp -d)

# Unmount all partitions of the specified drive
partitions=$(ls ${drive}* 2>/dev/null)
if [ "$partitions" ]; then
  for partition in $partitions; do
    sudo umount $partition 2>/dev/null || true
  done
fi

# Create GPT table and partitions
sudo parted $drive mklabel gpt
sudo parted $drive mkpart primary fat32 0% 500MB
sudo parted $drive mkpart primary ext4 500MB 100%

# Find the partitions
root_partition=$drive"2"
boot_partition=$drive"1"

# Format the partitions
sudo mkfs.ext4 $root_partition
sudo mkfs.fat -F32 $boot_partition

# Mount the partitions
sudo mount $root_partition $root_mount_dir
sudo mount $boot_partition $boot_mount_dir

# Download and extract the latest ArchLinux tarball
curl -LJO http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
sudo bsdtar -xpf ArchLinuxARM-aarch64-latest.tar.gz -C $root_mount_dir

# Extract the boot image
if [ ${boot_image: -4} == ".img" ]; then
  sudo mount $boot_image $boot_img_mount_dir
  sudo cp -R $boot_img_mount_dir/* $boot_mount_dir
  sudo umount $boot_img_mount_dir
  rm -rf $boot_img_mount_dir
elif [ ${boot_image: -7} == ".tar.gz" ]; then
  # Extract the .tar.gz file to a temporary directory
  boot_tar_dir=$(mktemp -d)
  sudo tar -xf "$boot_image" -C "$boot_tar_dir"

  # Copy contents to boot partition
  sudo cp -r "$boot_tar_dir"/* "$boot_mount_dir"

  # Remove the temporary directory
  sudo rm -rf "$boot_tar_dir"
else
  echo "Unsupported file format. Exiting."
  exit 1
fi

# Find the UUIDs of the root partition
root_uuid=$(sudo blkid $root_partition | awk '{print $2}' | tr -d '"')
root_part_uuid=$(sudo blkid -o export $root_partition | grep PARTUUID | awk -F= '{print $2}')

echo "Root partition UUID: $root_uuid"
echo "Root partition PARTUUID: $root_part_uuid"

# Change UUID for extlinux.conf


# Unmount the boot and root partitions
sudo umount $boot_mount_dir $root_mount_dir

# Clean up
sudo rm -rf $boot_mount_dir $root_mount_dir ArchLinuxARM-aarch64-latest.tar.gz boot-arch-rkbsp-latest.tar.gz

echo "Process completed successfully"
