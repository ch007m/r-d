REGISTRY_ADDRESS=kube-registry.infra.svc
REGISTRY_PROTOCOL=https
DOCKER_PREFIX=cmoulliard

echo "IMPORTANT: Copy the self signed cert here please using the name : server.crt !!!!! before to launch the script"

pushd cert-injection-webhook
pack build $DOCKER_PREFIX/my-setup-ca-certs -e BP_GO_TARGETS="./cmd/setup-ca-certs" --publish --builder paketobuildpacks/builder:base
pack build $DOCKER_PREFIX/my-cert-webhook -e BP_GO_TARGETS="./cmd/pod-webhook" --publish

ytt -f ./deployments/k8s \
      -v pod_webhook_image=$DOCKER_PREFIX/my-cert-webhook \
      -v setup_ca_certs_image=$DOCKER_PREFIX/my-setup-ca-certs \
      --data-value-file ca_cert_data=../server.crt \
      --data-value-yaml annotations="[kpack.io/build]" \
      > manifest.yaml

kapp delete -a cert-injection-webhook -y
kapp deploy -a cert-injection-webhook -f ./manifest.yaml -y
popd

echo "Run the k8s cmds"
kubectl create ns demo

kubectl delete ClusterStore/default
cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: ClusterStore
metadata:
  name: default
spec:
  sources:
  - image: gcr.io/paketo-buildpacks/java
EOF

kubectl delete ClusterStack/base
cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: ClusterStack
metadata:
  name: base
spec:
  id: "io.buildpacks.stacks.bionic"
  buildImage:
    image: "paketobuildpacks/build:base-cnb"
  runImage:
    image: "paketobuildpacks/run:base-cnb"
EOF

kubectl delete sa/tutorial-service-account -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tutorial-service-account
secrets:
- name: tutorial-registry-credentials
imagePullSecrets:
- name: tutorial-registry-credentials
EOF

kubectl delete secret/tutorial-registry-credentials -n demo
kubectl create secret docker-registry tutorial-registry-credentials \
     --docker-username=admin \
     --docker-password=snowdrop\
     --docker-server=$REGISTRY_PROTOCOL://$REGISTRY_ADDRESS:5000/\
     --namespace demo

kubectl delete builder/my-builder -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: kpack.io/v1alpha1
kind: Builder
metadata:
  annotations:
    kpack.io/build: cert
  name: my-builder
spec:
  serviceAccount: tutorial-service-account
  tag: $REGISTRY_ADDRESS:5000/demo/default-builder
  stack:
    name: base
    kind: ClusterStack
  store:
    name: default
    kind: ClusterStore
  order:
  - group:
    - id: paketo-buildpacks/java
EOF

kubectl delete image/tutorial-image -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: kpack.io/v1alpha1
kind: Image
metadata:
  annotations:
    kpack.io/build: cert
  name: tutorial-image
spec:
  tag: $REGISTRY_ADDRESS:5000/tutorial
  serviceAccount: tutorial-service-account
  builder:
    name: my-builder
    kind: Builder
  source:
    git:
      url: https://github.com/spring-projects/spring-petclinic
      revision: master
EOF