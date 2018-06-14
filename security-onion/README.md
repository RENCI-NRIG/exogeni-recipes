## Install Security Onion

Security Onion is installed on Ubuntu 16.

### ExoGENI Slice

Add the script below to the "PostBoot Script" section of the request.

```
#!/bin/bash
RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="security-onion"
RECIPE_FILE="so-install.sh"


git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/${RECIPE_FILE}" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

chmod +x ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}

while `lsof /var/lib/dpkg/lock` || `lsof /var/cache/debconf/templates.dat`; do 
   sleep 1 
done && ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}
```

### Chameleon

Heat template : <PLACEHOLDER for URL>

