#
# Execute this command remotely
# ssh -i <PUB_KEY_FILE_PATH> <USER>@<IP> -p <PORT> "bash -s" -- < ./uninstall.sh
#
# Define the following env vars:
# - REMOTE_HOME_DIR: home directory where files will be installed within the remote VM
#

KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

NAMESPACE_TAP="tap-install"
NAMESPACE_TAP_DEMO="tap-demo"

REMOTE_HOME_DIR="/home/snowdrop"
DEST_DIR="/usr/local/bin"
TANZU_TEMP_DIR="$REMOTE_HOME_DIR/tanzu"

# Checking about workload to be deleted
tanzu apps workload list -n $NAMESPACE_TAP_DEMO | awk '(NR>1)' | while read name app status age;
do
  if [[ $app != exit ]]; then
    echo "Deleting the $name workload under $NAMESPACE_TAP_DEMO"
    tanzu -n $NAMESPACE_TAP_DEMO apps workload delete $name --yes
  fi
done

# Delete all the resources of the namespace and finally the namespace
kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $NAMESPACE_TAP_DEMO
kubectl delete ns $NAMESPACE_TAP_DEMO

while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the package: $name"
  tanzu package installed delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package installed list -n $NAMESPACE_TAP -o json | jq -c '.[]')"

while read -r package; do
  name=$(echo $package | jq -r '.name')
  repo=$(echo $package | jq -r '.repository')
  tag=$(echo $package | jq -r '.tag')
  echo "Deleting the repository: $name"
  tanzu package repository delete $name -n $NAMESPACE_TAP -y
done <<< "$(tanzu package repository list -n $NAMESPACE_TAP -o json | jq -c '.[]')"

declare -a packages=("tap-install" "secretgen-controller" "tanzu-cluster-essentials"  "tanzu-package-repo-global" "kapp-controller")
for pkg in ${packages[@]}; do
   echo "Deleting the resources and namespace of: $pkg"
   echo "If the namespace cannot be deleted as some finalizers are still pending, execute this command"
   echo "kubectl get ns $pkg -o json | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" | kubectl replace --raw /api/v1/namespaces/$pkg/finalize -f -"
   kubectl delete "$(kubectl api-resources --namespaced=true --verbs=delete -o name | tr "\n" "," | sed -e 's/,$//')" --all -n $pkg
   kubectl delete ns $pkg
done

echo "## Clean previous installation of the Tanzu client"
rm -rf $TANZU_TEMP_DIR/cli    # Remove previously downloaded cli files
sudo rm /usr/local/bin/tanzu  # Remove CLI binary (executable)
rm -rf ~/.config/tanzu/       # current location # Remove config directory
rm -rf ~/.tanzu/              # old location # Remove config directory
rm -rf ~/.cache/tanzu         # remove cached catalog.yaml