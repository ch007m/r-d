## Platform

Tanzu Application Platform - https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html is a solution designed to be deployed top of K8s. It packages different technology such as:

| Name | Description | System(s) | Version |
| --- | --- | --- | --- |
| [Tanzu Build Service](https://docs.pivotal.io/build-service/1-2/) | Service building Container images using buildpacks spec | kpack | 1.2.2 |
| [Cloud Native runtimes](https://docs.vmware.com/en/Cloud-Native-Runtimes-for-VMware-Tanzu/index.html) | | | 1.0.2 |
| [Application Live](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/index.html) | | | 0.1.0 |
| [Application Accelerator](https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html) | Controller reconciling accelerator CRD (= developer project definition) | accelerator, source controllers | 0.2.0 |
| [Flux2](https://github.com/fluxcd/flux2#flux-version-2) | Sync k8s resources and config up to date from Git repositories | Flux2 | 0.17.0 |
| [Kapp](https://carvel.dev/kapp-controller/)| Deploy and view groups of Kubernetes resources as "applications" controller | kapp | 0.39.0 |

## Prerequisites

The following tools are required to install App Accelerator: 
- 
- Carvel [tools](https://carvel.dev/#whole-suite)
  - ytt version v0.34.0 or later.
  - kbld version v0.30.0 or later. 
  - imgpkg version v0.12.0 or later. 
  - kapp version v0.37.0 or later. 
- kubectl and Kubernetes v1.17 and later. 
- [Flux2](https://github.com/fluxcd/flux2#flux-version-2).

## Instructions

The commands listed hereafter have been executed top of a k8s 1.21 cluster created using `kind` according to the 
tanzu documentation guide.

The tanzu client version `0.1.0` has been downloaded from the tanzu product site - https://network.pivotal.io/products/tanzu-application-platform

```bash
docker login registry.tanzu.vmware.com -u cmoulliard@redhat.com
docker pull registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:0.1.0

kind-reg-ingress.sh
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
kapp deploy -a flux -f https://github.com/fluxcd/flux2/releases/download/v0.17.0/install.yaml

mkdir ~/temp/tanzu && cd ~/temp/tanzu
mv ~/Downloads/tanzu-cli-bundle-darwin-amd64.tar .
tar -vxf tanzu-cli-bundle-darwin-amd64.tar
cp core/v1.4.0-rc.5/tanzu-core-darwin_amd64 /usr/local/bin/tanzu

tanzu plugin clean
tanzu plugin install -v v1.4.0-rc.5 --local cli package
tanzu package version

kc create ns tap-install
kc create secret docker-registry tap-registry \\n-n tap-install \\n--docker-server='registry.pivotal.io' \\n--docker-username="cmoulliard@redhat.com" \\n--docker-password=".P?V9yM^e3vsVH9"

kapp deploy -a tap-package-repo -n tap-install -f ./files/tap-package-repo.yaml -y

tanzu package repository list -n tap-install
tanzu package available list -n tap-install
tanzu package available list cnrs.tanzu.vmware.com -n tap-install
tanzu package available get cnrs.tanzu.vmware.com/1.0.1 --values-schema -n tap-install

tanzu package install cloud-native-runtimes -p cnrs.tanzu.vmware.com -v 1.0.1 -n tap-install -f ./files/cnr.yml
tanzu package install app-accelerator -p accelerator.apps.tanzu.vmware.com -v 0.2.0 -n tap-install -f ./files/app-accelerator.yml
kc apply -f ./files/sample-accelerators-0-2.yaml
tanzu package install app-live-view -p appliveview.tanzu.vmware.com -v 0.1.0 -n tap-install -f ./files/app-live-view.yml
tanzu package installed list -n tap-install

tanzu package installed get cloud-native-runtimes -n tap-install
tanzu package installed update cloud-native-runtimes -p cnrs.tanzu.vmware.com -v 1.0.1 -n tap-install
```

### Clean

```bash
kc delete clusterrole/cloud-native-runtimes-tap-install-cluster-role
kc delete clusterrolebinding/cloud-native-runtimes-tap-install-cluster-rolebinding
kc delete sa/cloud-native-runtimes-tap-install-sa -n tap-install
kc delete -n tap-install secrets/cloud-native-runtimes-tap-install-values
```

