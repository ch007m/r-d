## Platform

Tanzu Application Platform - https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/index.html is a solution designed to be deployed top of K8s. 

The problem they would like to solve is presented within this video: https://www.youtube.com/watch?v=9oupRtKT_JM

Short summary about what is TAP is available here: http://i-programmer.cloudapp.net/news/90-tools/9503-vmware-announces-tanzu-application-platform-.html

It packages different technology such as:

| Name | Description | System(s) | Version |
| --- | --- | --- | --- |
| [Tanzu Build Service](https://docs.pivotal.io/build-service/1-2/) | Service building Container images using buildpacks spec | kpack | 1.2.2 |
| [Cloud Native runtimes](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.1/tap-0-1/GUID-overview.html) | Serverless application runtime for Kubernetes that is based on Knative and runs on a single Kubernetes cluster | | 1.0.2 |
| [Application Live](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-index.html) |  lightweight insights and troubleshooting tool that helps application developers and application operators to look inside running applications. It is based on the concept of Spring Boot Actuators | AppLive controler/server | 0.1.0 |
| [Application Accelerator](https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html) | Controller reconciling accelerator CRD (= developer project definition) | accelerator, source controllers | 0.2.0 |
| [Flux2](https://github.com/fluxcd/flux2#flux-version-2) | Sync k8s resources and config up to date from Git repositories | Flux2 | 0.17.0 |
| [Kapp](https://carvel.dev/kapp-controller/)| Deploy and view groups of Kubernetes resources as "applications" controller | kapp | 0.39.0 |

## Prerequisites

The following tools are required to install App Accelerator: 

- `shasum` binary (for linux OS) using `yum install perl-Digest-SHA -y`
- Carvel [tools](https://carvel.dev/#whole-suite) - `curl -L https://carvel.dev/install.sh | sudo bash`
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

# or using containerd and crictl
export VMWARE_USERNAME="<VMWARE_USERNAME>"
export VMWARE_PASSWORD="<VMWARE_PASSWORD>"
sudo crictl pull --creds $VMWARE_USERNAME:$VMWARE_PASSWORD registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:0.1.0

# Macos installation
mkdir ~/temp/tanzu && cd ~/temp/tanzu
mv ~/Downloads/tanzu-cli-bundle-darwin-amd64.tar .
tar -vxf tanzu-cli-bundle-darwin-amd64.tar
cp core/v1.4.0-rc.5/tanzu-core-darwin_amd64 /usr/local/bin/tanzu

# Linux installation
# To auth the user, use the API legacy token which is available here : https://network.pivotal.io/users/dashboard/edit-profile
pivnet login --api-token=$LEGACY_API_TOKEN
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='0.1.0' --product-file-id=1030933
tar -vxf tanzu-cli-bundle-linux-amd64.tar
cp cli/package/v1.4.0-rc.5/tanzu-package-linux_amd64 $HOME/bin/tanzu

tanzu plugin clean
tanzu plugin install -v v1.4.0-rc.5 --local cli package
tanzu package version

alias kc=kubectl

kapp deploy -a flux -f https://github.com/fluxcd/flux2/releases/download/v0.17.0/install.yaml
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml

kc create ns tap-install
kc create secret docker-registry tap-registry -n tap-install --docker-server='registry.pivotal.io' --docker-username=$VMWARE_USERNAME --docker-password=$VMWARE_PWD

pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='0.1.0' --product-file-id=1029762
kapp deploy -a tap-package-repo -n tap-install -f ./tap-package-repo.yaml -y
# Macos installation
kapp deploy -a tap-package-repo -n tap-install -f ./files/tap-package-repo.yaml -y

tanzu package repository list -n tap-install
tanzu package available list -n tap-install
tanzu package available list cnrs.tanzu.vmware.com -n tap-install
tanzu package available get cnrs.tanzu.vmware.com/1.0.1 --values-schema -n tap-install

cat <<EOF > cnr.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD>"

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

tanzu package install cloud-native-runtimes -p cnrs.tanzu.vmware.com -v 1.0.1 -n tap-install -f ./cnr.yml

cat <<EOF > app-accelerator.yml
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD>"
server:
  # Set this service_type to "NodePort" for local clusters like minikube.
  service_type: "NodePort"
  watched_namespace: "default"
  engine_invocation_url: "http://acc-engine.accelerator-system.svc.cluster.local/invocations"
engine:
  service_type: "ClusterIP"
EOF

tanzu package install app-accelerator -p accelerator.apps.tanzu.vmware.com -v 0.2.0 -n tap-install -f ./app-accelerator.yml

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

kc apply -f ./sample-accelerators-0-2.yaml

cat <<EOF > app-live-view.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD"

EOF

tanzu package install app-live-view -p appliveview.tanzu.vmware.com -v 0.1.0 -n tap-install -f ./app-live-view.yml
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

### Additional tools

To download the VMWare products from the Network Pivotal web site, as wget/curl cannot be used, we must install the `pivnet` client.

```bash
wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
cp pivnet-linux-amd64-3.0.1 $HOME/bin/pivnet
chmod +x $HOME/bin/pivnet
```

As `shasum` binary is not installed by default on centos7, we must deploy it using the following perl package
as it will be used by `carvel`
```bash
sudo yum install perl-Digest-SHA -y
```

