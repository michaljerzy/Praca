#!/bin/bash


# I use the repository, Jim Angel "jimangel" and I made changes to the ubuntu 20 version.

sudo su


#update apt-cache
apt update -y
apt upgrade -y

# most likely is already installed
apt -y install open-vm-tools

#Stop services for cleanup
service rsyslog stop



if [ `id -u` -ne 0 ]; then
	echo Need sudo
	exit 1
fi

set -v



#install packages
apt install -y open-vm-tools

#Stop services for cleanup
service rsyslog stop

#clear audit logs
if [ -f /var/log/wtmp ]; then
    truncate -s0 /var/log/wtmp
fi
if [ -f /var/log/lastlog ]; then
    truncate -s0 /var/log/lastlog
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

#cleanup current ssh keys
rm -f /etc/ssh/ssh_host_*

#add check for ssh keys on reboot...regenerate if neccessary
cat << 'EOL' | sudo tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.
# dynamically create hostname (optional)
if hostname | grep localhost; then
    hostnamectl set-hostname "$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')"
fi
test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server
exit 0
EOL

# make sure the script is executable
chmod +x /etc/rc.local

#reset hostname
# prevent cloudconfig from preserving the original hostname
sed -i 's/preserve_hostname: false/preserve_hostname: true/g' /etc/cloud/cloud.cfg
truncate -s0 /etc/hostname
hostnamectl set-hostname localhost

#cleanup apt
apt clean

# disable swap
swapoff --all
sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab

# set dhcp to use mac - this is a little bit of a hack but I need this to be placed under the active nic settings
# also look in /etc/netplan for other config files
sed -i 's/optional: true/dhcp-identifier: mac/g' /etc/netplan/01-network-manager-all.yaml 


# cleans out all of the cloud-init cache / logs - this is mainly cleaning out networking info
apt-get install cloud-init
cloud-init clean --logs

#cleanup shell history
cat /dev/null > ~/.bash_history && history -c
history -w

#shutdown
shutdown -h now
