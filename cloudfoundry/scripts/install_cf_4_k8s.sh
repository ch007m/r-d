IP_ADDR=$(/usr/sbin/ifconfig eth0  | grep 'inet ' | cut -d: -f2 | awk '{ print $2}')

CERT_INJECT_WEBHOOK_URL=https://github.com/vmware-tanzu/cert-injection-webhook.git
CERT_INJECT_WEBHOOK_FOLDER=cert-injection-webhook

CERTIFICATE_FILE=../server.crt

CF_URL=https://github.com/cloudfoundry/cf-for-k8s.git
CF_FOLDER=cf-for-k8s
CF_VALUES_FILE=new-cf-values.yml

REGISTRY_ADDRESS=$IP_ADDR
REGISTRY_PROTOCOL=https
REGISTRY_PREFIX=cmoulliard
REGISTRY_PORT=31000
REGISTRY_USERNAME=admin
REGISTRY_PASSWORD=snowdrop

BUILD_IMAGE=${1:-false}

function setupCertInjectWebhook() {

if [ ! -d "$CERT_INJECT_WEBHOOK_FOLDER" ] ; then
  git clone $CERT_INJECT_WEBHOOK_URL $CERT_INJECT_WEBHOOK_FOLDER
else
    cd "$CERT_INJECT_WEBHOOK_FOLDER"
    git pull
    cd ..
fi

cd cert-injection-webhook

echo "######################################"
echo "Build cert-webhook images: $BUILD_IMAGE"
echo "######################################"
if $BUILD_IMAGE; then
  pack build $REGISTRY_PREFIX/my-setup-ca-certs  \
      -e BP_GO_TARGETS="./cmd/setup-ca-certs"  \
      --publish  \
      --builder paketobuildpacks/builder:base
  pack build $REGISTRY_PREFIX/my-cert-webhook  \
       -e BP_GO_TARGETS="./cmd/pod-webhook"  \
       --publish
fi

if [ -f "$CERTIFICATE_FILE" ]; then
    ytt -f ./deployments/k8s \
      -v pod_webhook_image=$REGISTRY_PREFIX/my-cert-webhook \
      -v setup_ca_certs_image=$REGISTRY_PREFIX/my-setup-ca-certs \
      --data-value-file ca_cert_data=$CERTIFICATE_FILE \
      --data-value-yaml labels="[kpack.io/build,app]" \
      --data-value-yaml annotations="[kpack.io/build]" \
      > manifest.yaml
    echo "######################################"
    echo "Install cert-injection-webhook"
    echo "######################################"
    kapp delete -a cert-injection-webhook -y
    kapp deploy -a cert-injection-webhook -f ./manifest.yaml -y
else
    echo "#####################################################################################"
    echo "IMPORTANT: The self signed file is missing !!"
    echo "Copy it server.crt under the ./tmp directory please"
    echo "#####################################################################################"
    exit 0
fi

cd ..
}

function configureInstallCF() {
if [ ! -d "$CF_FOLDER" ] ; then
    git clone $CF_URL $CF_FOLDER
else
    cd "$CF_FOLDER"
    git pull
    cd ..
fi

cd $CF_FOLDER

./hack/generate-values.sh -d $IP_ADDR.nip.io > /tmp/$CF_VALUES_FILE

cat << EOF >> /tmp/$CF_VALUES_FILE
app_registry:
  hostname: $REGISTRY_ADDRESS:$REGISTRY_PORT
  repository_prefix: $REGISTRY_ADDRESS:$REGISTRY_PORT/cmoulliard
  username: $REGISTRY_USERNAME
  password: $REGISTRY_PASSWORD

add_metrics_server_components: true
enable_automount_service_account_token: true
load_balancer:
  enable: false
metrics_server_prefer_internal_kubelet_address: true
remove_resource_requirements: true
use_first_party_jwt_tokens: true
EOF

cat /tmp/$CF_VALUES_FILE

kapp delete -a cf -y
kapp deploy -a cf -f <(ytt -f config -f /tmp/$CF_VALUES_FILE) -y
cd ..
}

#
# Main program
#

echo "**********************"
echo "IP ETH0: $IP_ADDR"
echo "**********************"

pushd tmp

setupCertInjectWebhook
configureInstallCF

popd
