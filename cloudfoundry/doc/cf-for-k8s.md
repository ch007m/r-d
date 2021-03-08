## Install cf-for-k8s (aka VMWare Tanzu Application Service) 

Additional information about how to install/configure is available with the project [instructions](https://github.com/cloudfoundry/cf-for-k8s/blob/master/docs/deploy.md)

- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```
- Generate the `install` values such as domain name, app domain, certificates, ... using the bosh client
```bash
IP=95.217.159.244
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
```
- Pass your credentials to access the container registry (quay.io, docker, or local)
```bash
cat << EOF >> /tmp/cf-values.yml
app_registry:
  hostname: https://quay.io/
  repository_prefix: quay.io/cmoulliard
  username: "cmoulliard"
  password: "xxxxx"

add_metrics_server_components: true
enable_automount_service_account_token: true
metrics_server_prefer_internal_kubelet_address: true
remove_resource_requirements: true
use_first_party_jwt_tokens: true
load_balancer:
  enable: false
EOF
```
**REMARK**: If a local registry exists, then pass the following `hostname` and `repository_prefix`
```yaml
app_registry:
  hostname: http://kind-registry:5000
  repository_prefix: kind-registry:5000
  username: "cmoulliard"
  password: "xxxxx"
...
```
- Next, deploy `cf-for-k8s` using the `kapp` tool
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml)
```
**REMARKS**:

- When the `ingress nginx controller` has been deployed on kubernetes created using by example `kubeadm, kubelet`, then scale it down the `ingress nginx`, otherwise cf for k8s will fail to be deployed !!
```bash
$ kc scale --replicas=0 deployment.apps/nginx-ingress-controller -n kube-system
```
- If you plan to use another `builder` to build the image using `builddpack`, execute then this command (TO BE VERIFIED).
  
  We created this new `Spring Boot` builder which don t include the `Autoreconfiguration` pack as it will fail
  with applications using the Pivotal `CfEnv` project as this is the case with `Spring Music` app
```bash
cat << EOF >> /tmp/cf-values.yml
images:
  cf_autodetect_builder: cmoulliard/paketo-spring-boot-builder@sha256:f0fe222b06fd54e580a1366646f31e7b5b59047c3112b8416c06994e4109cd30
EOF
```
