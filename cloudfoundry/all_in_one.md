# Create VM and k8s cluster using Ansible

## Table of content

  * [Create K8s cluster using Ansible](#create-k8s-cluster-using-ansible)
      * [Prerequisite](#prerequisite)
      * [How to create the VM](#how-to-create-the-vm)
  * [Install tools](#install-tools)
  * [Install CloudFoundry](#install-cloudfoundry)
      * [Deploy cf-4-k8s](#deploy-cf-4-k8s)
      * [Install cf, Stratos](#install-cf-stratos)
      * [Push an application using an existing container image](#push-an-application-using-an-existing-container-image)
      * [Push an application using buildpack](#push-an-application-using-buildpack)
      * [Optional](#optional)
          * [Bitnami Service catalog](#bitnami-service-catalog)
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
        "https://k8s-console.95.217.159.244.nip.io/",
        "",
        "Using the Boot Token: ",
        "k3hxzh.p5kiogsey4hnccpv"
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
sudo chown -R 1001:1001 /tmp
sudo chmod -R 700 /tmp

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
- Patch the dashboard service to use the external IP address
```bash
IP=<IP_ADDRESS_OF_THE_VM>
kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"externalIPs":["$IP"]}}'
```

## Install tools

- Install wget, helm, jq, brew, maven, k9s and upgrade curl
```bash
sudo yum install -y wget epel-release jq maven

sudo rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-2-1.rhel7.noarch.rpm
sudo yum -y --enablerepo=city-fan.org install libcurl libcurl-devel

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> /home/snowdrop/.bash_profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

alias sudo='sudo env PATH=$PATH'
```

## Install CloudFoundry

### Deploy cf-4-k8s

- Install gcc (needed to install ytt)
```bash
brew install gcc 
```
- Install vmware tools such as : ytt, kapp and bosh tools
```bash
brew tap vmware-tanzu/carvel
brew install ytt kbld kapp imgpkg kwt vendir yq

brew install cloudfoundry/tap/bosh-cli
```
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
- **REMARK**: When using `kind`, please execute the following command to remove istio ingress service and fix health check, cpu/memory
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config/remove-resource-requirements.yml -f config/istio/ingressgateway-service-nodeport.yml)
```
- Scale down the `ingress nginx` application deployed within the kube-system namespace, otherwise cf for k8s will fail to be deployed
```bash
$ kc scale --replicas=0 deployment.apps/nginx-ingress-controller -n kube-system
``` 
**REMARK**: This step is only needed when ingress has been deployed on a kubernetes cluster

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
brew install cloudfoundry/tap/cf-cli@7
```

- Access the CF API using the IP address of the VM
```bash
IP=<IP_ADDRESS_VM>
cf api --skip-ssl-validation https://api.$IP.nip.io
```
- Log in using the `admin` user and password `cf_admin_password` as defined under /tmp/cf-values.yml
```bash
pwd=<cf-values.yml.cf_admin_password>
cf auth admin $pwd
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

### Push an application using an existing container image

- Push the docker image of an application
```bash
cf push test-app1 -o cloudfoundry/diego-docker-app
```

### Push an application using buildpack

- Test an application compiled locally and pushed to a container registry
```bash
git clone https://github.com/cloudfoundry-samples/test-app.git
cd test-app
cf push test-app2
```
- Validate if the `test-app2` is reachable
```bash
curl -k  https://test-app2-meditating-nyala-ea.apps.95.217.159.244.nip.io/env
{"BAD_QUOTE":"'","BAD_SHELL":"$1","CF_INSTANCE_ADDR":"0.0.0.0:8080","CF_INSTANCE_INTERNAL_IP":"10.244.0.32","CF_INSTANCE_IP":"10.244.0.32","CF_INSTANCE_PORT":"8080","CF_INSTANCE_PORTS":"[{\"external\":8080,\"internal\":8080}]","HOME":"/home/some_docker_user","HOSTNAME":"diego-docker-app-demo-3c087bf83d-0","KUBERNETES_PORT":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP_ADDR":"10.96.0.1","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_SERVICE_HOST":"10.96.0.1","KUBERNETES_SERVICE_PORT":"443","KUBERNETES_SERVICE_PORT_HTTPS":"443","LANG":"en_US.UTF-8","MEMORY_LIMIT":"1024m","PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/myapp/bin","POD_NAME":"diego-docker-app-demo-3c087bf83d-0","PORT":"8080","SOME_VAR":"some_docker_value","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_ADDR":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PROTO":"tcp","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_HOST":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT_HTTP":"8080","VCAP_APPLICATION":"{\"cf_api\":\"https://api.95.217.134.196.nip.io\",\"limits\":{\"fds\":16384,\"mem\":1024,\"disk\":1024},\"application_name\":\"diego-docker-app\",\"application_uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"name\":\"diego-docker-app\",\"space_name\":\"demo\",\"space_id\":\"f148f02d-fcf3-4657-a3ea-f3f8cae530ad\",\"organization_id\":\"c4f7aa9b-18cf-4687-8073-719f61cc4168\",\"organization_name\":\"redhat.com\",\"uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"process_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"process_type\":\"web\",\"application_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\",\"application_version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\"}","VCAP_APP_HOST":"0.0.0.0","VCAP_APP_PORT":"8080","VCAP_SERVICES":"{}"}[snowdrop@k03-k116 cf-for-k8s]$
```

- Move to the [developer page](developer.md) to play with the `Spring Music` application and a database

### Optional 

#### Bitnami Service catalog

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
- Modify the service created to define the `externalIP` address
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
