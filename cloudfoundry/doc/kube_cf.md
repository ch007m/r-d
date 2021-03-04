## Install KubeCF

To use [`kubecf`](https://kubecf.suse.dev/), you will install 2 helm charts in order to deploy:

- cf-operator: https://cloudfoundry-incubator.github.io/quarks-helm/
- kubecf: https://github.com/cloudfoundry-incubator/kubecf/tree/master/deploy/helm/kubecf

**NOTES**

The `cf-operator` is the underlying generic tool to deploy a (modified) BOSH deployment like `Kubecf` for use.
It has to be installed in the same Kubernetes cluster that Kubecf will be deployed to.

In this default deployment, kubecf is launched without Ingress, and it uses the `Eirini` scheduler.

## Table of Contents

   * [Cluster created with kubeadm, kubelet](#cluster-created-with-kubeadm-kubelet)
   * [Using Kind](#using-kind)
   * [Stratos console (Optinal)](#stratos-console-optinal)
   
### Cluster created with kubeadm, kubelet

**NOTE**: The scenario reported here will fail due to a problem with the Certificate needed by the UAA application. [Ticket](https://github.com/cloudfoundry-incubator/kubecf/issues/483) has been created and should be fiexed with
release [1.2.0](https://github.com/cloudfoundry-incubator/kubecf/issues?q=is%3Aopen+is%3Aissue+milestone%3A1.2.0)

- SSH to the vm where k8s >= 1.15 is deployed
```bash
ssh -i ~/.ssh/id_rsa_snowdrop_hetzner_k03-k116 snowdrop@95.217.134.196 -p 47286
```

- Install common [tools](tools.md)

- Create a namespace for the cf-operator and install it
```bash
kc create ns cf-operator

helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```

- Create the following `values.yaml` file with the VM Ethernet IP address that we could use from our laptop
```bash
NODE_NAME=<IP_ETH0_ADDRESS>
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
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.1/kubecf-v1.0.1.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```

### Using Kind

- See [instructions](kind.md) and [kubecf](https://kubecf.suse.dev/docs/tutorials/deploy-kind/) documentation
- Create a [kind config file](https://kind.sigs.k8s.io/docs/user/ingress/#ingress) mapping and exposing additional ports and configuring ingress
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

- Create an alias to use `kc` instead of `kubectl` and export the `KUBECONFIG` env var
```bash
alias kc=kubectl
export KUBECONFIG=.kubeconfig
```
- Trust the `kubernetes root CA` on the `kind docker container`
```bash 
sudo docker exec -it "kubecf-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'
Updating certificates in /etc/ssl/certs...
0 added, 0 removed; done.
Running hooks in /etc/ca-certificates/update.d...
done.
```
- Create a namespace for the cf-operator and install it
```bash
kc create namespace cf-operator
helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```
- Create the following `values.yaml` file with the `Node IP` address that we could use within the vm.
```bash
node_ip=$(kubectl get node kubecf-control-plane \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }')
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
features:
  eirini:
    enabled: true
  ingress:
    enabled: false
    tls:
      crt: ~
      key: ~
    annotations: {}
    labels: {}
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
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.1/kubecf-v1.0.1.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```

- To destroy/clean the cluster
```bash
sudo kind delete cluster --name kubecf
```

### Stratos console (Optinal)

See [instructions](others.md)