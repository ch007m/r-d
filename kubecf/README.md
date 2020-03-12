# VMWare Tanzu and Pivotal

## Doc

- Install locally cfdev and deploy an application: https://tanzu.vmware.com/tutorials/getting-started/local/install-pivotal-dev
- Deploy cloudfoundry on a local k8s : https://medium.com/@jmpinto/deploying-cloudfoundry-on-a-local-kubernetes-9103a57bf713
- kubecf doc: https://kubecf.suse.dev/docs/getting-started/kubernetes-deploy/
- cf-operator : https://github.com/cloudfoundry-incubator/cf-operator

## Kind

kind create cluster --name kubecf
kind get kubeconfig --name kubecf > .kubeconfig
cat .kubeconfig

export KUBECF_RELEASE=v1.0.0
kc create namespace cf-operator
kc get pods -A

helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"

"quarks" has been added to your repositories
NAME              	CHART VERSION    	APP VERSION      	DESCRIPTION
quarks/cf-operator	3.2.1+0.ga32a3f79	3.2.1+0.ga32a3f79	A Helm chart for cf-operator, the k8s operator ...
NAME: cf-operator
LAST DEPLOYED: Thu Mar 12 13:12:20 2020
NAMESPACE: cf-operator
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Running the operator will install the following CRD´s:

- boshdeployments.quarks.cloudfoundry.org
- quarksjobs.quarks.cloudfoundry.org
- quarksecrets.quarks.cloudfoundry.org
- quarkstatefulsets.quarks.cloudfoundry.org

You can always verify if the CRD´s are installed, by running:
 $ kubectl get crds

Interacting with the cf-operator pod

1. Check the cf-operator pod status
  kubectl -n cf-operator get pods

2. Tail the cf-operator pod logs
  export OPERATOR_POD=$(kubectl get pods -l name=cf-operator --namespace cf-operator --output name)
  kubectl -n cf-operator logs $OPERATOR_POD -f

3. Apply one of the BOSH deployment manifest examples
  kubectl -n kubecf apply -f docs/examples/bosh-deployment/boshdeployment-with-custom-variable.yaml

4. See the cf-operator in action!
  watch -c "kubectl -n kubecf get pods"

kubectl -n cf-operator get pods
NAME                                      READY   STATUS    RESTARTS   AGE
cf-operator-654fd599b8-fdjkr              1/1     Running   0          76s
cf-operator-quarks-job-66b8549cfd-rv6k7   1/1     Running   0          76s  

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


helm install kubecf --namespace kubecf --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
kubectl -n kubecf get pods


## Using Kubeadm

- Install Helm

```bash
ssh -i ~/.ssh/id_rsa_snowdrop_hetzner_k03-k116 snowdrop@95.217.134.196 -p 47286

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

- Install the `KubeCF` package
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


helm install kubecf --namespace kubecf --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
kubectl -n kubecf get pods
```
