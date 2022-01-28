#!/usr/bin/env bash
#
# To remotely install this script within a VM using SSH, execute:
# Change the REMOTE_HOME_DIR var o point to the remote VM home dir
# Define the following env vars:
# - TANZU_LEGACY_API_TOKEN used by pivnet to login
# - TANZU_REG_USERNAME: user to be used to be authenticated against the Tanzu image registry
# - TANZU_REG_PASSWORD: password to be used to be authenticated against the Tanzu image registry
#
# ssh-hetznerc h01-121 'bash -s' < ./install.sh
#
KUBE_CFG_FILE=${1:-h01-121}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

REMOTE_HOME_DIR="/home/snowdrop"
DEST_DIR="/usr/local/bin"

VM_IP=65.108.51.37
REGISTRY_URL="$VM_IP:32500"
REGISTRY_USERNAME="admin"
REGISTRY_PASSWORD="snowdrop"

TANZU_LEGACY_API_TOKEN="jzZZHugEFBS_2K_y4KXh"
TANZU_REG_USERNAME="cmoulliard@redhat.com"
TANZU_REG_PASSWORD=".P?V9yM^e3vsVH9"

INGRESS_DOMAIN=$VM_IP.xip.io

PIVNET_CLI_VERSION="3.0.1"
TANZU_CLUSTER_ESSENTIALS_VERSION="1.0.0"
TAP_VERSION="1.0.0"
TANZU_CLI_VERSION="v0.10.0"

TAP_GIT_CATALOG_REPO=https://raw.githubusercontent.com/halkyonio/tap-catalog-blank/main

TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo "## Executing installation Part I of the TAP guide"
echo "## Install Tanzu tools "
echo "## Installing pivnet tool ..."
wget -c https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_CLI_VERSION/pivnet-linux-amd64-$PIVNET_CLI_VERSION
chmod +x pivnet-linux-amd64-$PIVNET_CLI_VERSION && mv pivnet-linux-amd64-$PIVNET_CLI_VERSION pivnet && sudo cp pivnet /usr/local/bin
pivnet version

echo "### Pivnet log in to Tanzu "
pivnet login --api-token=$TANZU_LEGACY_API_TOKEN

echo "### Create tanzu directory "
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

## Install the Tanzu Application Platform GUI Blank Catalog
##pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=1099786
## echo "TODO: You must extract that catalog to the preceding Git repository of choice. This serves as the configuration location for your Organization's Catalog inside Tanzu Application Platform GUI."

# Download Cluster Essentials for VMware Tanzu
echo "### Set the Cluster Essentials product ID "
TANZU_CLUSTER_ESSENTIALS_FILE_ID="1105818"
TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA="sha256:82dfaf70656b54dcba0d4def85ccae1578ff27054e7533d08320244af7fb0343"

echo "## Download Cluster Essentials ... "
pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version=$TANZU_CLUSTER_ESSENTIALS_VERSION --product-file-id=$TANZU_CLUSTER_ESSENTIALS_FILE_ID
mkdir -p tanzu-cluster-essentials && tar -xvf tanzu-cluster-essentials-linux-amd64-$TANZU_CLUSTER_ESSENTIALS_VERSION.tgz -C ./tanzu-cluster-essentials

echo "## Install Cluster essentials (kapp, kbld, ytt, imgpkg)"
echo "## Configure and run install.sh, which installs kapp-controller and secretgen-controller on your cluster"
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@$TANZU_CLUSTER_ESSENTIALS_IMAGE_SHA
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
cd ./tanzu-cluster-essentials
export KUBECONFIG="/home/snowdrop/.kube/config"
./install.sh

echo "## Install the kapp CLI onto your $PATH:"
sudo cp ./kapp /usr/local/bin/kapp
cd ..

echo "## Install the Tanzu client & plug-ins"
echo "## Clean previous installation of the Tanzu client"
rm -rf $TANZU_TEMP_DIR/cli        # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
rm -rf ~/.config/tanzu/       # current location # Remove config directory
rm -rf ~/.tanzu/              # old location # Remove config directory
rm -rf ~/.cache/tanzu         # remove cached catalog.yaml

echo "## Download the Tanzu client and extract it"
TANZU_PRODUCT_FILE_ID="1114447"
TANZU_PRODUCT_NAME="tanzu-framework-linux-amd64"
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version=$TAP_VERSION --product-file-id=$TANZU_PRODUCT_FILE_ID
tar -vxf $TANZU_PRODUCT_NAME.tar

echo "## Set env var TANZU_CLI_NO_INIT to true to assure the local downloaded versions of the CLI core and plug-ins are installed"
export TANZU_CLI_NO_INIT=true
sudo install cli/core/$TANZU_CLI_VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu
tanzu version

echo "## Clean install Tanzu CLI plug-ins now"
export TANZU_CLI_NO_INIT=true
tanzu plugin install --local cli all
tanzu plugin list

echo "## Executing installation Part II of the TAP guide"
echo "## Install profiles ..."

export INSTALL_REGISTRY_USERNAME=$TANZU_REG_USERNAME
export INSTALL_REGISTRY_PASSWORD=$TANZU_REG_PASSWORD
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com

echo "## Create a namespace called tap-install for deploying the packages"
kubectl create ns tap-install

echo "## Create a registry secret"
tanzu secret registry add tap-registry \
  --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} \
  --server ${INSTALL_REGISTRY_HOSTNAME} \
  --export-to-all-namespaces --yes --namespace tap-install

echo "## Add Tanzu Application Platform package repository to the k8s cluster"
tanzu package repository add tanzu-tap-repository \
  --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0 \
  --namespace tap-install

sleep 10s

tanzu package available list --namespace tap-install

echo "## Install a Tanzu Application Platform profile"
echo "## Create first the tap-values.yaml file to configute the profile .... .light"

cat <<'EOF' > tap-values.yaml
profile: light
ceip_policy_disclosed: true # Installation fails if this is set to 'false'

buildservice:
  kp_default_repository: "$REGISTRY_URL/build-service"
  kp_default_repository_username: "$REGISTRY_USERNAME"
  kp_default_repository_password: "$REGISTRY_PASSWORD"
  tanzunet_username: "$TANZU_REG_USERNAME"
  tanzunet_password: "$TANZU_REG_PASSWORD"

supply_chain: basic

ootb_supply_chain_basic:
  registry:
    server: "$REGISTRY_URL"
    repository: "tap"
  gitops:
    ssh_secret: ""

tap_gui:
  service_type: ClusterIP
  ingressEnabled: "true"
  ingressDomain: "$INGRESS_DOMAIN"
  app_config:
    app:
      baseUrl: http://tap-gui.$INGRESS_DOMAIN
    catalog:
      locations:
        - type: url
          target: $TAP_GIT_CATALOG_REPO/catalog-info.yaml
    backend:
      baseUrl: http://tap-gui.$INGRESS_DOMAIN
      cors:
        origin: http://tap-gui.$INGRESS_DOMAIN

metadata_store:
  app_service_type: NodePort
EOF

cat tap-values.yaml

popd
exit

# tanzu package install tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file tap-values.yml -n tap-install
# echo "## Verify the package install"
# tanzu package installed get tap -n tap-install

## Patch the Knative Serving config-domain configmap to expose as domain: <VM_IP>.nip.io
#PATCH="{\"data\":{\"$VM_IP.nip.io\": \"\"}}"
#kubectl patch cm/config-domain -n knative-serving \
#  --type merge \
#  -p $PATCH




