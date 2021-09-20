
KUBE_CFG_FILE=${1:-h01-121}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

DEST_DIR="/usr/local/bin"

VM_IP="<CHANGE_ME>"
CONTAINER_REGISTRY_URL="$VM_IP:32500"
CONTAINER_REGISTRY_USERNAME="<CHANGE_ME>"
CONTAINER_REGISTRY_PASSWORD="<CHANGE_ME>"

TANZU_LEGACY_API_TOKEN="<CHANGE_ME>"
TANZU_REG_USERNAME="<CHANGE_ME>"
TANZU_REG_PASSWORD="<CHANGE_ME>"

TANZU_TAP_CLI_VERSION="v1.4.0"
TANZU_FLUX_VERSION="v0.17.0"
TANZU_KAPP_VERSION="latest"
TANZU_BUILD_SERVICE_VERSION="1.2.2"
TANZU_TEMP_DIR="./tanzu"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo "#### Install Tanzu tools: pivnet, ytt, kapp, imgpkg, kbld #####"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "#### Detected Linux OS ####"
  curl -L https://carvel.dev/install.sh | sudo bash
  echo "TODO : Add command to install pivnet"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "#### Detected Mac OS ####"
  brew tap vmware-tanzu/carvel
  brew reinstall ytt kbld kapp kwt imgpkg vendir
  brew reinstall pivotal/tap/pivnet-cli
fi

echo "### Create tanzu directory ####"
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

echo "### Download TANZU CLIENT"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "#### Detected Linux OS ####"
  TANZU_PRODUCT_FILE_ID="1040320"
  TANZU_PRODUCT_NAME="tanzu-cli-bundle-linux-amd64"

elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "#### Detected Mac OS ####"
  TANZU_PRODUCT_FILE_ID="1040323"
  TANZU_PRODUCT_NAME="tanzu-cli-bundle-darwin-amd64"
fi

echo "### Pivnet log in to Tanzu ###"
pivnet login --api-token=$TANZU_LEGACY_API_TOKEN

# Download the TANZU client
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='0.1.0' --product-file-id=$TANZU_PRODUCT_FILE_ID
tar -vxf $TANZU_PRODUCT_NAME.tar
cp cli/core/$TANZU_TAP_CLI_VERSION/tanzu-core* $DEST_DIR/tanzu

# Next, configure the Tanzu client to install the plugin `package`. This extension will be used to download the resources from the Pivotal registry
tanzu plugin clean
tanzu plugin install -v $TANZU_TAP_CLI_VERSION --local cli package
tanzu package version

# Install the needed components: kapp controller, fluxcd
kapp deploy -a flux -f https://github.com/fluxcd/flux2/releases/download/$TANZU_FLUX_VERSION/install.yaml -y
sleep 1m
kapp deploy -a kubectl -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/$TANZU_KAPP_VERSION/download/release.yml -y
sleep 1m

# Deploy TAP
# 1. Create NS
kubectl create ns tap-install

# Step 2. Create K8S secret containing Tanzu registry creds
kubectl create secret docker-registry tap-registry \
  -n tap-install \
  --docker-server='registry.pivotal.io' \
  --docker-username=$TANZU_REG_USERNAME \
  --docker-password=$TANZU_REG_PASSWORD

# Step 3. Download the TAP repository
echo "### Pivnet log in to Tanzu ###"
pivnet download-product-files --product-slug='tanzu-application-platform' \
   --release-version='0.1.0' \
   --product-file-id=1029762

kapp deploy -a tap-package-repo \
   -n tap-install \
   -f ./tap-package-repo.yaml -y

# 4. Install the TAP packages
# Configure and install: CNR
cat <<EOF > cnr.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$TANZU_REG_USERNAME"
  password: "$TANZU_REG_PASSWORD"

provider: local
pdb:
  enable: "true"

ingress:
  reuse_crds:
  external:
    namespace:
  internal:
    namespace:

local_dns:
  enable: "false"
EOF

tanzu package install cloud-native-runtimes \
   -p cnrs.tanzu.vmware.com \
   -v 1.0.1 \
   -n tap-install \
   -f ./cnr.yml

