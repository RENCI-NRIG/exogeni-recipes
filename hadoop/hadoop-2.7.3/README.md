This recipe is similar to the [hadoop tutorial](../hadoop-tutorial/) recipe, but starts with a base Centos 7.3 image, and installs and runs Hadoop on top of that.

## Known Issues
* `firewalld` is currently preventing the Hadoop cluster from communicating, presumably because `eth0` is not being correctly placed in the `trusted` zone.

## References
* http://hadoop.apache.org/docs/r2.8.0/hadoop-project-dist/hadoop-common/ClusterSetup.html
