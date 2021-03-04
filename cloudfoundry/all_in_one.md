# Create a k8s cluster and play with CF

## Table of content

  * [Create a K8s cluster](#create-a-k8s-cluster)
  * [Install tools](#install-tools)
  * [Install CloudFoundry](#install-cloudfoundry)
      * [Deploy cf-4-k8s](#deploy-cf-4-k8s)
      * [Access CAPI](#access-capi)
        * [Push an application using an existing container image](#push-an-application-using-an-existing-container-image)
        * [Push an application using buildpack](#push-an-application-using-buildpack)
      * [What about using Spring Music ;-)](#what-about-using-spring-music--)
      * [Optional](#optional)
        * [Install Stratos](#install-stratos)
        * [Bitnami Service catalog](#bitnami-service-catalog)
        * [Kubernetes dashboard](#kubernetes-dashboard)
    
## Create a K8s cluster

- Using a Centos7 [vm](k8s-vm.md) created on hetzner cloud provider
- or [kind](kind.md)

## Install tools

See [tools](tools.md)

## Install CloudFoundry

### Deploy cf-4-k8s

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

### Access CAPI

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

#### Push an application using an existing container image

- Push the docker image of an application
```bash
cf push test-app1 -o cloudfoundry/diego-docker-app
```

#### Push an application using buildpack

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

### What about using Spring Music ;-)

Move to the [developer page](developer.md) to play with the `Spring Music` application and a database

### Optional 

#### Install Stratos

See [others](others.md)

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