
KUBE_CFG_FILE=${1:-h01-121}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

kubectl delete secret tap-registry -n tap-install

declare -a packages=("app-accelerator" "app-live-view" "cloud-native-runtimes")
for pkg in ${packages[@]}; do
  echo "### DELETING A TANZU PACKAGE####"
  echo "tanzu package installed delete $pkg -n tap-install -y"
  tanzu package installed delete $pkg -n tap-install -y
done

# Trick to fix the issue which blocks to delete kc
kubectl patch crd/apps.kappctrl.k14s.io -p '{"metadata":{"finalizers":null}}' --type=merge

declare -a packages=("flux" "tanzu-build-service" "kc")
for pkg in ${packages[@]}; do
  echo "### DELETING ####"
  echo "kapp delete -a $pkg -y"
  kapp delete -a $pkg -y
done