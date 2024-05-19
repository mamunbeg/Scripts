#!/bin/bash
### run post Ubuntu install

serial=$(sudo dmidecode -s system-serial-number)
new_hostname="CAP-"$serial
sudo hostnamectl set-hostname $new_hostname
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$new_hostname/g" /etc/hosts

sudo apt update
sudo apt install curl git

### Uninstall Snap and install Flatpak

sudo systemctl stop var-snap.mount
sudo systemctl disable var-snap.mount

cd ~/
git clone https://github.com/MasterGeekMX/snap-to-flatpak.git
chmod +x ~/snap-to-flatpak/snap-to-flatpak.sh
~/snap-to-flatpak/snap-to-flatpak.sh
rm -rf ~/snap-to-flatpak

echo '
Package: snapd
Pin: release a=*
Pin-Priority: -10
' | sudo tee /etc/apt/preferences.d/nosnap.pref

flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

sudo apt update
sudo apt dist-upgrade

### Install flatpaks

flatpak install flathub com.mattjakeman.ExtensionManager
flatpak install flathub org.mozilla.firefox
flatpak install flathub com.microsoft.Edge
flatpak install flathub org.remmina.Remmina
flatpak install flathub org.onlyoffice.desktopeditors
# flatpak install flathub org.gnome.Evolution
flatpak install flathub org.gnome.Snapshot
flatpak install flathub org.gnome.Photos
flatpak install flathub org.gnome.baobab
flatpak install flathub us.zoom.Zoom
# flatpak install flathub org.gnome.Boxes
flatpak install flathub com.visualstudio.code
flatpak install flathub org.wireshark.Wireshark
flatpak install flathub org.videolan.VLC
flatpak install flathub io.gitlab.zehkira.Monophony
flatpak install flathub org.nickvision.tubeconverter
flatpak install flathub de.haeckerfelix.Fragments
flatpak install flathub org.ppsspp.PPSSPP

### Install Powershell

sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell

<<comment ------------------------------------------------------------------------------

### Install deb packages

### Install Mozilla Firefox

sudo add-apt-repository ppa:mozillateam/ppa
sudo apt update
sudo apt install firefox

### Install Microsoft Edge

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge.list'
sudo rm microsoft.gpg
sudo apt update && sudo apt install microsoft-edge-stable

comment

### Add fingerprint authentication for sudo

sudo pam-auth-update


