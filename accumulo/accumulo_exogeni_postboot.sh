#!/bin/bash

############################################################
# Hadoop section copied from hadoop recipe:
# https://github.com/RENCI-NRIG/exogeni-recipes/tree/master/hadoop/hadoop-2.7.3/hadoop_exogeni_postboot.txt
############################################################

# using stable2 link for Hadoop Version
# HADOOP_VERSION=hadoop-2.7.3

# Velocity Hacks
#set( $bash_var = '${' )
#set( $bash_str_split = '#* ' )
############################################################

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
yum -y update # disabled only during testing. should be enabled in production
yum install -y wget java-1.8.0-openjdk-devel

export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

cat > /etc/profile.d/java.sh << EOF
export JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:/bin/java::")
export PATH=\$JAVA_HOME/bin:\$PATH
EOF

# Install Hadoop
############################################################
stable2=$(curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/hadoop/common/stable2)
# stable2 should look like: link hadoop-2.7.4
HADOOP_VERSION=${bash_var}stable2${bash_str_split}}
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

# Configure iptables for Hadoop (Centos 6)
############################################################
# https://www.vultr.com/docs/setup-iptables-firewall-on-centos-6
iptables -F; iptables -X; iptables -Z
#Allow all loopback (lo) traffic and drop all traffic to 127.0.0.0/8 other than lo:
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -d 127.0.0.0/8 -j REJECT
#Block some common attacks:
iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
#Accept all established inbound connections:
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
#Allow SSH connections:
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow internal cluster connections
iptables -I INPUT -i eth1 -p tcp -j ACCEPT

#Node specific iptables config
if [[ $self.Name() == NameNode ]]
then
  # connections to namenode allowed from outside the cluster
  iptables -A INPUT -p tcp --dport 50070 -j ACCEPT
elif [[ $self.Name() == ResourceManager ]]
then
  # connections to resource manager from outside the cluster
  iptables -A INPUT -p tcp --dport 8088 -j ACCEPT
elif [[ $self.Name() == Workers* ]]
then
  # TODO ?
  : #no-op
elif [[ $self.Name() == AccumuloMaster ]]
then
  # connections to accumulo monitor from outside the cluster
  iptables -A INPUT -p tcp --dport 9995 -j ACCEPT
fi

# complete the iptables config
#set the default policies:
iptables -P INPUT DROP
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP
#Save the iptables configuration with the following command:
service iptables save

# Create hadoop user and setup SSH
############################################################
useradd -U hadoop
mkdir /home/hadoop/.ssh

# Namenode will generate private SSH key
if [[ $self.Name() == NameNode ]]
then
  ssh-keygen -t rsa -N "" -f /home/hadoop/.ssh/id_rsa
  cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys

  # allow cluster to download SSH public key
  # port is only accessible to internal cluster
  mkdir /public_html
  cp -u /home/hadoop/.ssh/id_rsa.pub /public_html/
  (cd /public_html; python -c 'import SimpleHTTPServer,BaseHTTPServer; BaseHTTPServer.HTTPServer(("", 8080), SimpleHTTPServer.SimpleHTTPRequestHandler).serve_forever()') &
else
  # Need to download SSH public key from master
  until wget -O /home/hadoop/.ssh/id_rsa.pub "http://namenode:8080/id_rsa.pub"
  do
    sleep 2
  done
  cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys
fi

# Add host RSA keys to SSH known hosts files
# Need to wait until these succeed
until ssh-keyscan namenode >> /home/hadoop/.ssh/known_hosts; do sleep 2; done
until ssh-keyscan resourcemanager >> /home/hadoop/.ssh/known_hosts; do sleep 2; done
#set ( $sizeWorkerGroup = $Workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
  until ssh-keyscan `echo $Workers.get($j).Name() | sed 's/\//-/g'` >> /home/hadoop/.ssh/known_hosts
  do
    sleep 2
  done
#end

