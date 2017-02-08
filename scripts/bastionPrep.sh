#!/bin/bash
echo $(date) " - Starting Script"

USER=$1
PASSWORD="$2"
POOL_ID=$3

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

subscription-manager register --username="$USER" --password="$PASSWORD"
if [ $? -eq 0 ]
then
   echo "Subscribed successfully"
else
   echo "Incorrect Username and / or Password specified"
   exit 3
fi

subscription-manager attach --pool=$POOL_ID
if [ $? -eq 0 ]
then
   echo "Pool attached successfully"
else
   echo "Incorrect Pool ID or no entitlements available"
   exit 4
fi

# Disable all repositories and enable only the required ones
echo $(date) " - Disabling all repositories and enabling only the required repos"

subscription-manager repos --disable="*"

subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.4-rpms"

# Install base packages and update system to latest packages
echo $(date) " - Install base packages and update system to latest packages"

yum -y install wget git net-tools bind-utils iptables-services bridge-utils bash-completion httpd-tools
yum -y update --exclude=WALinuxAgent

# Install OpenShift utilities
echo $(date) " - Installing OpenShift utilities"

yum -y install atomic-openshift-utils

# Prereqs for NFS
# Create a lv with what's left in the docker-vg VG, which depends on disk size defined (100G disk = 60G free)
yum -y install nfs-utils
VGFREESPACE=$(vgs|grep docker-vg|awk '{ print $7 }'|sed 's/.00g/G/')
lvcreate -n lv_nfs -L+$VGFREESPACE docker-vg
mkfs.xfs /dev/mapper/docker--vg-lv_nfs
echo "/dev/mapper/docker--vg-lv_nfs /exports xfs defaults 0 0" >>/etc/fstab
mkdir /exports
mount -a
for item in registry metrics jenkins; do mkdir -p /exports/$item; done
chown nfsnobody:nfsnobody /exports -R
chmod a+rwx /exports -R

echo $(date) " - Script Complete"
