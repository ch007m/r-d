## Install cf-for-k8s (aka VMWare Tanzu Application Service) 

Additional information about how to install/configure is available with the project [instructions](https://github.com/cloudfoundry/cf-for-k8s/blob/master/docs/deploy.md)

- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```
- Create a k8s cluster using `kind`. See how to install `kind` tool - [here](KIND.md)
```bash
kind create cluster --name cf-k8s --config=./deploy/kind/cluster.yml --image kindest/node:v1.16.4
```
- Install the needed [tools](TOOLS.md) like also the tools only used by cf-4-k8s project and able to populate the kubernetes resources using `ytt`, `kapp`
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

- Generate the `installation` values such as the `domain name`, `app domain`, `certificates`, `registry` ... using the bosh client 
```bash
IP=<VM_ETH0_IP_ADDRESS>
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
```
- Append, end of the `/tmp/cf-values.yml` file, your container registry credential.
```bash
echo -e '\napp_registry:\n  hostname: https://index.docker.io/v1/\n  repository: <repo>\n  username: <username>\n  password: <password>' >> /tmp/cf-values.yml
```
- Use the `Spring Boot` builder which don t include the `Autoreconfiguration` pack as it will fail with applications using the Pivotal `CfEnv` project
```bash
echo -e '\nimages:\n  cf_autodetect_builder: cmoulliard/paketo-spring-boot-builder@sha256:f0fe222b06fd54e580a1366646f31e7b5b59047c3112b8416c06994e4109cd30' >> /tmp/cf-values.yml
```
- Deploy the Kubernetes metrics server needed by the `metrics-proxy` pod
```bash
kc apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
```

- Next, deploy `cf-4-k8s` using the `kapp` tool, and some additional files
```bash
./bin/install-cf.sh /tmp/cf-values.yml
```
- **REMARK**: When using `kind`, please execute the following command to use the `nodeport-for-ingress` as kind don't provide a loadbalancer that `istio ingressgateway` can use and fix resource allocations.
```bash
curl https://raw.githubusercontent.com/cloudfoundry/cf-for-k8s/ed4c9ea79025bb4767543cb013d3c854d1cd2b72/config-optional/use-nodeport-for-ingress.yml > config-optional/use-nodeport-for-ingress.yml
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config-optional/remove-resource-requirements.yml -f config-optional/use-nodeport-for-ingress.yml)
```
- **REMARK**: When the `ingress nginx controller` has been deployed on kubernetes created using by example `kubeadm, kubelet`, then scale it down the `ingress nginx`, otherwise cf for k8s will fail to be deployed !!
```bash
$ kc scale --replicas=0 deployment.apps/nginx-ingress-controller -n kube-system
```

### Stratos console 

See [instructions](OTHERS.md)

