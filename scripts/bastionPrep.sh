#!/bin/bash
echo $(date) " - Starting Script"

ORG=$1
ACT_KEY="$2"
POOL_ID=$3

# Register Host with Cloud Access Subscription
echo $(date) " - Register host with Cloud Access Subscription"

subscription-manager register --org="$ORG" --activationkey="$ACT_KEY"
if [ $? -eq 0 ]
then
   echo "Subscribed successfully"
else
   echo "Incorrect Organization ID and / or Activation Key specified"
   exit 3
fi

subscription-manager attach --pool=$POOL_ID > attach.log
if [ $? -eq 0 ]
then
   echo "Pool attached successfully"
else
   evaluate=$( cut -f 2-5 -d ' ' attach.log )
   if [[ $evaluate == "unit has already had" ]]
      then
	     echo "Pool was already attached and was not attached again."
		 exit 0
	  else
         echo "Incorrect Pool ID or no entitlements available"
         exit 4
   fi
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

echo $(date) " - Script Complete"
