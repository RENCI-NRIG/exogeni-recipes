## exogeni-recipes
ExoGENI example scripts

In most recipes, the postboot script is presented as a separate file from the RDF request file.  This is not strictly necessary, as the RDF request file contains the postboot script for each node.  The postboot script is presented separately for ease of editing.  Any changes made to the postboot script will need to be manually copied into the RDF request file.  (Usually this will be done using Flukes, by editing the Node properties, and pasting in the postboot script.)

### Debugging postboot behavior
It is not always obvious if the postboot script has completed.  You can run a couple of commands to see what the postboot script is currently doing:

```bash
# grep the process log to find the pid of the bootscript, in this case 1401
[root@AccumuloMaster ~]# ps -ef | grep neuca
root      1177     1  0 13:33 ?        00:00:00 /usr/bin/python /usr/bin/neucad start
root      1401  1177  0 13:33 ?        00:00:00 /bin/bash /var/lib/neuca/bootscript
root      1651  1559  0 13:34 pts/0    00:00:00 grep neuca

# create a while loop to find children processes of the bootscript (pid 1401)
[root@AccumuloMaster ~]# while true; do date; ps -ef | grep 1401 | tail -2 | head -1; sleep 5; done
Wed Sep 20 13:34:46 EDT 2017
root      1645  1401  5 13:34 ?        00:00:00 curl --location --insecure --show-error https://dist.apache.org/repos/dist/release/hadoop
```

## References
- [Velocity Templates](https://github.com/RENCI-NRIG/orca5/wiki/velocity-templates)

