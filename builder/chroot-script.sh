#!/bin/bash
set -ex

### configure Debian Jessie base ###
if [[ "${VARIANT}" == "raspbian" ]]; then
  # for Rasbian we need an extra gpg key to be able to access the repository
  wget -v http://mirrordirector.raspbian.org/raspbian.public.key -O key
  apt-key add key
fi

# upgrade to latest Debian package versions
apt-get update
apt-get upgrade -y

### configure network and systemd services ###

# set ethernet interface eth0*to dhcp
tee /etc/systemd/network/eth.network << EOF
[Match]
Name=eth*

[Network]
DHCP=yes
EOF

# enable networkd
systemctl enable systemd-networkd

# configure and enable resolved
ln -sfv /run/systemd/resolve/resolv.conf /etc/resolv.conf
DEST=$(readlink -m /etc/resolv.conf)
mkdir -p "$(dirname "$DEST")"
touch /etc/resolv.conf
systemctl enable systemd-resolved

# enable ntp with timesyncd
sed -i 's|#Servers=|Servers=|g' /etc/systemd/timesyncd.conf
systemctl enable systemd-timesyncd

# set default locales to 'en_US.UTF-8'
echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen

echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections
dpkg-reconfigure -f noninteractive locales


### HypriotOS default settings ###

# set hostname
echo "$HYPRIOT_HOSTNAME" > /etc/hostname

# install skeleton files from /etc/skel for root user
cp /etc/skel/{.bash_prompt,.bashrc,.profile} /root/

# install Hypriot group and user
addgroup --system --quiet "$HYPRIOT_GROUPNAME"
useradd -m "$HYPRIOT_USERNAME" --group "$HYPRIOT_GROUPNAME" --shell /bin/bash
echo "$HYPRIOT_USERNAME:$HYPRIOT_PASSWORD" | /usr/sbin/chpasswd

# add user to sudoers group
echo "$HYPRIOT_USERNAME ALL=NOPASSWD: ALL" > "/etc/sudoers.d/user-$HYPRIOT_USERNAME"
chmod 0440 "/etc/sudoers.d/user-$HYPRIOT_USERNAME"

# set HypriotOS version infos
echo "HYPRIOT_OS=\"HypriotOS/${BUILD_ARCH}\"" >> /etc/os-release
echo "HYPRIOT_OS_VERSION=\"${HYPRIOT_OS_VERSION}\"" >> /etc/os-release
