
KUBE_CFG_FILE=${1:-h01-121}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

kubectl delete secret tap-registry -n tap-install

declare -a packages=("app-accelerator" "app-live-view" "cloud-native-runtimes")
for pkg in ${packages[@]}; do
  echo "### DELETING A TANZU PACKAGE####"
  echo "tanzu package installed delete $pkg -n tap-install -y"
  tanzu package installed delete $pkg -n tap-install -y
done

declare -a packages=("tap-service-account" "tanzu-build-service" "tap-package-repo" "flux" "kc")
for pkg in ${packages[@]}; do
  echo "### DELETING ####"
  echo "kapp delete -a $pkg -y"
  kapp delete -a $pkg -y
done

kubectl delete ns tap-install