#!/bin/bash


function clean_up {
        echo "--- ERROR"
        exit 1
}

trap clean_up SIGHUP SIGINT SIGTERM


function title
{
    echo ""
    echo "============================================================================== "
    echo "--- $1"
    echo "============================================================================== "
}


VERSION="2.5.3"
BRO_URL="https://www.bro.org/downloads/bro-${VERSION}.tar.gz"
BRO=`basename ${BRO_URL} .tar.gz`
IPSUMDUMP_URL="http://www.read.seas.harvard.edu/~kohler/ipsumdump/ipsumdump-1.86.tar.gz"
IPSUMDUMP=`basename ${IPSUMDUMP_URL} .tar.gz`
GEOLITECITY_DB_URL="http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz"
GEOLITECITY_DB=`basename ${GEOLITECITY_DB_URL}`

title "Update OS"
yum clean all
yum -y update

title "Install epel-release wget net-tools"
yum -y install epel-release wget net-tools

title "Install Development Tools"
yum -y install cmake make gcc gcc-c++ flex bison libpcap-devel openssl-devel python-devel swig zlib-devel file-devel 

#
# Notes about some consistency facts: 
# -----------------------------------
# When installing on a VM, first update the kernel, create a new image and launch the VM from the updated image
# kernel-devel and kernel-headers should be consistent with the running kernel version. 
# Otherwise pf_ring kernel module will not be built
# 

title "Install kernel-devel kernel-headers"
yum -y install kernel-devel kernel-headers

title "Install PF_RING"
#cd ~
#yum -y install dkms
#wget http://packages.ntop.org/rpm7/noarch/PF_RING-dkms/pfring-dkms-7.1.0-1507.noarch.rpm
#wget http://packages.ntop.org/rpm7/x86_64/PF_RING/pfring-7.1.0-1507.x86_64.rpm
#yum -y localinstall pfring-*
#modprobe pf_ring enable_tx_capture=0 min_num_slots=32768

# Build pf_ring from source
title "PF_RING: lib"
cd ~
git clone https://github.com/ntop/PF_RING.git
cd PF_RING/userland/lib
./configure --prefix=/opt/pfring
make install

title "PF_RING: libpcap"
cd ../libpcap
./configure --prefix=/opt/pfring
make install

title "PF_RING: tcpdump"
cd ../tcpdump
./configure --prefix=/opt/pfring
make install

title "PF_RING: kernel"
cd ../../kernel
make 
make install

title "Install pf_ring module"
modprobe pf_ring enable_tx_capture=0 min_num_slots=32768
lsmod | grep pf_ring


title "Install GeoIP"
yum -y install GeoIP
wget ${GEOLITECITY_DB_URL}
gunzip ${GEOLITECITY_DB}
mv `basename ${GEOLITECITY_DB} .gz` /usr/share/GeoIP/GeoIPCity.dat

title "Install gperftools"
yum -y  install gperftools

title "Install IPSUMDUMP"
cd ~
wget ${IPSUMDUMP_URL}
tar xf `basename ${IPSUMDUMP_URL}` -C /opt && ln -s /opt/${IPSUMDUMP} /opt/ipsumdump
cd /opt/ipsumdump
./configure --prefix=/opt/ipsumdump
make && make install 

title "Install BRO"
cd ~
wget ${BRO_URL}
tar xf `basename ${BRO_URL}` -C /opt && ln -s /opt/${BRO} /opt/bro
cd /opt/bro
./configure --prefix=/opt/bro --with-pcap=/opt/pfring
make && make install

