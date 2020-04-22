## Install cf-for-k8s (aka VMWare Tanzu)

### Deploy the tools and configure cf-4-k8s

Additional information about how to install/configure is available with the project [instructions](https://github.com/cloudfoundry/cf-for-k8s/blob/master/docs/deploy.md)

- Install common [tools](TOOLS.md)
- Next, install the tools only used by cf-4-k8s project and able to populate the kubernetes resources using ytt, kapp

```bash
brew tap k14s/tap
brew install ytt kbld kapp imgpkg kwt vendir
```

- Deploy the `bosh` client as it will be used during the next step to generate k8s resources
```bash
wget https://github.com/cloudfoundry/bosh-cli/releases/download/v6.2.1/bosh-cli-6.2.1-linux-amd64
mv bosh-cli-6.2.1-linux-amd64 bosh
chmod +x ./bosh
sudo mv ./bosh /usr/local/bin/bosh
```

- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```

- Generate the `install` values such as domain name, app domain, certificates, ... using the bosh client 
```bash
IP=<VM_ETH0_IP_ADDRESS>
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
```
- Edit the `/tmp/cf-values.yml` file to add your registry credentials
```yaml
...
log_cache_client:
  id: log-cache
  secret: <secret>>

app_registry:
  hostname: https://index.docker.io/v1/
  repository: <repo>
  username: <username>
  password: <password>
```

- Deploy the Kubernetes metrics server needed by the cf-for-k8s metrics-proxy pod
```bash
kc apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
```

- Next, deploy `cf-4-k8s` using the `kapp` tool and some additional files
```bash
./bin/install-cf.sh /tmp/cf-values.yml
```
- **REMARK**: When using `kind`, please execute the following command to remove istio ingress service and fix healthcheck, cpu/memory
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config-optional/remove-resource-requirements.yml -f config-optional/remove-ingressgateway-service.yml)
```
- Scale down the `ingress nginx` application deployed within the kube-system namespace, otherwise cf for k8s will failt to be deployed
```bash
$ kc scale --replicas=0 deployment.apps/nginx-ingress-controller -n kube-system
``` 
**REMARK**: This step is only needed when ingress has been deployed on a kubernetes cluster

### Additional features (optional)

### Kind cluster

- See how to install `kind` tool - [here](KIND.md)
- Create a kind cluster
```bash
sudo kind create cluster --name cf-k8s --config=./deploy/kind/cluster.yml
sudo docker exec -it "kubecf-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'
```
- Got the k8s config
```bash
mkdir ~/.kube
sudo kind get kubeconfig --name cf-k8s  > ~/.kube/config
```

### Stratos console 

See [instructions](OTHERS.md)

