#!/bin/bash

# 

# setup /etc/hosts
############################################################
echo $bgfed0.IP("VLAN0") $bgfed0.Name() >> /etc/hosts
echo $bgfed1.IP("VLAN0") $bgfed1.Name() >> /etc/hosts
echo $bgfed2.IP("VLAN0") $bgfed2.Name() >> /etc/hosts


echo $(echo $self.Name() | sed 's/\//-/g') > /etc/hostname
/bin/hostname -F /etc/hostname

# Install Java
############################################################
yum makecache fast
#yum -y update
yum install -y wget java-1.8.0-openjdk-devel
#apt install -y openjdk-9-jdk

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

# Install Java
############################################################
curl --location --insecure --show-error https://sourceforge.net/projects/bigdata/files/bigdata/2.1.4/blazegraph.rpm/download > blazegraph.rpm

yum install -y blazegraph.rpm

