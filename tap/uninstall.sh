#
# Execute this command remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
#

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

NAMESPACE="tap-install"
NAMESPACE_DEMO="tap-demo"

REMOTE_HOME_DIR="/home/snowdrop"
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

tanzu apps workload list -n $NAMESPACE_DEMO | awk '(NR>1)' | while read name app status age;
do
  echo "Deleting the $name workload under $NAMESPACE_DEMO"
  tanzu -n $NAMESPACE_DEMO apps workload delete $name --yes
done
kubectl delete ns $NAMESPACE_DEMO

while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the package: $name"
  tanzu package installed delete $name -n $NAMESPACE -y
done <<< "$(tanzu package installed list -n $NAMESPACE -o json | jq -c '.[]')"

while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the repository: $name"
  tanzu package repository delete $name -n $NAMESPACE -y
done <<< "$(tanzu package repository list -n $NAMESPACE -o json | jq -c '.[]')"

declare -a packages=("tap-install" "kapp-controller" "secretgen-controller" "tanzu-cluster-essentials"  "tanzu-package-repo-global")
for pkg in ${packages[@]}; do
   echo "Deleting the resources and namespace of: $pkg"
   kubectl delete all --all -n $pkg
   kubectl delete ns  $pkg
done

echo "## Clean previous installation of the Tanzu client"
rm -rf $TANZU_TEMP_DIR/cli    # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
rm -rf ~/.config/tanzu/       # current location # Remove config directory
rm -rf ~/.tanzu/              # old location # Remove config directory
rm -rf ~/.cache/tanzu         # remove cached catalog.yaml