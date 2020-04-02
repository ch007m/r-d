## Deploy Service Catalog

- Deploy first the Service Catalog API and change the webhook service secure port as the same port is already used by Istio
```bash
git clone https://github.com/kubernetes-sigs/service-catalog.git
kubectl create ns catalog
cat << _EOF_ > svc.yml
image: quay.io/kubernetes-service-catalog/service-catalog:canary

webhook:
  service:
    port: 443
    type: NodePort
    nodePort:
      securePort: 31444
_EOF_

helm install catalog service-catalog/charts/catalog -n catalog --values ./svc.yml
```
- Next, install the Service Catalog Client `svcat`
```bash
curl -sLO https://download.svcat.sh/cli/latest/linux/amd64/svcat
chmod +x ./svcat
sudo mv ./svcat /usr/local/bin/
```

## Minibroker

- And deploy the mini-broker. More information] is available [here](https://svc-cat.io/docs/walkthrough/). 
 
```bash
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
kc create ns minibroker
helm install minibroker -n minibroker minibroker/minibroker
```
- If minibroker will be used with CF, then use the following [instructions](https://github.com/kubernetes-sigs/minibroker#usage-with-cloud-foundry)
```bash
helm install minibroker -n minibroker minibroker/minibroker \
	--set "deployServiceCatalog=false" \
    --set "defaultNamespace=minibroker"
```

- To play with CF and minibroker - see [here](https://github.com/kubernetes-sigs/minibroker#usage)

## OAB

```bash
cat << _EOF_ > oab.yml
apiVersion: v1
kind: Namespace
metadata:
  name: oab
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: automation-broker-apb
  namespace: oab
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: automation-broker-apb
roleRef:
  name: cluster-admin
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: automation-broker-apb
    namespace: oab
---
apiVersion: v1
kind: Pod
metadata:
  name: automation-broker-apb
  namespace: oab
spec:
  serviceAccount: automation-broker-apb
  containers:
    - name: apb
      image: docker.io/automationbroker/automation-broker-apb:latest
      args:
        - "provision"
        - "-e create_broker_namespace=true"
        - "-e broker_auto_escalate=true"
        - "-e wait_for_broker=true"
      imagePullPolicy: IfNotPresent
  restartPolicy: Never
_EOF_

kc apply -f oab.yml
```
- Wait a few minutes and next check plans, brokers

## Dummy test

- Create a Service instance and binding
```bash
cat << _EOF_ > serviceinstance.yml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: mini-postgresql
spec:
  clusterServiceClassExternalName: postgresql
  clusterServicePlanExternalName: 11-6-0
  parameters:
    param-1: value-1
    param-2: value-2
_EOF_

kc apply -n db -f serviceinstance.yml
svcat describe instance -n db mini-postgresql

cat << _EOF_ > servicebinding.yml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  name: mini-binding
spec:
  instanceRef:
    name: mini-postgresql
_EOF_

kc apply -n db -f servicebinding.yml
svcat describe binding -n db mini-binding
```

