# Create VM and k8s cluster using Ansible

Test done the 31 of March

- Create VM and deploy a k8s cluster
```bash
export k8s_version=116
export VM_NAME=h01-${k8s_version}
export PASSWORD_STORE_DIR=~/.password-store-snowdrop

ansible-playbook hetzner/ansible/hetzner-delete-server.yml -e vm_name=${VM_NAME} -e hetzner_context_name=snowdrop
ansible-playbook ansible/playbook/passstore_controller_inventory_remove.yml -e vm_name=${VM_NAME}  -e pass_provider=hetzner
ansible-playbook ansible/playbook/passstore_controller_inventory.yml -e vm_name=${VM_NAME}  -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version} -e operation=create
ansible-playbook hetzner/ansible/hetzner-create-server.yml -e vm_name=${VM_NAME} -e salt_text=$(gpg --gen-random --armor 1 20) -e hetzner_context_name=snowdrop -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version}
ansible-playbook ansible/playbook/sec_host.yml -e vm_name=${VM_NAME} -e provider=hetzner

ansible-playbook kubernetes/ansible/k8s.yml --limit ${VM_NAME}

ok: [h01-116] => {
    "msg": [
        "You can also view the kubernetes dashboard at",
        "https://k8s-console.95.217.161.67.nip.io/",
        "",
        "Using the Boot Token: ",
        "43qo7d.l7iwyyrw1g2tblrl"
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

# Install tools

- Install wget, helm, jq, brew, maven, k9s
```bash
sudo yum install wget -y
sudo yum install epel-release -y
sudo yum install jq -y 
sudo yum install maven -y

mkdir temp && cd temp
wget https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz
tar -vxf helm-v3.1.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin

wget https://github.com/derailed/k9s/releases/download/v0.17.7/k9s_Linux_x86_64.tar.gz
tar -vxf k9s_Linux_x86_64.tar.gz
sudo mv k9s /usr/local/bin

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
sudo yum groupinstall 'Development Tools' -y
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> /home/snowdrop/.bash_profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

alias sudo='sudo env PATH=$PATH'
```

## Deploy KubeCF

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

## Deploy cf-4-k8s

- Install ytt, kapp tools
```bash
brew tap k14s/tap
brew install ytt kbld kapp imgpkg kwt vendir
```

- Install bosh client
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
IP=95.217.161.67
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
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

## Install cf, Stratos

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

## Service catalog

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
- Install the bitnami service catalog
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

## Optional 

- Install kind
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
