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
- [Tanzu Build Service](#TAS)

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
cp cli/core/v1.4.0-rc.5/tanzu-core-linux_amd64 $HOME/bin/tanzu

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
| Retrieving package details for cnrs.tanzu.vmware.com/1.0.1...
  KEY                         DEFAULT  TYPE     DESCRIPTION
  ingress.reuse_crds          false    boolean  set true to reuse existing Contour instance
  ingress.external.namespace  <nil>    string   external namespace
  ingress.internal.namespace  <nil>    string   internal namespace
  local_dns.domain            <nil>    string   domain name
  local_dns.enable            false    boolean  specify true if local DNS needs to be enabled
  pdb.enable                  true     boolean  <nil>
  provider                    <nil>    string   Kubernetes cluster provider
  registry.password           <nil>    string   registry password
  registry.server             <nil>    string   registry server
  registry.username           <nil>    string   registry username

cat <<EOF > cnr.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD"

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
\ Installing package 'cnrs.tanzu.vmware.com'
| Getting namespace 'tap-install'
| Getting package metadata for 'cnrs.tanzu.vmware.com'
| Creating service account 'cloud-native-runtimes-tap-install-sa'
| Creating cluster admin role 'cloud-native-runtimes-tap-install-cluster-role'
| Creating cluster role binding 'cloud-native-runtimes-tap-install-cluster-rolebinding'
| Creating secret 'cloud-native-runtimes-tap-install-values'
- Creating package resource
- Package install status: Reconciling
...
Added installed package 'cloud-native-runtimes' in namespace 'tap-install'
 
cat <<EOF > app-accelerator.yml
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD"
server:
  # Set this service_type to "NodePort" for local clusters like minikube.
  service_type: "NodePort"
  watched_namespace: "default"
  engine_invocation_url: "http://acc-engine.accelerator-system.svc.cluster.local/invocations"
engine:
  service_type: "ClusterIP"
EOF

tanzu package install app-accelerator -p accelerator.apps.tanzu.vmware.com -v 0.2.0 -n tap-install -f app-accelerator.yml
- Installing package 'accelerator.apps.tanzu.vmware.com'
| Getting namespace 'tap-install'
| Getting package metadata for 'accelerator.apps.tanzu.vmware.com'
| Creating service account 'app-accelerator-tap-install-sa'
| Creating cluster admin role 'app-accelerator-tap-install-cluster-role'
| Creating cluster role binding 'app-accelerator-tap-install-cluster-rolebinding'
| Creating secret 'app-accelerator-tap-install-values'
- Creating package resource
/ Package install status: Reconciling
...


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
accelerator.accelerator.apps.tanzu.vmware.com/hello-fun created
accelerator.accelerator.apps.tanzu.vmware.com/hello-ytt created
accelerator.accelerator.apps.tanzu.vmware.com/spring-petclinic created
accelerator.accelerator.apps.tanzu.vmware.com/spring-sql-jpa created
accelerator.accelerator.apps.tanzu.vmware.com/node-accelerator created

cat <<EOF > app-live-view.yml
---
registry:
  server: "registry.pivotal.io"
  username: "$VMWARE_USERNAME"
  password: "$VMWARE_PASSWORD"

EOF

tanzu package install app-live-view -p appliveview.tanzu.vmware.com -v 0.1.0 -n tap-install -f ./app-live-view.yml
\ Installing package 'appliveview.tanzu.vmware.com'
| Getting namespace 'tap-install'
| Getting package metadata for 'appliveview.tanzu.vmware.com'
| Creating service account 'app-live-view-tap-install-sa'
| Creating cluster admin role 'app-live-view-tap-install-cluster-role'
| Creating cluster role binding 'app-live-view-tap-install-cluster-rolebinding'
| Creating secret 'app-live-view-tap-install-values'
- Creating package resource
/ Package install status: Reconciling

# To check the packages installed
tanzu package installed list -n tap-install

# To check the status of each package
tanzu package installed get -n tap-install cloud-native-runtimes
tanzu package installed get -n tap-install app-live-view
tanzu package installed get -n tap-install app-accelerator

# To update a package if some errors are reported
tanzu package installed update cloud-native-runtimes -v 1.0.1 -n tap-install -f cnr.yml
tanzu package installed update app-accelerator -v 0.2.0 -n tap-install -f app-accelerator.yml
tanzu package installed update app-live-view -v 0.1.0 -n tap-install -f app-live-view.yml
```
As the documentation is missing the steps to install `kpacck`, then follow my instructions.
**REMARK**: Be sure that you have accepted the needed EULAs - https://network.tanzu.vmware.com/users/dashboard/eulas

```bash
# Install kp client
pivnet download-product-files --product-slug='build-service' --release-version='1.2.2' --product-file-id=1000629
chmod +x kp-linux-0.3.1
cp kp-linux-0.3.1 ~/bin/kp
# download the list of the images to be installed 
pivnet download-product-files --product-slug='tbs-dependencies' --release-version='100.0.155' --product-file-id=1036685
```

## Testing

- Access the UI
- Download the spring petclinic example by clicking on the `Generate project`
- scp the file to the VM
- unzip the spring petclinic app
- Create a new github repo and pushthe code to this repo
- Create a sa/clusterrole/clusterrolebinding to be used to build the image
```bash
cat <<EOF | kc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tap-service-account
  namespace: tap-install
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-cluster-role
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["*"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-cluster-role-binding
subjects:
- kind: ServiceAccount
  name: tap-service-account
  namespace: tap-install
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin-cluster-role
EOF
```
- Patch the SA created to set the `imagePullSecrets`
```bash
kubectl patch serviceaccount tap-service-account -p "{\"imagePullSecrets\": [{\"name\": \"tap-registry\"}]}" -n tap-install
serviceaccount/tap-service-account patched
```
- Create an `image` kubernetes resource to let `Kpack` to perform a buildpacks build
```bash
export GITHUB_USER="<GITHUB_USER>"
cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: Image
metadata:
  name: spring-petclinic-image
  namespace: tap-install
spec:
  tag: dev.registry.pivotal.io/tanzu-advanced-edition/vdesikan/spring-petclinic-eks
  serviceAccount: default
  builder:
    kind: ClusterBuilder
    name: default
  source:
    git:
      url: https://github.com/$GITHUB_USER/spring-pet-clinic-eks
      revision: main
EOF
```
- Deploy the image you generated as a service with Cloud Native Runtimes. Deploy the image in the namespace where Application Live View is running with the labels tanzu.app.live.view=true and tanzu.app.live.view.application.name=<app_name>. Add the appropriate DNS entries using /etc/hosts.
  tap-install % more kapp-deploy-spring-petclinic.yaml
```bash
cat <<EOF | kubectl apply -f - 
apiVersion: kappctrl.k14s.io/v1alpha1
kind: App
metadata:
  name: spring-petclinic
  namespace: tap-install
spec:
  serviceAccountName: tap-service-account
  fetch:
    - inline:
        paths:
          manifest.yml: |
            ---
            apiVersion: kapp.k14s.io/v1alpha1
            kind: Config
            rebaseRules:
              - path: [metadata, annotations, serving.knative.dev/creator]
                type: copy
                sources: [new, existing]
                resourceMatchers: &matchers
                  - apiVersionKindMatcher: {apiVersion: serving.knative.dev/v1, kind: Service}
              - path: [metadata, annotations, serving.knative.dev/lastModifier]
                type: copy
                sources: [new, existing]
                resourceMatchers: *matchers
            ---
            apiVersion: serving.knative.dev/v1
            kind: Service
            metadata:
              name: petclinic
            spec:
              template:
                metadata:
                  annotations:
                    client.knative.dev/user-image: ""
                  labels:
                    tanzu.app.live.view: "true"
                    tanzu.app.live.view.application.name: "spring-petclinic"
                spec:
                  containers:
                  - image: dev.registry.pivotal.io/tanzu-advanced-edition/vdesikan/spring-petclinic-eks@sha256:be889cf313016eb4fc168556493c2b1672c8e2af725e33696bf461b8212f9872
                    securityContext:
                      runAsUser: 1000
  template:
    - ytt: {}
  deploy:
    - kapp: {}
EOF
```  

## TAS

- As this is easier to use the `docker client tool`, than `ctr, ctictl, ..` we will install it
```bash
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install docker-ce-cli
```
- Login in to `registry.pivotal.io` and your public registry (e.g. quay.io)
```bash
export REG_USER="<REG_USER>"
export REG_PWD="<REG_PWD>"
docker login -u=$REG_USER -p=$REG_PWD quay.io

export PIVOTAL_REG_USER="<TANZUNET_USERNAME>"
export PIVOTAL_REG_PWD="<TANZUNET_PWD>"
docker login -u=$PIVOTAL_REG_USER -p=$PIVOTAL_REG_PWD registry.pivotal.io
```
- Copy the TAS image to your `<REGISTRY>`/build-service
```bash
export IMAGE_REPOSITORY="<YOUR_IMAGE_REPOSITORY"
imgpkg copy -b "registry.pivotal.io/build-service/bundle:1.2.2" --to-repo $IMAGE_REPOSITORY
copy | exporting 17 images...
copy | will export registry.pivotal.io/build-service/bundle@sha256:e03765dbce254a1266a8bba026a71ec908854681bd12bf69cd7d55d407bbca95
copy | will export registry.pivotal.io/build-service/dependency-updater@sha256:9f71c2fa6f7779924a95d9bcdedc248b4623c4d446ecddf950a21117e1cebd76
copy | will export registry.pivotal.io/build-service/kpack-build-init-windows@sha256:20758ba22ead903aa4aacaa08a3f89dce0586f938a5d091e6c37bf5b13d632f3
copy | will export registry.pivotal.io/build-service/kpack-build-init@sha256:31e95adee6d59ac46f5f2ec48208cbd154db0f4f8e6c1de1b8edf0cd9418bba8
copy | will export registry.pivotal.io/build-service/kpack-completion-windows@sha256:1f8f1d98ea439ba6a25808a29af33259ad926a7054ad8f4b1aea91abf8a8b141
copy | will export registry.pivotal.io/build-service/kpack-completion@sha256:1c63b9c876b11b7bf5f83095136b690fc07860c80b62a167c41b4c3efd1910bd
copy | will export registry.pivotal.io/build-service/kpack-controller@sha256:4b3c825d6fb656f137706738058aab59051d753312e75404fc5cdaf49c352867
copy | will export registry.pivotal.io/build-service/kpack-lifecycle@sha256:c923a81a1c3908122e29a30bae5886646d6ec26429bad4842c67103636041d93
copy | will export registry.pivotal.io/build-service/kpack-rebase@sha256:79ae0f103bb39d7ef498202d950391c6ef656e06f937b4be4ec2abb6a37ad40a
copy | will export registry.pivotal.io/build-service/kpack-webhook@sha256:594fe3525a8bc35f99280e31ebc38a3f1f8e02e0c961c35d27b6397c2ad8fa68
copy | will export registry.pivotal.io/build-service/pod-webhook@sha256:3d8b31e5fba451bb51ccd586b23c439e0cab293007748c546ce79f698968dab8
copy | will export registry.pivotal.io/build-service/secret-syncer@sha256:77aecf06753ddca717f63e0a6c8b8602381fef7699856fa4741617b965098d57
copy | will export registry.pivotal.io/build-service/setup-ca-certs@sha256:3f8342b534e3e308188c3d0683c02c941c407a1ddacb086425499ed9cf0888e9
copy | will export registry.pivotal.io/build-service/sleeper@sha256:0881284ec39f0b0e00c0cfd2551762f14e43580085dce9d0530717c704ade988
copy | will export registry.pivotal.io/build-service/smart-warmer@sha256:4c8627a7f23d84fc25b409b7864930d27acc6454e3cdaa5e3917b5f252ff65ad
copy | will export registry.pivotal.io/build-service/stackify@sha256:a40af2d5d569ea8bee8ec1effc43ba0ddf707959b63e7c85587af31f49c4157f
copy | will export registry.pivotal.io/build-service/stacks-operator@sha256:1daa693bd09a1fcae7a2f82859115dc1688823330464e5b47d8b9b709dee89f1
copy | exported 17 images
copy | importing 17 images...
```
- Export the content of the image locally
```bash
imgpkg pull -b "$IMAGE_REPOSITORY:1.2.2" -o ./bundle
```
- Alternatively, we can export the content of the TAS image from the pivotal registry using the following command
```bash
imgpkg pull -b "registry.pivotal.io/build-service/bundle:1.2.2" -o ./bundle
```
**REMARK**: Currently discussed in order to figure out why we don't use directly the images from the pivotal registry

- Deploy TAS
```bash
ytt -f ./bundle/values.yaml \
    -f ./bundle/config/ \
    -v docker_repository='<IMAGE-REPOSITORY>' \
    -v docker_username='<REGISTRY-USERNAME>' \
    -v docker_password='<REGISTRY-PASSWORD>' \
    -v tanzunet_username='<TANZUNET_USERNAME>' \
    -v tanzunet_password='<TANZUNET_PASSWORD>' \
    | kbld -f ./bundle/.imgpkg/images.yml -f- \
    | kapp deploy -a tanzu-build-service -f- -y
```

- Import Tanzu Build Service Dependencies using the `kp` cli and the Dependency Descriptor `descriptor-<version>.yaml` file
```bash
kp import -f ./descriptor-<version>.yaml

e.g: kp import -f ./descriptor-100.0.155.yaml
```

### Clean

```bash
kc delete clusterrole/cloud-native-runtimes-tap-install-cluster-role
kc delete clusterrolebinding/cloud-native-runtimes-tap-install-cluster-rolebinding
kc delete sa/cloud-native-runtimes-tap-install-sa -n tap-install
kc delete -n tap-install secrets/cloud-native-runtimes-tap-install-values

kc delete -n tap-install sa/app-accelerator-tap-install-sa
kc delete clusterrole/app-accelerator-tap-install-cluster-role
kc delete clusterrolebinding/app-accelerator-tap-install-cluster-rolebinding
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

If you plan to use kpack, then install the `kp` client
```bash
pivnet download-product-files --product-slug='build-service' --release-version='1.2.2' --product-file-id=1000629
chmod +x kp-linux-0.3.1
cp kp-linux-0.3.1 ~/bin/kp
```