# Fix permissions in .ssh
chown -R hadoop:hadoop /home/hadoop/.ssh
chmod -R g-w /home/hadoop/.ssh
chmod -R o-w /home/hadoop/.ssh

# see if the NameNode can copy private key to other nodes
if [[ $self.Name() == NameNode ]]
then
  until sudo -u hadoop scp -o BatchMode=yes /home/hadoop/.ssh/id_rsa resourcemanager:/home/hadoop/.ssh/id_rsa; do sleep 2; done
  #set ( $sizeWorkerGroup = $Workers.size() - 1 )
  #foreach ( $j in [0..$sizeWorkerGroup] )
    until sudo -u hadoop scp -o BatchMode=yes /home/hadoop/.ssh/id_rsa `echo $Workers.get($j).Name() | sed 's/\//-/g'`:/home/hadoop/.ssh/id_rsa
    do
      sleep 2
    done
  #end
fi

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
  <property>
    <name>yarn.resourcemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
</configuration>
EOF

cat > $SLAVES_FILE << EOF
#set ( $sizeWorkerGroup = $Workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 `echo $Workers.get($j).Name() | sed 's/\//-/g'`
#end
EOF

# make sure the hadoop user owns /opt/hadoop
chown -R hadoop:hadoop ${HADOOP_PREFIX}

# Centos 7 only
############################################################
# Why is the firewall not cooperating??
# This should probably work, but it is not currently
#echo "hadoop_exogeni_postboot: attempting to fix eth0 trusted zone"
#nmcli connection modify eth0 connection.zone internal

# Start Hadoop
############################################################
echo "hadoop_exogeni_postboot: starting Hadoop"

if [[ $self.Name() == NameNode ]]
then
  sudo -E -u hadoop $HADOOP_PREFIX/bin/hdfs namenode -format
  sudo -E -u hadoop $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start namenode
elif [[ $self.Name() == ResourceManager ]]
then
  # make sure the NameNode has had time to send the SSH private key
  until [ -f /home/hadoop/.ssh/id_rsa ]
  do
    sleep 2
  done
  sudo -E -u hadoop $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start resourcemanager
elif [[ $self.Name() == Workers* ]]
then
  # make sure the NameNode has had time to send the SSH private key
  until [ -f /home/hadoop/.ssh/id_rsa ]
  do
    sleep 2
  done
  sudo -E -u hadoop $HADOOP_PREFIX/sbin/hadoop-daemon.sh --config $HADOOP_CONF_DIR --script hdfs start datanode
  sudo -E -u hadoop $HADOOP_YARN_HOME/sbin/yarn-daemon.sh --config $HADOOP_CONF_DIR start nodemanager
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

ACCUMULO_VERSION=1.8.1

# Complete SSH setup for Accumulo Master
############################################################
until ssh-keyscan accumulomaster >> /home/hadoop/.ssh/known_hosts; do sleep 2; done
if [[ $self.Name() == AccumuloMaster ]]
then
  ssh-keyscan `neuca-get-public-ip` >> /home/hadoop/.ssh/known_hosts
  ssh-keyscan 0.0.0.0 >> /home/hadoop/.ssh/known_hosts
fi

# see if the NameNode can copy private key to other nodes
if [[ $self.Name() == NameNode ]]
then
  until sudo -u hadoop scp -o BatchMode=yes /home/hadoop/.ssh/id_rsa accumulomaster:/home/hadoop/.ssh/id_rsa; do sleep 2; done
fi

# Install Accumulo
############################################################
mkdir -p /opt/accumulo-${ACCUMULO_VERSION}
curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/accumulo/${ACCUMULO_VERSION}/accumulo-${ACCUMULO_VERSION}-bin.tar.gz > /opt/accumulo-${ACCUMULO_VERSION}.tgz
tar -C /opt/accumulo-${ACCUMULO_VERSION} --extract --file /opt/accumulo-${ACCUMULO_VERSION}.tgz --strip-components=1
rm -f /opt/accumulo-${ACCUMULO_VERSION}.tgz*

