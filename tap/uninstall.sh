

declare -a packages=("app-accelerator" "app-live-view" "cloud-native-runtimes")
for pkg in ${packages[@]}; do
  tanzu package installed delete $pkg -n tap-install -y
done

declare -a packages=("flux" "tanzu-build-service" "kc")
for pkg in ${packages[@]}; do
  kapp delete -a $pkg
done