# 4. Install the TAP packages
# Configure and install: Application Accelerator
cat <<EOF > app-accelerator.yml
registry:
  server: "registry.pivotal.io"
  username: "$TANZU_REG_USERNAME"
  password: "$TANZU_REG_PASSWORD"
server:
  # Set this service_type to "NodePort" for local clusters like minikube.
  service_type: "NodePort" # or LoadBalancer
  watched_namespace: "default"
  engine_invocation_url: "http://acc-engine.accelerator-system.svc.cluster.local/invocations"
engine:
  service_type: "ClusterIP"
EOF

tanzu package install app-accelerator \
   -p accelerator.apps.tanzu.vmware.com \
   -v 0.2.0 \
   -n tap-install \
   -f app-accelerator.yml

# Configure and install: Application View
cat <<EOF > app-live-view.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD"
EOF

tanzu package install app-live-view \
   -p appliveview.tanzu.vmware.com \
   -v 0.1.0 \
   -n tap-install \
   -f ./app-live-view.yml

# 5. Deploy some Accelerator samples to feed the `Application Accelerator` dashboard
cat <<EOF > sample-accelerators-0-2.yaml
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: new-accelerator
spec:
  git:
    url: https://github.com/sample-accelerators/new-accelerator
    ref:
      branch: main
      tag: v0.2.x
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: hello-fun
spec:
  git:
    url: https://github.com/sample-accelerators/hello-fun
    ref:
      branch: main
      tag: v0.2.x
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: hello-ytt
spec:
  git:
    url: https://github.com/sample-accelerators/hello-ytt
    ref:
      branch: main
      tag: v0.2.x
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: spring-petclinic
spec:
  git:
    ignore: ".git"
    url: https://github.com/sample-accelerators/spring-petclinic
    ref:
      branch: main
      tag: v0.2.x
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: spring-sql-jpa
spec:
  git:
    url: https://github.com/sample-accelerators/spring-sql-jpa
    ref:
      branch: main
      tag: v0.2.x
---
apiVersion: accelerator.apps.tanzu.vmware.com/v1alpha1
kind: Accelerator
metadata:
  name: node-accelerator
spec:
  git:
    url: https://github.com/sample-accelerators/node-accelerator
    ref:
      branch: main
      tag: v0.2.x
EOF

kubectl apply -f ./sample-accelerators-0-2.yaml

# Install Tanzu Build Service

# The following certificate (TO BE CHANGED) is only needed when you use a local private container registry
cat <<EOF > reg-ca.crt
-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBADANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwprdWJl
cm5ldGVzMB4XDTIxMDkxNDEyMTM0NFoXDTMxMDkxMjEyMTM0NFowFTETMBEGA1UE
AxMKa3ViZXJuZXRlczCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJCC
uxekCnvsm2Sv5Pui5GZIu3x/wkfJfWkiLDPuCB1pFHPK4GVShNIynHDwwGeaTCzL
L44Pz4YDcL3Jbk9sT3cGBy5BJw81TWLJ8Yrm+HCTc9QWnQBFJuYVp5MylR2MfdvZ
anw0gJTlTRUUVmmd2XznV2nCr+Ncb4LIG1Yo56VGvUC/DQV9oxRGGQA4W2rG2WqC
HSefsqry1g/HIMyb+G8cXf1k655aA44wtC2oHEN3clcY3CYxjZdOg18Qyg7LaPB5
CvIjsI1mVRVCgaXSR9HKP1vIJyvnRw853ClfCSqHKLgGoWvMijimb5grpFbXEypl
VZIURtX3UhHwamBXCusCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMA8GA1UdEwEB
/wQFMAMBAf8wHQYDVR0OBBYEFAvapiI873ufa88VpVdU4hYr/kXwMA0GCSqGSIb3
DQEBCwUAA4IBAQBHSBBzhWklQPefBZC0G5TeZeJeN8Wf5sB1pRjqwe111XbsF6cP
t5RZqKLJXSj4NIIJIPXKgDjAyfRt/dkeMeVqbuBA7mB+iFu/5lyI4nZtywOxp+0s
qBtMI+ASLketAxHtqn6CmIQSRC4dNCEmVW2iHzhUxPutOjcKsAMONhj9aRFs3Yy1
nWs+sTbsABmNR3qUBKsiiLJa2FeTtTnu2cOeHw1xIN4+/1UriqbfMIwv9i3/w+sP
9SEgQWnRR4dwSWlz2z0vzMYYUPjW1m0t+kDhI5NoTgVXDXbnwpo6CihYlDSK9/WS
qhq84mkP+KnMmozE3/JN8CMSnTYNYAIaNBq0
-----END CERTIFICATE-----
EOF
#
# DO NOT FORGET TO COPY THE CERTIFICATE UNDER /etc/docker/certs.d !
# sudo mkdir -p /etc/docker/certs.d/95.217.159.244:32500
# sudo cp reg-ca.crt /etc/docker/certs.d/95.217.159.244:32500/ca.crt
#

