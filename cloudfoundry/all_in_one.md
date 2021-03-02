# Create VM and k8s cluster using Ansible

## Table of content

   * [Create K8s cluster using Ansible](#create-k8s-cluster-using-ansible)
   * [Install tools](#install-tools)
   * [Install CloudFoundry](#install-cloudfoundry)
      * [Deploy cf-4-k8s](#deploy-cf-4-k8s)
      * [Deploy KubeCF](#deploy-kubecf)
      * [Install cf, Stratos](#install-cf-stratos)
      * [Service catalog](#service-catalog)
      * [Optional](#optional)
         * [Kubernetes dashboard](#kubernetes-dashboard)
         * [Install kind](#install-kind)

## Create K8s cluster using Ansible

### Prerequisite
- `hcloud` client is needed
  `brew install hcloud`
- Configure the `snowdrop` context
  ```bash
  hcloud context create snowdrop
  $token: <HETZNER_API_TOKEN>
  ```

### How to create the VM
- Create a VM on Hetzner & deploy a k8s cluster
```bash
pushd ~/code/snowdrop/infra-jobs-productization/k8s-infra
export k8s_version=118
export VM_NAME=h01-${k8s_version}
export PASSWORD_STORE_DIR=~/.password-store-snowdrop
ansible-playbook hetzner/ansible/hetzner-delete-server.yml -e vm_name=${VM_NAME} -e hetzner_context_name=snowdrop
ansible-playbook ansible/playbook/passstore_controller_inventory_remove.yml -e vm_name=${VM_NAME} -e pass_provider=hetzner
ansible-playbook ansible/playbook/passstore_controller_inventory.yml -e vm_name=${VM_NAME} -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version} -e operation=create
ansible-playbook hetzner/ansible/hetzner-create-server.yml -e vm_name=${VM_NAME} -e salt_text=$(gpg --gen-random --armor 1 20) -e hetzner_context_name=snowdrop -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version}
ansible-playbook ansible/playbook/sec_host.yml -e vm_name=${VM_NAME} -e provider=hetzner
ansible-playbook kubernetes/ansible/k8s.yml --limit ${VM_NAME}
popd

ok: [h01-118] => {
    "msg": [
        "You can also view the kubernetes dashboard at",
        "https://k8s-console.65.21.55.223.nip.io/",
        "",
        "Using the Boot Token: ",
        "v6vzdy.wogsaankymdxsfrb"
    ]
}
```

- SSH to the VM
```bash
ssh-hetznerc ${VM_NAME}
```

- Add missing PV
```bash
mkdir /tmp/pv00{6,7,8,9,10,11}
sudo chown -R snowdrop:snowdrop /tmp
sudo chown -R 777 /tmp

create_pv() {
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0$1
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: $2Gi
  hostPath:
    path: /tmp/pv0$1
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem
EOF
}

create_pv 06 20
create_pv 07 20
create_pv 08 20
create_pv 09 100
create_pv 10 8
create_pv 11 8
```

## Install tools

- Install wget, helm, jq, brew, maven, k9s and upgrade curl
```bash
sudo yum install -y wget epel-release jq maven

sudo rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-2-1.rhel7.noarch.rpm
sudo yum -y --enablerepo=city-fan.org install libcurl libcurl-devel

helm_version=3.5.2
k9s_version=0.24.2

mkdir temp && cd temp
wget https://get.helm.sh/helm-v$helm_version-linux-amd64.tar.gz
tar -vxf helm-v$helm_version-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin

wget https://github.com/derailed/k9s/releases/download/v$k9s_version/k9s_Linux_x86_64.tar.gz
tar -vxf k9s_Linux_x86_64.tar.gz
sudo mv k9s /usr/local/bin

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
yum groupinstall 'Development Tools' -y
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> /home/snowdrop/.bash_profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

alias sudo='sudo env PATH=$PATH'
```
- Deploy docker if not yet there
```bash
sudo yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io 
sudo systemctl start docker   
```
## Install CloudFoundry

### Deploy cf-4-k8s

- Install cfssl, gcc
```bash
brew install gcc cfssl 
```
- Install vmware tools such as : ytt, kapp and bosh tools
```bash
brew tap vmware-tanzu/carvel
brew install ytt kbld kapp imgpkg kwt vendir

brew install cloudfoundry/tap/bosh-cli
```
- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```
- Generate the `install` values such as domain name, app domain, certificates, ... using the bosh client 
```bash
IP=95.217.161.67
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
```
- Pass your credentials to access the docker registry
```bash
cat << EOF >> /tmp/cf-values.yml
app_registry:
  hostname: https://index.docker.io/v1/
  repository_prefix: "cmoulliard"
  username: "cmoulliard"
  password: "aGxecQquG7"

add_metrics_server_components: true
enable_automount_service_account_token: true
load_balancer:
  enable: false
metrics_server_prefer_internal_kubelet_address: true
remove_resource_requirements: true
use_first_party_jwt_tokens: true
EOF
```  
- Next, deploy `cf-4-k8s` using the `kapp` tool
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml)
```
- **REMARK**: When using `kind`, please execute the following command to remove istio ingress service and fix healthcheck, cpu/memory
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config-optional/remove-resource-requirements.yml -f config-optional/remove-ingressgateway-service.yml)
```
- Scale down the `ingress nginx` application deployed within the kube-system namespace, otherwise cf for k8s will fail to be deployed
```bash
$ kc scale --replicas=0 deployment.apps/nginx-ingress-controller -n kube-system
``` 
**REMARK**: This step is only needed when ingress has been deployed on a kubernetes cluster

### Deploy KubeCF

- Install Quarks CRD + Operator
```bash
kc create ns cf-operator
helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
kc -n cf-operator get pods
```

- Deploy kubecf
```bash
NODE_NAME=h01-116
node_ip=$(kubectl get node ${NODE_NAME} \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }') 
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
services:
  router:
    externalIPs:
    - ${node_ip}
features:
  eirini:
    enabled: true
kube:
  service_cluster_ip_range: 0.0.0.0/0
  pod_cluster_ip_range: 0.0.0.0/0
_EOF_

wget https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.1/kubecf-v1.0.1.tgz
helm install kubecf --namespace kubecf --values values.yaml kubecf-v1.0.1.tgz
```
- To uninstall it
```bash
helm uninstall kubecf -n kubecf
```

### Install cf, Stratos

```bash
export node_ip=95.217.161.67
kc create ns stratos
cat << _EOF_ > stratos.yml
console:
  service:
    externalIPs: ["${node_ip}"]
    servicePort: 8444
_EOF_

helm repo add suse https://kubernetes-charts.suse.com/
helm install stratos --namespace stratos --values ./stratos.yml suse/console
```

- Install CF Client
```bash
curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
```
- Get secret
```bash
kubectl get secret \
>         --namespace kubecf kubecf.var-cf-admin-password \
>         -o jsonpath='{.data.password}' \
>         | base64 --decode

WOg8sCzuhZBJaLs6BhWBJ0bkc4iAxRg3kanbTBXrPVUbtBRMcXAOrm6KAQiJyYY0
```

- Access the API and log on

```bash
cf api --skip-ssl-validation https://api.95.217.161.67.nip.io
acp=$(kubectl get secret \
>         --namespace kubecf kubecf.var-cf-admin-password \
>         -o jsonpath='{.data.password}' \
>         | base64 --decode)

cf auth admin "${acp}"
```
- Login using the admin credentials for key cf_admin_password in /tmp/cf-values.yml
```bash
cf auth admin <cf-values.yml.cf_admin_password>
```  

- Enable docker feature (needed when using cf-4-k8s)
```bash
cf enable-feature-flag diego_docker
```

- Create the org, space
```bash
cf create-org redhat.com
cf create-space demo -o redhat.com
cf create-user developer password
cf target -o redhat.com -s demo
```
- Deploy an app based using `pre-built` Docker image
```bash
cf push test-app-build -o cloudfoundry/diego-docker-app
```  

- Deploy a Spring example and `build` it
```bash
git clone https://github.com/cloudfoundry-samples/spring-music
cd spring-music/
./gradlew assemble
cf push spring-music
```

### Service catalog

- Create a helm config file
```bash
cat << _EOF_ > bitnami.yml
useHelm3: true
ingress:
  enabled: false
frontend:
  service:
    type: LoadBalancer
_EOF_
```  
- Install the `bitnami` service catalog
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
kubectl create ns kubeapps
helm install kubeapps -n kubeapps --values ./bitnami.yml bitnami/kubeapps 

NAME: kubeapps
LAST DEPLOYED: Wed Apr  1 13:53:07 2020
NAMESPACE: kubeapps
STATUS: deployed
REVISION: 1
NOTES:
** Please be patient while the chart is being deployed **

Tip:

  Watch the deployment status using the command: kubectl get pods -w --namespace kubeapps

Kubeapps can be accessed via port 80 on the following DNS name from within your cluster:

   kubeapps.kubeapps.svc.cluster.local

To access Kubeapps from outside your K8s cluster, follow the steps below:

1. Get the Kubeapps URL by running these commands:
   echo "Kubeapps URL: http://127.0.0.1:8080"
   export POD_NAME=$(kubectl get pods --namespace kubeapps -l "app=kubeapps" -o jsonpath="{.items[0].metadata.name}")
   kubectl port-forward --namespace kubeapps $POD_NAME 8080:8080

2. Open a browser and access Kubeapps using the obtained URL.
```
- Modify the service created to define the externalIP address
```bash
apiVersion: v1
kind: Service
metadata:
  labels:
    app: kubeapps
    chart: kubeapps-3.4.3
    heritage: Helm
    release: kubeapps
  name: kubeapps
  namespace: kubeapps
spec:
  clusterIP: 10.110.182.9
  externalIPs:
  - 95.217.161.67
  externalTrafficPolicy: Cluster
  ports:
  - name: http
    nodePort: 32648
    port: 80
    protocol: TCP
    targetPort: http
  selector:
    app: kubeapps
    release: kubeapps
  sessionAffinity: None
  type: LoadBalancer
```  
- Create a `serviceaccount` and next get the token to use it to access the dashboard
```bash
kubectl create serviceaccount kubeapps-operator -n kubeapps
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator -n kubeapps
```
-
```bash
kubectl get secret $(kubectl get serviceaccount kubeapps-operator -n kubeapps -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' -n kubeapps && echo
```

- Modify the service created to define the externalIP address `http://95.217.161.67/#/login`

### Optional 

#### Kubernetes dashboard

- Deploy the Kubernetes dashboard and expose it using the NodePort - `30080`
```bash
kc apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kc delete svc/kubernetes-dashboard -n kubernetes-dashboard

cat << EOF | kc apply -f -
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-nodeport
  namespace: kubernetes-dashboard
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30080
  selector:
    k8s-app: kubernetes-dashboard
EOF

cat <<EOF | kubectl apply -f -
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-for-bootstrappers
subjects:
- kind: Group
  name: system:bootstrappers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-n0iqpx
  namespace: kube-system

type: bootstrap.kubernetes.io/token
stringData:
  # Human readable description. Optional.
  description: dashboard-admin-user

  # Token ID and secret. Required.
  token-id: n0iqpx
  token-secret: t63ia1aluwe8f8iw

  # Allowed usages.
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:worker
EOF
```
- Generate a self-signed certificate trusted using CA authority of the cluster
```bash
mkdir certs && cd certs/
cat <<EOF | cfssl genkey - | cfssljson -bare server
{
  "hosts": [
    "${IP}",
    "${IP}:30080"
  ],
  "CN": "${IP}",
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [{
    "C": "BE",
    "ST": "Namur",
    "L": "Florennes",
    "O": "Red Hat Middleware",
    "OU": "Snowdrop"
  }]
}
EOF

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: kubernetes-dashboard
spec:
  request: $(cat server.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kc get csr kubernetes-dashboard -o jsonpath='{.status.certificate}' \
    | base64 --decode > server.crt
```

- Recreate the secret to use the `certificate` and `key` generated
```bash
kc delete secret/kubernetes-dashboard-certs -n kubernetes-dashboard
kc create secret tls  kubernetes-dashboard-certs -n kubernetes-dashboard --cert=server.crt --key=server-key.pem
```
- Redeploy the dashboard
```bash
kc scale --replicas=0 deployment/kubernetes-dashboard -n kubernetes-dashboard
kc scale --replicas=1 deployment/kubernetes-dashboard -n kubernetes-dashboard 
```

- Launch the dashboard
```bash
kubectl port-forward service/kubernetes-dashboard-nodeport --address localhost,${IP} 30080:443 -n kubernetes-dashboard & 
```

#### Install kind
```bash
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
chmod +x ./kind
sudo mv  ./kind /usr/local/bin

sudo kind create cluster --name kubecf --config=cfg.yml
sudo kind get kubeconfig --name kubecf > .kubeconfig
export KUBECONFIG=.kubeconfig
sudo docker exec -it "kubecf-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'
```
- Create kind cluster
```bash
cat << _EOF_ > cfg.yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        authorization-mode: "AlwaysAllow"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
_EOF_
```
