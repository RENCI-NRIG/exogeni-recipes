#!/bin/bash

{

#
# Install Git
#

sudo yum -y install git vim 
sudo yum -y net-tools

#
# Clone Security Onion 
#

SO2_REPO="https://github.com/Security-Onion-Solutions/securityonion"
TAG="2.3.120"

git clone ${SO2_REPO} securityonion
cd securityonion
git checkout tags/${TAG}

#
# Generate automation answerfile 
#

cd setup
ANSWER_FILE_TEMPLATE="standalone-net-centos"
ANSWER_FILE_CUSTOM="standalone-net-centos-custom"

cp automation/${ANSWER_FILE_TEMPLATE} automation/${ANSWER_FILE_CUSTOM}

#
# Modify variables (see so-whiptail)
#

# Manager Server Hostname
HOSTNAME=$(hostname | cut -d"." -f 1)
sed -i -r "s/.*(HOSTNAME=).*/\1${HOSTNAME}/g" automation/${ANSWER_FILE_CUSTOM}

# Allowed IP or Subnet
ALLOW_CIDR="192.168.0.0\/16"
sed -i -r "s/(^ALLOW_CIDR=).*/\1${ALLOW_CIDR}/g" automation/${ANSWER_FILE_CUSTOM}

# NICs to the Monitor Interface
BNICS=ens224
sed -i -r "s/(^BNICS=).*/\1${BNICS}/g" automation/${ANSWER_FILE_CUSTOM}

# Management NIC
MNIC=ens192
sed -i -r "s/(^MNIC=).*/\1${MNIC}/g" automation/${ANSWER_FILE_CUSTOM}

# Management DNS
MDNS="\"8.8.8.8 8.8.4.4\""
sed -i -r "s/.*(MDNS=).*/\1${MDNS}/g" automation/${ANSWER_FILE_CUSTOM}

# Management Gateway
MGATEWAY=$(ip route | grep default | awk '{print $3}')
sed -i -r "s/.*(MGATEWAY=).*/\1${MGATEWAY}/g" automation/${ANSWER_FILE_CUSTOM}

# Management IP
MIP=$(ip  -f inet a show dev ${MNIC} | grep 'inet' | awk '{print $2}' | sed 's/\/.*//g')
sed -i -r "s/.*(MIP=).*/\1${MIP}/g" automation/${ANSWER_FILE_CUSTOM}

# Management Netmask
MMASK=$(ifconfig ${MNIC}| awk '/netmask/{ print $4;}')
sed -i -r "s/.*(MMASK=).*/\1${MMASK}/g" automation/${ANSWER_FILE_CUSTOM}

# Management DNS search domain
MSEARCH="renci.ben"
sed -i -r "s/.*(MSEARCH=).*/\1${MSEARCH}/g" automation/${ANSWER_FILE_CUSTOM}

# Manager Server Hostname
MSRV=$(hostname | cut -d"." -f 1)
sed -i -r "s/.*(MSRV=).*/\1${MSRV}/g" automation/${ANSWER_FILE_CUSTOM}

# MTU for the monitor NICs
MTU="9000"
sed -i -r "s/.*(MTU=).*/\1${MTU}/g" automation/${ANSWER_FILE_CUSTOM}

# Administrator account for the web interfaces
WEBUSER=admin@securityonion.net
sed -i -r "s/(^WEBUSER=).*/\1${WEBUSER}/g" automation/${ANSWER_FILE_CUSTOM}

# Administrator account password
WEBPASSWD1=0n10nus3r
sed -i -r "s/(^WEBPASSWD1=).*/\1${WEBPASSWD1}/g" automation/${ANSWER_FILE_CUSTOM}

# Repeat administrator password
WEBPASSWD2=0n10nus3r
sed -i -r "s/(^WEBPASSWD2=).*/\1${WEBPASSWD2}/g" automation/${ANSWER_FILE_CUSTOM}


#
# Install 
#
sudo bash so-setup network standalone-net-centos-custom

echo "Security Onion installation is completed ..." 

} > /tmp/boot.log 2>&1