# 1. Log on to the private or public container registry
docker login \
   -u=$CONTAINER_REGISTRY_USERNAME \
   -p=$CONTAINER_REGISTRY_PASSWORD \
   $CONTAINER_REGISTRY_URL

# 2. Log on to the Tanzu container registry
docker login \
   -u=$TANZU_REG_USERNAME \
   -p=$TANZU_REG_PASSWORD \
   registry.pivotal.io

# 3. Copy the TBS images to the `<REGISTRY_USER>`/build-service repository

IMAGE_REPOSITORY=$CONTAINER_REGISTRY_URL/buildservice
imgpkg copy -b "registry.pivotal.io/build-service/bundle:$TANZU_BUILD_SERVICE_VERSION" --to-repo $IMAGE_REPOSITORY --registry-ca-cert-path reg-ca.crt

imgpkg pull -b "$IMAGE_REPOSITORY:$TBS_VERSION" -o ./bundle --registry-ca-cert-path reg-ca.crt

# 4. Deploy TBS
ytt -f ./bundle/values.yaml \
    -f ./bundle/config/ \
    -f reg-ca.crt \
    -v docker_repository=$CONTAINER_REGISTRY_URL/ \
    -v docker_username=$CONTAINER_REGISTRY_USERNAME \
    -v docker_password=$CONTAINER_REGISTRY_PASSWORD \
    | kbld -f ./bundle/.imgpkg/images.yml -f- \
    | kapp deploy -a tanzu-build-service -f- -y

# 5. Install the kp client
echo "### Download KP"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "#### Detected Linux OS ####"
  TANZU_PRODUCT_FILE_ID="1000629"
  TANZU_PRODUCT_NAME="kp-linux-0.3.1"

elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "#### Detected Mac OS ####"
  TANZU_PRODUCT_FILE_ID="1000628"
  TANZU_PRODUCT_NAME="kp-darwin-0.3.1"
fi

pivnet download-product-files --product-slug='build-service' \
   --release-version=$TANZU_BUILD_SERVICE_VERSION \
   --product-file-id=$TANZU_PRODUCT_FILE_ID

chmod +x $TANZU_PRODUCT_NAME
cp $TANZU_PRODUCT_NAME $DEST_DIR/kp

# 6. Import the `Tanzu Build Service` dependencies` such as: lifecycle, buildpacks (go, java, python, ..)
#    using the dependency descriptor `descriptor-<version>.yaml` file
pivnet download-product-files --product-slug='tbs-dependencies' \
    --release-version='100.0.155'\
    --product-file-id=1036685

kp import -f ./descriptor-100.0.155.yaml \
   --registry-ca-cert-path reg-ca.crt

## Patch the KNative Serving config-domain configmap to expose as domain: <VM_IP>.nip.io
## TODO: Fix the error : invalid JSON Path
PATCH="{\"data\":{\"$VM_IP.nip.io\": \"\"}}"
kubectl patch cm/config-domain -n knative-serving \
  --type merge \
  -p $PATCH

popd




