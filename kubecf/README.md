# VMWare Tanzu and Pivotal

## Doc

- Install locally cfdev and deploy an application: https://tanzu.vmware.com/tutorials/getting-started/local/install-pivotal-dev
- Deploy cloudfoundry on a local k8s: https://medium.com/@jmpinto/deploying-cloudfoundry-on-a-local-kubernetes-9103a57bf713
- kubecf doc: https://kubecf.suse.dev/docs/getting-started/kubernetes-deploy/
- cf-operator: https://github.com/cloudfoundry-incubator/cf-operator

## Deploy kubecf on Kind

- Install first [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
```bash
cd ~/temp
alias sudo='sudo env PATH=$PATH'
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
chmod +x ./kind
sudo mv kind /usr/local/bin
```
- Create a [kind config file]() mapping and exposing additional ports and configuring ingress
```bash
cat << _EOF_  > cfg.yml
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
- Create a kubernetes cluster
```bash
sudo kind create cluster --name kubecf --config=cfg.yml
sudo kind get kubeconfig --name kubecf > .kubeconfig
```

- Create an alias to use `kc` instead of kubectl and export the KUBECONFIG var
```bash
alias kc=kubectl
export KUBECONFIG=.kubeconfig
```
- Create a namespace for the cf-operator and install it
```bash
kc create namespace cf-operator
helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```
- Create the following `values.yaml` file with the `Node IP` address that we could use within the vm
```bash
node_ip=$(kubectl get node kubecf-control-plane \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }')
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
services:
  router:
    externalIPs:
    - ${node_ip}
kube:
  service_cluster_ip_range: 0.0.0.0/0
  pod_cluster_ip_range: 0.0.0.0/0
_EOF_
```

- Install the `KubeCF` helm chart
```bash
helm install kubecf \
   --namespace kubecf \
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```

### Additional features needed for kind

- Create a RBAC and token for the user accessing the dashboard
```bash
export NODE_IP=95.217.134.196
cat << _EOF_  > security-dashboard.yml
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
  name: bootstrap-token-4rp3cg
  namespace: kube-system

type: bootstrap.kubernetes.io/token
stringData:
  # Human readable description. Optional.
  description: snowdrop-admin-user

  # Token ID and secret. Required.
  token-id: 4rp3cg
  token-secret: gyc63n7m1t0oj8wv

  # Allowed usages.
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:worker
_EOF_

kc apply -f security-dashboard.yml
```

- Install the k8s dashboard
```bash
kc apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
```

- Deploy [Ingress](https://kind.sigs.k8s.io/docs/user/ingress/) controller
```bash
kc apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kc apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/baremetal/service-nodeport.yaml
kc patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":443,"hostPort":443}]}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```
- Create an `ingress resource` for the dashboard
```bash
cat << _EOF_  > ingress-dashboard.yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    kubernetes.io/ingress.class: nginx
  labels:
    app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  rules:
  - host: k8s-console.${NODE_IP}.nip.io
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
        path: /
_EOF_

kc apply -f ingress-dashboard.yml
```

- To destroy/clean the cluster
```bash
sudo kind delete cluster --name kubecf
```

## Using Kubernetes cluster

**NOTE**: The scenario reported here will fail due to a problem with the Certificate needed by the UAA application. [Ticket](https://github.com/cloudfoundry-incubator/kubecf/issues/483) has been created and should be fiexed with
release [1.2.0](https://github.com/cloudfoundry-incubator/kubecf/issues?q=is%3Aopen+is%3Aissue+milestone%3A1.2.0)

- SSH to the vm where k8s >= 1.15 is deployed
```bash
ssh -i ~/.ssh/id_rsa_snowdrop_hetzner_k03-k116 snowdrop@95.217.134.196 -p 47286
```
- Install Helm tool within the VM

```bash
mkdir temp && cd temp
sudo yum install wget
wget https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz
tar -vxf helm-v3.1.1-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
alias kc=kubectl
```

- Create a namespace for the cf-operator and install it
```bash
kc create ns cf-operator

helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```

- Create the following `values.yaml` file with the VM Ethernet IP address that we could use from our laptop
```bash
NODE_NAME=k03-k116
node_ip=$(kubectl get node ${NODE_NAME} \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }')
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
services:
  router:
    externalIPs:
    - ${node_ip}
kube:
  service_cluster_ip_range: 0.0.0.0/0
  pod_cluster_ip_range: 0.0.0.0/0
_EOF_
```

- Install the `KubeCF` helm chart
```bash
helm install kubecf \
   --namespace kubecf \
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```
