#!/bin/bash

echo $infra0.IP("VLAN0") infra0 >> /etc/hosts
echo $infra1.IP("VLAN0") infra1 >> /etc/hosts
echo $infra2.IP("VLAN0") infra2 >> /etc/hosts

echo `echo $self.Name() | sed 's/\//-/g'` > /etc/hostname
/bin/hostname -F /etc/hostname

# Install docker
yum makecache fast
yum -y update
yum install -y yum-utils git
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
yum makecache fast
yum install -y docker-ce
systemctl start docker
systemctl enable docker


# https://github.com/coreos/etcd/blob/master/Documentation/op-guide/container.md#docker
ETCD_VERSION=latest
TOKEN=exogeni-etc-cluster
CLUSTER_STATE=new
NAME_1=infra0
NAME_2=infra1
NAME_3=infra2
HOST_1=$infra0.IP("VLAN0")
HOST_2=$infra1.IP("VLAN0")
HOST_3=$infra2.IP("VLAN0")
CLUSTER=${NAME_1}=http://${HOST_1}:2380,${NAME_2}=http://${HOST_2}:2380,${NAME_3}=http://${HOST_3}:2380
DATA_DIR=/var/lib/etcd

if [[ $self.Name() == infra0 ]]
then
  THIS_NAME=${NAME_1}
  THIS_IP=${HOST_1}
elif [[ $self.Name() == infra1 ]]
then
  THIS_NAME=${NAME_2}
  THIS_IP=${HOST_2}
elif [[ $self.Name() == infra2 ]]
then
  THIS_NAME=${NAME_3}
  THIS_IP=${HOST_3}
fi

docker run \
  -p 2379:2379 \
  -p 2380:2380 \
  --volume=${DATA_DIR}:/etcd-data \
  --name etcd quay.io/coreos/etcd:${ETCD_VERSION} \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name ${THIS_NAME} \
  --initial-advertise-peer-urls http://${THIS_IP}:2380 --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${THIS_IP}:2379 --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster ${CLUSTER} \
  --initial-cluster-state ${CLUSTER_STATE} --initial-cluster-token ${TOKEN}

# testing
# docker exec etcd-v3.2.1 /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcd -version"
# docker exec etcd-v3.2.1 /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcdctl version"
# docker exec etcd-v3.2.1 /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcdctl endpoint health"
# docker exec etcd-v3.2.1 /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcdctl put foo bar"
# docker exec etcd-v3.2.1 /bin/sh -c "export ETCDCTL_API=3 && /usr/local/bin/etcdctl get --consistency=s foo"