export ACCUMULO_HOME=/opt/accumulo-${ACCUMULO_VERSION}

cat > /etc/profile.d/accumulo.sh << EOF
export ACCUMULO_HOME=/opt/accumulo-$ACCUMULO_VERSION
#export PATH=\$ACCUMULO_HOME/bin:\$PATH
EOF

# make sure the hadoop user owns /opt/accumulo
chown -R hadoop:hadoop ${ACCUMULO_HOME}

# Configure Accumulo
# This assumes default accumulo password of 'secret'
############################################################

# accumulo bootstrap_config.sh tries to create a temp file in CWD.
# 512MB bug https://issues.apache.org/jira/browse/ACCUMULO-4585
cd ${ACCUMULO_HOME}
sudo -E -u hadoop ${ACCUMULO_HOME}/bin/bootstrap_config.sh --size 1GB --jvm --version 2

# tell accumulo where to run each service
sed -i "/localhost/ s/.*/$AccumuloMaster.Name()/" ${ACCUMULO_HOME}/conf/masters
sed -i "/localhost/ s/.*/$AccumuloMaster.Name()/" ${ACCUMULO_HOME}/conf/monitor
sed -i "/localhost/ s/.*/$AccumuloMaster.Name()/" ${ACCUMULO_HOME}/conf/gc
sed -i "/localhost/ s/.*/$AccumuloMaster.Name()/" ${ACCUMULO_HOME}/conf/tracers # not sure where these should be run ?

cat > ${ACCUMULO_HOME}/conf/slaves << EOF
#set ( $sizeWorkerGroup = $Workers.size() - 1 )
#foreach ( $j in [0..$sizeWorkerGroup] )
 `echo $Workers.get($j).Name() | sed 's/\//-/g'`
#end
EOF

# Need monitor to bind to public port
sed -i "/ACCUMULO_MONITOR_BIND_ALL/ s/^# //" ${ACCUMULO_HOME}/conf/accumulo-env.sh

# setup zookeeper hosts
sed -i "/localhost:2181/ s/localhost:2181/zoo1:2181,zoo2:2181,zoo3:2181/" ${ACCUMULO_HOME}/conf/accumulo-site.xml

# disable SASL (?) Kerberos ??
# this is disabled correctly by bootstrap_config.sh
#sed -i '/instance.rpc.sasl.enabled/!b;n;s/true/false/' ${ACCUMULO_HOME}/conf/accumulo-site.xml

# if you change the accumulo password in the 'init' stage below, you will need to change it here too
#sed -i '/trace.token.property.password/!b;n;s/secret/NEW_PASSWORD/' ${ACCUMULO_HOME}/conf/accumulo-site.xml

# Start Accumulo
# Start each host separately, as they may be at different 
# stages of configuration
############################################################
if [[ $self.Name() == AccumuloMaster ]]
then
  # wait until we have the SSH private key
  until [ -f /home/hadoop/.ssh/id_rsa ]
  do
    sleep 2
  done

  # init and run accumulo
  # This assumes default accumulo password of 'secret'
  sudo -E -u hadoop ${ACCUMULO_HOME}/bin/accumulo init --instance-name exogeni --password secret --user root
  sudo -E -u hadoop ${ACCUMULO_HOME}/bin/start-here.sh

elif [[ $self.Name() == Workers* ]]
then
  # make sure the NameNode has had time to send the SSH private key
  until [ -f /home/hadoop/.ssh/id_rsa ]
  do
    sleep 2
  done

  # need to wait for 'init' of accumulo to finish
  until sudo -E -u hadoop ${HADOOP_PREFIX}/bin/hdfs dfs -ls /accumulo/instance_id > /dev/null 2>&1
  do
    sleep 1
  done

  sudo -E -u hadoop ${ACCUMULO_HOME}/bin/start-here.sh
fi


