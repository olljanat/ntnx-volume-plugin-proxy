# Background
Nutanix Prism Central contains concepts called for 
[Projects](https://portal.nutanix.com/page/documents/details?targetId=Prism-Central-Guide-Prism-v5_17:mul-explore-projects-view-pc-r.html)
and [Roles](https://portal.nutanix.com/page/documents/details?targetId=Prism-Central-Guide-Prism-v5_17:mul-explore-roles-view-pc-r.html) 
which are excellent way to delegate control including API access for different user groups without compromising core infrastructure security.

Unfortunately volume groups provided by [Nutanix Volumes](https://www.nutanix.com/products/volumes) can be only managed from Prism Element (or its API) 
because those are not (at least yet) available through from Prism Central API (API version 3).

Because of that limitation all Docker nodes which are using [Nutanix DVP (Docker Volume Plug-in)](https://hub.docker.com/plugins/nutanix-dvp-docker-volume-plug-in) must:
* have access to cluster VIP port TCP/9440 (API versions 0.8, 1 and 2)
* known service account username and password which have "Cluster Admin" (=> **unlimited** access to cluster :grimacing:) role

## Will Nutanix fix this issue?
We know that:
* Nutanix introduced [Docker volume plugin on their forum](https://next.nutanix.com/karbon-kubernetes-service-30/docker-nutanix-container-volume-plug-in-18726) on March 2017
* [Docker Hub](https://hub.docker.com/r/ntnx/nutanix_volume_plugin/tags) show that latest version was created on 25th of September 2018
* Nutanix introduced [Karbon on their forum](https://next.nutanix.com/karbon-kubernetes-service-30/kubernetes-cluster-deployment-with-nutanix-karbon-32001) on March 2019
* Nutanix is actively developing [Karbon](https://www.nutanix.com/products/karbon) and they released [CSI–Based Driver](https://next.nutanix.com/blog-40/nutanix-releases-new-kubernetes-csi-based-driver-30941) for it on 26 of September 2018 (one day after latest volume plugin) but it still needs Docker volume plugin so so all requirements remains.
* Nutanix is actively working on to introduce more features to Prism Central side and integrations with public clouds.

**Summary:** It doesn't look like that we can expect this limitation to be fixed any time soon so I needed to handle this problem on other way and that was driver to introduce this solution.

# How this solution handles the issue?
This solution uses [NGINX](https://www.nginx.com) as containerized reverse proxy for Prism Element APIs and implement these features:
* Delegated user authentication
* Filter storage containers based on user (one user <=> one storage container)
* Filter volume groups based on storage container
* Mock volume group delete API (safety feature, `docker volume rm ...` command will only remove volume from Docker internal cache but volume groups will stay on Nutanix cluster) 
* Hide all other Prism Element APIs which are not needed

It is worthwhile to mention that it is possible to create [service specific interface(s)](https://portal.nutanix.com/page/documents/details?targetId=Nutanix-Security-Guide-v5_17:wc-service-specific-traffic-isolate-t.html) for Nutanix Volumes which will add *ntnx0* (or ntnx1 or ntnx2) interface(s) (currently three interfaces looks to be maximum) to each CVM and create iptables rules which will allow only iSCSI to use it.

Illustration of network connections in full deployment:
![Alt text](https://raw.githubusercontent.com/olljanat/ntnx-volume-plugin-proxy/master/pictures/ntnx-volume-plugin-proxy_networking.png "ntnx-volume-plugin-proxy networking")

# Installation
## Preparations
* Create service account with Cluster Admin (it is used by this proxy to authenticate against of Nutanix cluster)
* Create own storage container for each Docker environment (swarm/kubernetes cluster/any set of Docker nodes which are allowed to see same disks)
* Use Prism Element [REST API Explorer](https://portal.nutanix.com/page/documents/details?targetId=Prism-Element-Data-Protection-Guide-v5_17:man-rest-api-c.html) to get storage containers metadata (API Version 1, GET /containers)
* Copy metadata to your favorite text editor and search container id (id field value after `::` marks)
![Alt text](https://raw.githubusercontent.com/olljanat/ntnx-volume-plugin-proxy/master/pictures/storage-container-metadata.png "Storage Container Metadata")
* Create [.htaccess](https://en.wikipedia.org/wiki/.htaccess) file which contains one user for each storage container and where container id is used as username:
```bash
echo -n "<container id>:" >> /.htpasswd
echo "<password you choose>" | openssl passwd -apr1 -stdin >> /.htpasswd
```

## Docker swarm deployment
You need one deployment per Nutanix cluster (Port number must be 9440 so you must run these on different servers or use load balancer as from of Docker nodes).

**NOTE!!!** Because service account with Cluster Admin permissions will be visible on Docker node where you deploy this solution you need restrict access to that one for persons who anyway have cluster admin permissions to Nutanix environment.

Update environment variables to docker-compose.yml file:
* **PRISM_IP** => Nutanix cluster VIP or FQDN
* **AuthorizationBase64** => `username:password` combination of service account you created earlier.
```bash
export HTPASSWD_TIMESTAMP=`date --utc +%Y%m%d%H%M%S`
docker stack deploy -c docker-compose.yml cluster1-ntnx-volume-plugin
```

## Docker plugin installation
You can follow official guidance from most of the part but notice that with this solution you should use parameters on this way:
* **PRISM_IP** => IP or FQDN of server which run [ollijanatuinen/ntnx-volume-plugin-proxy](https://hub.docker.com/r/ollijanatuinen/ntnx-volume-plugin-proxy) container.
* **DATASERVICES_IP** => Data service IP configured in the Nutanix cluster
* **PRISM_USERNAME** => Username to ntnx-volume-plugin-proxy, must match to .htaccess file and to storage container id.
* **PRISM_PASSWORD** => Password to ntnx-volume-plugin-proxy, must match to .htaccess file.
* **DEFAULT_CONTAINER** => Name of storage container, must be same than which id you use as username.

Example:
```bash
docker plugin install ntnx/nutanix_volume_plugin:1.4ubuntu \
PRISM_IP="ntnx-volume-plugin-proxy.domain.local" \
DATASERVICES_IP="ntnx-data.domain.local" \
PRISM_USERNAME="<container id>" \
PRISM_PASSWORD="<password you choose>" \
DEFAULT_CONTAINER="docker_dev" \
--alias nutanix
```

## Troubleshooting
### Plugin enable failure
Most common error message you will see when you try install/enable is:
```
Error response from daemon: dial unix /run/docker/plugins/<id>/nutanix.sock: connect: no such file or directory
```
more details about that one you can find from ntnx-volume-plugin-proxy container log.

Most common problems are:
* Network connectivity issues
* Incorrect username/password
* DEFAULT_CONTAINER variable value does not match to username

### Volume mount error:
If volume mount fails to error like:
```
docker: Error response from daemon: error while mounting volume '/var/lib/docker/plugins/<id>/rootfs':
iSCSI initiator error: Target volume: <volume name> not found. Please ensure that the dataservices IP: ntnx-data.domain.local:3260 is correct and reachable on port 3260.
```
Then check that iscsid is able to reach volume using command:
```
iscsiadm --mode discovery -t sendtargets --portal ntnx-data.domain.local
```

You can also find plugin error log from `/var/lib/docker/plugins/<id>/rootfs/nvp.log`
