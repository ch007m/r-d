## Launch a local registry for kind

More information can be found here:

- https://kind.sigs.k8s.io/docs/user/local-registry/
- https://gabrieltanner.org/blog/docker-registry

### Create a htpwd user/pwd
```bash
sudo yum install httpd-utils
cd tmp
htpasswd -Bc registry.password cmoulliard
<ADD PWD>
```

### Create a registry container
```bash
cat << EOF > docker-compose.yml
version: '3'

services:
  registry:
    container_name: "kind-registry"
    image: registry:2
    ports:
      - "127.0.0.1:5000:5000"
    environment:
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/registry.password
    restart: always
    volumes:
      - /home/snowdrop/tmp:/auth
EOF

docker-compose up --force-recreate -d
```

## Create a cluster with the local registry enabled in containerd
```bash
cat <<EOF | kind create cluster --config=-
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
    extraPortMappings:
      - protocol: TCP
        containerPort: 80
        hostPort: 80
      - protocol: TCP
        containerPort: 443
        hostPort: 443
      - protocol: TCP
        containerPort: 30000
        hostPort: 30000
      - protocol: TCP
        containerPort: 5000
        hostPort: 31000
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
      endpoint = ["http://kind-registry:5000"]
EOF
```

### Connect the registry to the cluster network
```bash
docker network connect "kind" "kind-registry" || true
```

### Document the local registry

See - https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:5000"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
```
### Create a kubernetes secret containing Docker User/pwd
```bash
kubectl create secret docker-registry regcred -n default \
  --docker-server=localhost:5000 \
  --docker-username=cmoulliard \
  --docker-password=dabou
```
### Do a test

- Tag and push
```bash
docker pull gcr.io/google-samples/hello-app:1.0
docker tag gcr.io/google-samples/hello-app:1.0 localhost:5000/hello-app:1.0

docker login localhost:5000 -u cmoulliard -p dabou
docker push localhost:5000/hello-app:1.0
```
- And now we can create a Kubernetes pod consuming the image created within the local registry
```bash  
kc delete deployment/hello-server -n default
cat << EOF | kc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "1"
  labels:
    app: hello-server
  name: hello-server
  namespace: default
spec:
  selector:
    matchLabels:
      app: hello-server
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: hello-server
    spec:
      containers:
        - image: 95.217.159.244:31000/hello-app:1.0
          imagePullPolicy: IfNotPresent
          name: hello-app
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
      imagePullSecrets:
      - name: regcred
EOF
```
