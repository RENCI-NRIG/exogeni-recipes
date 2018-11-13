## Install Security Onion

Security Onion is installed on Ubuntu 16.

### ExoGENI Slice

Add the script below to the "PostBoot Script" section of the request.

```
#!/bin/bash
{
RECIPE_REPO="https://github.com/RENCI-NRIG/exogeni-recipes.git"
RECIPE_DIR="/opt/exogeni-recipes"
RECIPE_APP="security-onion"
RECIPE_FILE="so-install.sh"
            
SO_ANSWER_FILE="sosetup_answerfile_for_exogeni_xl_node"

#WHITELIST=$domain
WHITELIST="152.54.0.0/16"
MAIL_RECIPIENT="mcevik@renci.org"

git clone  --no-checkout ${RECIPE_REPO} ${RECIPE_DIR}
cd ${RECIPE_DIR} && git config core.sparsecheckout true
echo "${RECIPE_APP}/" >> .git/info/sparse-checkout
git read-tree -m -u HEAD

chmod +x ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}

while pgrep apt-get | lsof /var/lib/dpkg/lock; do 
     echo "--- Wait on locking dpkg dir"; 
     sleep 1; 
done && ${RECIPE_DIR}/${RECIPE_APP}/${RECIPE_FILE}

if [ -x /usr/sbin/sosetup ]; then
    echo "--- Apply Workaround for delays on Pulledpork rule-updates"
    sed -i -r "s/(^.*&& INTERNET=)\"UP\"/\1\"DOWN\"/g" /usr/sbin/sosetup
                
    echo "--- Start configuring the node with the answerfile"
    /usr/sbin/sosetup -f ${RECIPE_DIR}/${RECIPE_APP}/${SO_ANSWER_FILE} -y
fi

echo "--- Add firewall rule for ${WHITELIST}"
ufw allow proto tcp from ${WHITELIST} to any port 443,22,7734

echo "Security Onion configuration is completed" | mail -s "Security Onion Ready" -t ${MAIL_RECIPIENT}

} > /tmp/install_security_onion.log 2>&1

```

### Chameleon

Heat template : <PLACEHOLDER for URL>

