#!/bin/bash


ZOOKEEPER_VERSION=zookeeper-3.4.6
KAFKA_VERSION=1.0.0

# Velocity Hacks
#set( $bash_var = '${' )
#set( $bash_str_split = '#* ' )
############################################################

# setup /etc/hosts
############################################################
echo $kafka0.IP("VLAN0") $kafka0.Name() >> /etc/hosts
echo $kafka1.IP("VLAN0") $kafka1.Name() >> /etc/hosts
echo $kafka2.IP("VLAN0") $kafka2.Name() >> /etc/hosts
echo $kafka0.IP("VLAN0") zoo1 >> /etc/hosts
echo $kafka1.IP("VLAN0") zoo2 >> /etc/hosts
echo $kafka2.IP("VLAN0") zoo3 >> /etc/hosts

echo `echo $self.Name() | sed 's/\//-/g'` > /etc/hostname
/bin/hostname -F /etc/hostname

# Install Java
############################################################
yum makecache fast
yum --assumeyes update # disabled only during testing. should be enabled in production
yum install --assumeyes wget java-1.8.0-openjdk-devel

export JAVA_HOME=$(readlink --canonicalize /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink --canonicalize /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF


# Configure iptables for Hadoop (Centos 6)
############################################################
# https://www.vultr.com/docs/setup-iptables-firewall-on-centos-6
iptables --flush; iptables --delete-chain; iptables --zero
#Allow all loopback (lo) traffic and drop all traffic to 127.0.0.0/8 other than lo:
iptables --append INPUT --in-interface lo --jump ACCEPT
iptables --append INPUT --destination 127.0.0.0/8 --jump REJECT
#Block some common attacks:
iptables --append INPUT --protocol tcp ! --syn -m state --state NEW --jump DROP
iptables --append INPUT --protocol tcp --tcp-flags ALL NONE --jump DROP
iptables --append INPUT --protocol tcp --tcp-flags ALL ALL --jump DROP
#Accept all established inbound connections:
iptables --append INPUT -m state --state ESTABLISHED,RELATED --jump ACCEPT
#Allow SSH connections:
iptables --append INPUT --protocol tcp --dport 22 --jump ACCEPT

# Allow internal cluster connections
iptables --append INPUT --in-interface eth1 --jump ACCEPT

#Node specific iptables config


# complete the iptables config
#set the default policies:
iptables --policy INPUT DROP
iptables --policy OUTPUT ACCEPT
iptables --policy FORWARD DROP
#Save the iptables configuration with the following command:
service iptables save


############################################################
# ZooKeeper
# https://zookeeper.apache.org/doc/r3.4.6/zookeeperStarted.html
############################################################

export ZOOKEEPER_HOME=/opt/${ZOOKEEPER_VERSION}
export ZOOKEEPER_DATADIR=/var/lib/zookeeper/

# Install ZooKeeper
############################################################
mkdir --parents ${ZOOKEEPER_HOME}
echo "kafka_exogeni_postboot: downloading ZooKeeper"

wget --no-verbose --output-document=/opt/${ZOOKEEPER_VERSION}.tgz "https://www.apache.org/dyn/closer.cgi?action=download&filename=/zookeeper/${ZOOKEEPER_VERSION}/${ZOOKEEPER_VERSION}.tar.gz"
tar --directory=/opt --extract --file /opt/${ZOOKEEPER_VERSION}.tgz
rm /opt/${ZOOKEEPER_VERSION}.tgz*

cat > /etc/profile.d/zookeeper.sh << EOF
export ZOOKEEPER_HOME=${ZOOKEEPER_HOME}
export ZOO_DATADIR_AUTOCREATE_DISABLE=1
export PATH=\$ZOOKEEPER_HOME/bin:\$PATH
export ZOOKEEPER_DATADIR=${ZOOKEEPER_DATADIR}
EOF

# Configure ZooKeeper
############################################################
mkdir --parents ${ZOOKEEPER_DATADIR}
echo "kafka_exogeni_postboot: configuring ZooKeeper"

cat > ${ZOOKEEPER_HOME}/conf/zoo.cfg << EOF
# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial 
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between 
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
dataDir=${ZOOKEEPER_DATADIR}
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the 
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1
server.1=zoo1:2888:3888
server.2=zoo2:2888:3888
server.3=zoo3:2888:3888
EOF

if [[ $self.Name() == kafka0 ]]
then
  echo 1 > ${ZOOKEEPER_DATADIR}/myid
elif [[ $self.Name() == kafka1 ]]
then
  echo 2 > ${ZOOKEEPER_DATADIR}/myid
elif [[ $self.Name() == kafka2 ]]
then
  echo 3 > ${ZOOKEEPER_DATADIR}/myid
fi

# Start ZooKeeper
############################################################
if [[ $self.Name() == kafka0 ]] || [[ $self.Name() == kafka1 ]] || [[ $self.Name() == kafka2 ]]
then
  echo "kafka_exogeni_postboot: starting ZooKeeper"
  ${ZOOKEEPER_HOME}/bin/zkServer.sh start
fi


############################################################
# Kafka
# Assumes cluster has already been configured for Zookeeper
# https://kafka.apache.org/quickstart
############################################################
export KAFKA_HOME=/opt/kafka_2.11-${KAFKA_VERSION}
export KAFKA_DATADIR=/var/lib/kafka/
export KAFKA_SERVER_CONF=${KAFKA_HOME}/config/server.properties

# Install Kafka
############################################################
mkdir --parents ${KAFKA_HOME}
echo "kafka_exogeni_postboot: downloading Kafka"

curl --location --insecure --show-error "https://www.apache.org/dyn/closer.cgi?action=download&filename=/kafka/${KAFKA_VERSION}/kafka_2.11-${KAFKA_VERSION}.tgz" > /opt/kafka_2.11-${KAFKA_VERSION}.tgz
tar --directory=/opt/kafka_2.11-${KAFKA_VERSION} --extract --file /opt/kafka_2.11-${KAFKA_VERSION}.tgz --strip-components=1
rm --force /opt/kafka_2.11-${KAFKA_VERSION}.tgz*

cat > /etc/profile.d/kafka.sh << EOF
export KAFKA_HOME=${KAFKA_HOME}
#export PATH=\$KAFKA_HOME/bin:\$PATH
export KAFKA_DATADIR=${KAFKA_DATADIR}
export KAFKA_SERVER_CONF=${KAFKA_SERVER_CONF}
EOF

# Configure Kafka
############################################################
echo "kafka_exogeni_postboot: configuring Kafka"

KAFKA_SERVER_CONF=${KAFKA_HOME}/config/server.properties
mkdir --parents ${KAFKA_DATADIR}

# The id of the broker. This must be set to a unique integer for each broker.
if [[ $self.Name() == kafka0 ]]
then
  sed --in-place '/broker.id=0/s/0/0/' ${KAFKA_SERVER_CONF}
elif [[ $self.Name() == kafka1 ]]
then
  sed --in-place '/broker.id=0/s/0/1/' ${KAFKA_SERVER_CONF}
elif [[ $self.Name() == kafka2 ]]
then
  sed --in-place '/broker.id=0/s/0/2/' ${KAFKA_SERVER_CONF}
fi

# Zookeeper connection string (see zookeeper docs for details).
sed --in-place '/zookeeper.connect=localhost:2181/s/localhost:2181/zoo1:2181,zoo2:2181,zoo3:2181/' ${KAFKA_SERVER_CONF}

# A comma seperated list of directories under which to store log files
sed --in-place "\|log.dirs=/tmp/kafka-logs|s|/tmp/kafka-logs|${KAFKA_DATADIR}|" ${KAFKA_SERVER_CONF}

# The default number of log partitions per topic.
sed --in-place '/num.partitions=1/s/1/1/' ${KAFKA_SERVER_CONF}

# Start Kafka
############################################################
if [[ $self.Name() == kafka0 ]] || [[ $self.Name() == kafka1 ]] || [[ $self.Name() == kafka2 ]]
then
  # Need to wait for Zookeeper quorum before starting Kafka
  echo "kafka_exogeni_postboot: detecting Zookeeper quorum..."
  until ${ZOOKEEPER_HOME}/bin/zkServer.sh status ; do sleep 2; done

  echo "kafka_exogeni_postboot: starting Kafka"
  ${KAFKA_HOME}/bin/kafka-server-start.sh -daemon ${KAFKA_SERVER_CONF}
fi


