#!/bin/bash

############################################################
# Hadoop section copied from hadoop recipe:
# https://github.com/RENCI-NRIG/exogeni-recipes/tree/master/hadoop/hadoop-2.7.3/hadoop_exogeni_postboot.txt
############################################################

HADOOP_VERSION=hadoop-2.7.3

# setup /etc/hosts
############################################################
echo $NameNode.IP("VLAN0") $NameNode.Name() >> /etc/hosts
echo $ResourceManager.IP("VLAN0") $ResourceManager.Name() >> /etc/hosts
#set ( $sizeWorkerGroup = $Workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 echo $Workers.get($j).IP("VLAN0") `echo $Workers.get($j).Name() | sed 's/\//-/g'` >> /etc/hosts
#end

echo `echo $self.Name() | sed 's/\//-/g'` > /etc/hostname
/bin/hostname -F /etc/hostname

# Install Java
############################################################
yum makecache fast
yum -y update
yum install -y wget java-1.8.0-openjdk-devel

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

# Install Hadoop
############################################################
mkdir -p /opt/${HADOOP_VERSION}
curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/hadoop/common/${HADOOP_VERSION}/${HADOOP_VERSION}.tar.gz > /opt/${HADOOP_VERSION}.tgz
tar -C /opt/${HADOOP_VERSION} --extract --file /opt/${HADOOP_VERSION}.tgz --strip-components=1
rm -f /opt/${HADOOP_VERSION}.tgz*

export HADOOP_PREFIX=/opt/${HADOOP_VERSION}
export HADOOP_YARN_HOME=${HADOOP_PREFIX}
HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop

cat > /etc/profile.d/hadoop.sh << EOF
export HADOOP_PREFIX=${HADOOP_PREFIX}
export HADOOP_YARN_HOME=${HADOOP_PREFIX}
export HADOOP_CONF_DIR=${HADOOP_PREFIX}/etc/hadoop
export PATH=\$HADOOP_PREFIX/bin:\$PATH
EOF

# Configure Hadoop
############################################################
CORE_SITE_FILE=${HADOOP_CONF_DIR}/core-site.xml
HDFS_SITE_FILE=${HADOOP_CONF_DIR}/hdfs-site.xml
MAPRED_SITE_FILE=${HADOOP_CONF_DIR}/mapred-site.xml
YARN_SITE_FILE=${HADOOP_CONF_DIR}/yarn-site.xml
SLAVES_FILE=${HADOOP_CONF_DIR}/slaves

echo "hadoop_exogeni_postboot: configuring Hadoop"

cat > $CORE_SITE_FILE << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
   <name>fs.default.name</name>
   <value>hdfs://$NameNode.Name():9000</value>
  </property>
</configuration>
EOF

cat > $HDFS_SITE_FILE << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
  <property>
   <name>dfs.replication</name>
   <value>2</value>
  </property>
</configuration>
EOF

cat > $MAPRED_SITE_FILE << EOF
<configuration>
 <property>
   <name>mapreduce.framework.name</name>
   <value>yarn</value>
 </property>
</configuration>
EOF

cat > $YARN_SITE_FILE << EOF
<?xml version="1.0"?>
<configuration>
<!-- Site specific YARN configuration properties -->
 <property>
   <name>yarn.resourcemanager.hostname</name>
   <value>$ResourceManager.Name()</value>
 </property>
</configuration>
EOF

cat > $SLAVES_FILE << EOF
#set ( $sizeWorkerGroup = $Workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 `echo $Workers.get($j).Name() | sed 's/\//-/g'` 
#end
EOF

# Why is the firewall not cooperating??
# This should probably work, but it is not currently
echo "hadoop_exogeni_postboot: attempting to fix eth0 trusted zone"
nmcli connection modify eth0 connection.zone internal

# Start Hadoop
############################################################
echo "hadoop_exogeni_postboot: starting Hadoop"

if [[ $self.Name() == NameNode ]]
then
  $HADOOP_PREFIX/bin/hdfs namenode -format
  $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
elif [[ $self.Name() == ResourceManager ]]
then
  $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
elif [[ $self.Name() == Workers* ]]
then
  $HADOOP_PREFIX/sbin/hadoop-daemons.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
  $HADOOP_YARN_HOME/sbin/yarn-daemons.sh --config $HADOOP_CONF_DIR start nodemanager
fi


############################################################
# ZooKeeper
# Assumes cluster has already been configured for Hadoop
############################################################

ZOOKEEPER_VERSION=zookeeper-3.4.6

# setup /etc/hosts
############################################################
echo $AccumuloMaster.IP("VLAN0") $AccumuloMaster.Name() >> /etc/hosts
echo $NameNode.IP("VLAN0") zoo1 >> /etc/hosts
echo $ResourceManager.IP("VLAN0") zoo2 >> /etc/hosts
echo $AccumuloMaster.IP("VLAN0") zoo3 >> /etc/hosts

# Install ZooKeeper
############################################################
mkdir -p /opt/${ZOOKEEPER_VERSION}
wget -nv --output-document=/opt/${ZOOKEEPER_VERSION}.tgz https://dist.apache.org/repos/dist/release/zookeeper/${ZOOKEEPER_VERSION}/${ZOOKEEPER_VERSION}.tar.gz
tar -C /opt --extract --file /opt/${ZOOKEEPER_VERSION}.tgz
rm /opt/${ZOOKEEPER_VERSION}.tgz*

export ZOOKEEPER_HOME=/opt/${ZOOKEEPER_VERSION}

cat > /etc/profile.d/zookeeper.sh << EOF
export ZOOKEEPER_HOME=/opt/${ZOOKEEPER_VERSION}
export ZOO_DATADIR_AUTOCREATE_DISABLE=1
export PATH=\$ZOOKEEPER_HOME/bin:\$PATH
EOF

# Configure ZooKeeper
############################################################
ZOOKEEPER_DATADIR=/var/lib/zookeeper/
mkdir -p ${ZOOKEEPER_DATADIR}

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

if [[ $self.Name() == NameNode ]]
then
  echo 1 > ${ZOOKEEPER_DATADIR}/myid
elif [[ $self.Name() == ResourceManager ]]
then
  echo 2 > ${ZOOKEEPER_DATADIR}/myid
elif [[ $self.Name() == AccumuloMaster ]]
then
  echo 3 > ${ZOOKEEPER_DATADIR}/myid
fi

# Start ZooKeeper
############################################################
if [[ $self.Name() == NameNode ]] || [[ $self.Name() == ResourceManager ]] || [[ $self.Name() == AccumuloMaster ]]
then
  echo "accumulo_exogeni_postboot: starting ZooKeeper"
  ${ZOOKEEPER_HOME}/bin/zkServer.sh start
fi


############################################################
# Accumulo
# Assumes cluster has already been configured for Hadoop and Zookeeper
############################################################


