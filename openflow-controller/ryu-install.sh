#!/bin/bash
{
set -e -u -o pipefail

RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="openflow-controller/docker"
DOCKER_IMAGE="ryu-docker"
DOCKER_CONTAINER_NAME="ryu-controller"
# Change OFP_TCP_LISTEN_PORT with desired value
OFP_TCP_LISTEN_PORT="6653"
# Change OFP_WSGI_LISTEN_PORT with desired value
OFP_WSGI_LISTEN_PORT="8080"
RYU_APP="/opt/ryu_app/simple_switch_13_custom_chameleon.py"
# Used for port mirroring via openflow
MIRROR_PORT="10000"

sudo dnf install -y yum-utils device-mapper-persistent-data lvm2 vim

echo "Installing Docker ..."
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce
sudo systemctl start docker

echo "Configuring Ryu controller ..."
git clone  --no-checkout $RECIPE_REPO $RECIPE_DIR
cd $RECIPE_DIR && git config core.sparsecheckout true
echo "$RECIPE_APP/*" >> .git/info/sparse-checkout
git read-tree -m -u HEAD
pushd ${RECIPE_DIR}/${RECIPE_APP}
sed -r -i 's/^(RYU_APP=.*)/#\1/g' ryu_start.sh
sed -r -i 's/^(OFP_TCP_LISTEN_PORT=.*)/#\1/g' ryu_start.sh

echo "Building Ryu controller image ..."
docker build -t ${DOCKER_IMAGE} .

echo "Starting Ryu controller ..."
docker run --rm -dit \
  -p $OFP_TCP_LISTEN_PORT:$OFP_TCP_LISTEN_PORT \
  -p $OFP_WSGI_LISTEN_PORT:$OFP_WSGI_LISTEN_PORT \
  -v opt_ryu_chameleon:/opt/ryu_chameleon \
  -v opt_ryu:/opt/ryu \
  -v var_log_ryu:/var/log/ryu \
  -v var_run_ryu:/var/run/ryu \
  -e RYU_APP=$RYU_APP -e OFP_TCP_LISTEN_PORT=$OFP_TCP_LISTEN_PORT \
  --name=$DOCKER_CONTAINER_NAME \
  $DOCKER_IMAGE

echo "Opening OF controller port ..."
ufw allow $OFP_TCP_LISTEN_PORT

echo "Done."
} > /tmp/boot.log 2>&1
