Least privilege proxy service for [Nutanix DVP (Docker Volume Plug-in)](https://hub.docker.com/plugins/nutanix-dvp-docker-volume-plug-in)

# TODO
* Docs and pictures
* htaccess using docker secret

# Installation
## Docker swarm deployment
You need one deployment per cluster.
NOTE! Port number must be 9440 so you must run these on different servers.
```bash
docker stack deploy -c docker-compose.yml cluster1
```

## Docker plugin installation
You can follow official guidance from most of the part but notice that with this solution you should use parameters on this way:
* PRISM_IP: IP or FQDN of server which run ollijanatuinen/ntnx-volume-plugin-proxy container.
* DATASERVICES_IP: Data service IP configured in the Nutanix cluster
* PRISM_USERNAME: Username to ntnx-volume-plugin-proxy, must match to .htaccess file and to storage container id.
* PRISM_PASSWORD: Password to ntnx-volume-plugin-proxy, must match to .htaccess file.
* DEFAULT_CONTAINER: Name of storage container, must be same than which id you use as username.

Example:
```bash
docker plugin install ntnx/nutanix_volume_plugin:1.4ubuntu \
PRISM_IP="ntnx-volume-plugin-proxy.domain.local" \
DATASERVICES_IP="ntnx-data.domain.local" \
PRISM_USERNAME="29513873" \
PRISM_PASSWORD="docker" \
DEFAULT_CONTAINER="Docker" \
--alias nutanix
```
