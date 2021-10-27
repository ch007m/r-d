
BIN_DEST_DIR=${1:-/usr/local/bin}
TANZU_TEMP_DIR="./tanzu/tools"

TANZU_LEGACY_API_TOKEN=${TANZU_LEGACY_API_TOKEN:-"<CHANGE_ME>"}

TANZU_TAP_CLI_VERSION  ="v0.5.0"
TANZU_PACKAGES_VERSION ="0.2.0"
PIVNET_VERSION         ="3.0.1"

echo "### Create tanzu directory ####"
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
else
    rm -rf $TANZU_TEMP_DIR/*
fi

pushd $TANZU_TEMP_DIR

echo "#### Install Tanzu tools: pivnet, ytt, kapp, imgpkg, kbld #####"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "#### Detected Linux OS ####"
  export K14SIO_INSTALL_BIN_DIR=$BIN_DEST_DIR
  curl -L https://carvel.dev/install.sh | sudo bash
  echo "#### Install pivnet"
  wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v$PIVNET_VERSION/pivnet-linux-amd64-$PIVNET_VERSION
  chmod +x pivnet-linux-amd64-$PIVNET_VERSION
  mv pivnet-linux-amd64-$PIVNET_VERSION $BIN_DEST_DIR/pivnet
elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "#### Detected Mac OS ####"
  brew tap vmware-tanzu/carvel
  brew reinstall ytt kbld kapp kwt imgpkg vendir
  brew reinstall pivotal/tap/pivnet-cli
fi

echo "### Download TANZU CLIENT"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "#### Detected Linux OS ####"
  TANZU_PRODUCT_FILE_ID="1055586"
  TANZU_PRODUCT_NAME="tanzu-framework-linux-amd64"

elif [[ "$OSTYPE" == "darwin"* ]]; then
  echo "#### Detected Mac OS ####"
  TANZU_PRODUCT_FILE_ID="1055576"
  TANZU_PRODUCT_NAME="tanzu-framework-darwin-amd64"
fi

echo "### Pivnet log in to Tanzu ###"
pivnet login --api-token=$TANZU_LEGACY_API_TOKEN

# Download the TANZU client
pivnet download-product-files \
    --product-slug='tanzu-application-platform' \
    --release-version=$TANZU_PACKAGES_VERSION \
    --product-file-id=$TANZU_PRODUCT_FILE_ID

rm -rf ~/.config/tanzu
tar -vxf $TANZU_PRODUCT_NAME.tar
cp cli/core/$TANZU_TAP_CLI_VERSION/tanzu-core* $BIN_DEST_DIR/tanzu

# Next, configure the Tanzu client to install the plugin `package`. This extension will be used to download the resources from the Pivotal registry
tanzu plugin install --local cli all

# List the tanzu plugins installed
echo "#### tanzu plugin list"
tanzu plugin list

popd