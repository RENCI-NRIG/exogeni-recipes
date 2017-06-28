This example is a setup for a simple `etcd` cluster.

The [etcd_exogeni_request.rdf](./etcd_exogeni_request.rdf) file will:
1. Boot three virtual machines at a single site, with a broadcast link
1. Use the latest CentOS 7.3 images
1. Install Docker
1. Run the latest etcd docker container

## Multi-site
To experiment with a distributed `etcd` cluster, simply change the site/`Domain` before submitting the request. You will want to review the etcd documentation on [Tuning](https://coreos.com/etcd/docs/latest/tuning.html).

## References
* https://coreos.com/etcd/docs/latest/op-guide/clustering.html
* https://github.com/coreos/etcd/blob/master/Documentation/op-guide/container.md#docker
