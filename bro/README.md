## Install OpenFlow Controller

### ExoGENI Slice

Add the script below to the "PostBoot Script" section of the request.
This script installs Bro on CentOS 7.

```
#!/bin/bash
yum install -y git
RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="bro"
RECIPE_FILE="bro-install.sh"


git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/${RECIPE_FILE}" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

chmod +x ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
```

Bro is installed to /opt/bro directory. After the installation is completed
modify configuration file `/opt/bro/etc/node.cfg` 

Run Bro and check status:
```
/opt/bro/bin/broctl deploy
/opt/bro/bin/broctl status
```

### Chameleon

Heat template : <PLACEHOLDER for URL>

