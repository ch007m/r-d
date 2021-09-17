Table of Contents
=================

   * [What is TAP](#what-is-tap)
   * [References](#references)
   * [Prerequisites](#prerequisites)
   * [Instructions](#instructions)
      * [Tanzu client and TAP repository](#tanzu-client-and-tap-repository)
      * [Install TAP - Cloud Native Runtimes](#install-tap---cloud-native-runtimes)
      * [Install TAP - Accelerator](#install-tap---accelerator)
      * [Install TAP - Review what it has been installed](#install-tap---review-what-it-has-been-installed)
      * [Install Tanzu Build Service (TBS)](#install-tanzu-build-service-tbs)
   * [Demo](#demo)
      * [Demo shortcuts](#demo-shortcuts)
   * [Additional tools](#additional-tools)
      * [Clean](#clean)
      
## What is TAP

Tanzu Application Platform - https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.1/tap-0-1/GUID-overview.html is a packaged set of components that helps developers and
operators to more easily build, deploy, and manage apps on a Kubernetes platform.

Short introduction about what is TAP is available [here](http://i-programmer.cloudapp.net/news/90-tools/9503-vmware-announces-tanzu-application-platform-.html) and could be summarized as such:

TAP is a `Knative` platform using `kpack` (= buildpacks controller) to build images, `Contour` (= ingress) to route the traffic, `kapp` (= kind of helm technology but with more features) to assemble the
`applications` and `Application Live and Application Accelerator`** to guide the Architects/Developers to design/deploy/monitor applications on k8s.

**: Where VMWare/Pivotal would like to capture with a great DevExp on K8s the Spring Architects and Developers.

Tanzu Application Platform simplifies workflows in both the `inner` loop and `outer` loop of Kubernetes-based app development:

- Inner Loop: The inner loop describes a developer’s local development environment where they code and test apps. The activities that take place in the inner loop include writing code, committing to a version control system, deploying to a development or staging environment, testing, and then making additional code changes.
- Outer Loop: The outer loop describes the steps to deploy apps to production and maintain them over time. For example, on a cloud-native platform, the outer loop includes activities such as building container images, adding container security, and configuring continuous integration (CI) and continuous delivery (CD) pipelines.

**REMARK**: The VMWare Tanzu definition of an inner loop implies an image build while this is not the case using Openshift odo as we push the code within a pod.

**NOTE**: The problem TAP `beta 0.1` would like to solve is presented within this [video](https://www.youtube.com/watch?v=9oupRtKT_JM)

It packages different technology such as:


| Name                                                                                                                 | Description                                                                                                                                                                                        | System(s)                       | Version |
| ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | --------- |
| [Tanzu Build Service](https://docs.pivotal.io/build-service/1-2/)                                                    | Service building Container images using buildpacks spec                                                                                                                                            | kpack                           | 1.2.2   |
| [Cloud Native runtimes](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.1/tap-0-1/GUID-overview.html) | Serverless application runtime for Kubernetes that is based on Knative and runs on a single Kubernetes cluster                                                                                     |                                 | 1.0.2   |
| [Application Live](https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-index.html)       | lightweight insights and troubleshooting tool that helps application developers and application operators to look inside running applications. It is based on the concept of Spring Boot Actuators | AppLive controler/server        | 0.1.0   |
| [Application Accelerator](https://docs.vmware.com/en/Application-Accelerator-for-VMware-Tanzu/index.html)            | Controller reconciling accelerator CRD (= developer project definition)                                                                                                                            | accelerator, source controllers | 0.2.0   |
| [Flux2](https://github.com/fluxcd/flux2#flux-version-2)                                                              | Sync k8s resources and config up to date from Git repositories                                                                                                                                     | Flux2                           | 0.17.0  |
| [Kapp](https://carvel.dev/kapp-controller/)                                                                          | Deploy and view groups of Kubernetes resources as "applications" controller                                                                                                                        | kapp                            | 0.39.0  |

## References

[Contour Ingres architecture](https://projectcontour.io/docs/v1.18.1/architecture/)

[Use an Ingress route with Contour](https://tanzu.vmware.com/developer/guides/kubernetes/service-routing-contour-to-ingress-and-beyond/)

[How to install Tanzu (Contour, Harbor, TBS) on kind](https://github.com/tanzu-japan/devsecops-demo)

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

The commands listed hereafter have been executed top of a `k8s 1.21` cluster and have been reviewed due to some issues discovered using the
[tanzu installation guide](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.1/tap-0-1/GUID-install.html).

### Tanzu client and TAP repository

To install/uninstall TAP on a k8s cluster, it is needed to install The Tanzu client that we can download from the `https://network.pivotal.io/products/` website
or using the tool `pivnet`.

- Download the Mac/Linux or Windows client from - https://network.pivotal.io/products/tanzu-application-platform

```bash
# Macos installation
mkdir ~/tanzu && cd ~/tanzu
mv ~/Downloads/tanzu-cli-bundle-darwin-amd64.tar .
tar -vxf tanzu-cli-bundle-darwin-amd64.tar
cp core/v1.4.0-rc.5/tanzu-core-darwin_amd64 /usr/local/bin/tanzu
```
- Or use the `pivnet` client tool
```bash
# To auth the user, use the API legacy token which is available here : https://network.pivotal.io/users/dashboard/edit-profile
pivnet login --api-token=$LEGACY_API_TOKEN
mkdir ~/tanzu && cd ~/tanzu
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='0.1.0' --product-file-id=1030933
tar -vxf tanzu-cli-bundle-linux-amd64.tar
cp cli/core/v1.4.0-rc.5/tanzu-core-linux_amd64 $HOME/bin/tanzu
```

- Next, configure the Tanzu client to install the plugin `package`. This extension will be used to download the resources from the Pivotal registry

```bash
tanzu plugin clean
tanzu plugin install -v v1.4.0-rc.5 --local cli package
✔  successfully installed package
tanzu package version
```

- Install the needed projects such as `flux2` and `kapp-controller` not installed by the Tanzu client

```bash
kapp deploy -a flux -f https://github.com/fluxcd/flux2/releases/download/v0.17.0/install.yaml
kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/latest/download/release.yml
```

- Create the `tap-install` namespace and the secret containing your pivotal registry credentials:

```bash
alias kc=kubectl
kc create ns tap-install

export VMWARE_USERNAME="<VMWARE_USERNAME>"
export VMWARE_PASSWORD="<VMWARE_PASSWORD>"
kc create secret docker-registry tap-registry -n tap-install --docker-server='registry.pivotal.io' --docker-username=$VMWARE_USERNAME --docker-password=$VMWARE_PASSWORD
```

- Download using `pivnet` client the `PackageRepository` CRD containing the reference of the image installing TAP `registry.pivotal.io/tanzu-application-platform/tap-packages:0.1.0` :

```bash
pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='0.1.0' --product-file-id=1029762
2021/09/14 15:26:39 Downloading 'tap-package-repo.yaml' to 'tap-package-repo.yaml'
...
```

- Deploy the CRD within the `tap-install` namespace using `kapp` and the application name `tap-package-repo`:

```bash
kapp deploy -a tap-package-repo -n tap-install -f ./tap-package-repo.yaml -y
```

- You can check what the repository contains like the packages you can install using the following commands:

```bash
tanzu package repository list -n tap-install
/ Retrieving repositories...
  NAME                  REPOSITORY                                                         STATUS               DETAILS
  tanzu-tap-repository  registry.pivotal.io/tanzu-application-platform/tap-packages:0.1.0  Reconcile succeeded

tanzu package available list -n tap-install
/ Retrieving available packages...
  NAME                               DISPLAY-NAME                              SHORT-DESCRIPTION
  accelerator.apps.tanzu.vmware.com  Application Accelerator for VMware Tanzu  Used to create new projects and configurations.
  appliveview.tanzu.vmware.com       Application Live View for VMware Tanzu    App for monitoring and troubleshooting running apps
  cnrs.tanzu.vmware.com              Cloud Native Runtimes                     Cloud Native Runtimes is a serverless runtime based on Knative
```

- To see the detail of the parameters of a package to be installed, execute the command:

```bash
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
```

### Install TAP - Cloud Native Runtimes

- In order to install the package `CNR = Cloud Native Runtimes`, we will create a yaml file containing the parameters such as the `creds` to access the registry, the provider, ...

  **WARNING**: If the k8s cluster that you will use do not run a LB, then configure the field `provider: local`

```bash
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
```

### Install TAP - Accelerator 

- When this is done, we will proceed to the deployment of the `Application accelerator` and create another config yaml file:

  **WARNING**: If the k8s cluster that you will use do not run a LB, then configure the field `service_type` to use `NodePort`

```bash
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
```

- Deploy the `app-accelerator` package:

```bash
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
```

- Next, install some sample accelerators (= Application templates) to feed the `Application Accelerator` dashboard :

```bash
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
```

- When done, install the `application live` package and configure it:

```bash
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
```

### Install TAP - Review what it has been installed

- Check the status of the 3 packages installed:

```bash
tanzu package installed list -n tap-install
\ Retrieving installed packages...
  NAME                   PACKAGE-NAME                       PACKAGE-VERSION  STATUS
  app-accelerator        accelerator.apps.tanzu.vmware.com  0.2.0            Reconcile succeeded
  app-live-view          appliveview.tanzu.vmware.com       0.1.0            Reconcile succeeded
  cloud-native-runtimes  cnrs.tanzu.vmware.com              1.0.1            Reconcile succeeded
  
# or individually
tanzu package installed get -n tap-install cloud-native-runtimes
tanzu package installed get -n tap-install app-live-view
tanzu package installed get -n tap-install app-accelerator
```

- To update a package if some errors are reported, use the following commands:

```bash
tanzu package installed update cloud-native-runtimes -v 1.0.1 -n tap-install -f cnr.yml
tanzu package installed update app-accelerator -v 0.2.0 -n tap-install -f app-accelerator.yml
tanzu package installed update app-live-view -v 0.1.0 -n tap-install -f app-live-view.yml
```

**WARNING**: Be sure that you have accepted the needed EULAs - https://network.tanzu.vmware.com/users/dashboard/eulas, otherwise some images will not be installed !

- Move now to the next section to install `Tanzu Build Services` as it is needed to build the image of the DEMO.

### Install Tanzu Build Service (TBS)

To install the `Tanzu Build Service` (aka [TBS](https://docs.pivotal.io/build-service/1-2/installing.html)) on your k8s cluster, execute the commands described hereafter.
The commands have been tested successfully against `docker.io`, `private docker registry` version 2.6 (as version 2.7 fails)

- Login in first to `registry.pivotal.io` and your public or private images registry (e.g. docker.io, ...).

```bash
export REG_USER="<REG_USER>"
export REG_PWD="<REG_PWD>"
docker login -u=$REG_USER -p=$REG_PWD docker.io

export PIVOTAL_REG_USER="<TANZUNET_USERNAME>"
export PIVOTAL_REG_PWD="<TANZUNET_PWD>"
docker login -u=$PIVOTAL_REG_USER -p=$PIVOTAL_REG_PWD registry.pivotal.io
```

- Copy the TBS images to your `<REGISTRY_USER>`/build-service

**REMARK**: When this demo has been performed, the TBS version used was `1.2.2`

**NOTE**: You can also use a private docker registry running on your k8s cluster. Use , in this case the version `2.6` as `2.7` reports `MANIFEST_BLOB_UNKNOWN` during imgpkg import !!

```bash
export IMAGE_REPOSITORY="<YOUR_IMAGE_REPOSITORY"
export TBS_VERSION="1.2.2"
imgpkg copy -b "registry.pivotal.io/build-service/bundle:$TBS_VERSION" --to-repo $IMAGE_REPOSITORY
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

**NOTe**: When you deploy to a private docker registry, then provide as additional the parameter the path to the CA certificate of the registry `--registry-ca-cert-path certs/ca.crt`

- Export the content of the images locally under the folder `./bundle`

```bash
imgpkg pull -b "$IMAGE_REPOSITORY:$TBS_VERSION" -o ./bundle
```

- Alternatively, we can export the content of the TAS image from the pivotal registry using the following command

```bash
imgpkg pull -b "registry.pivotal.io/build-service/bundle:$TBS_VERSION" -o ./bundle
```

- Deploy `TBS`

```bash
export IMAGE-REPOSITORY="quay.io/<REG_USER>/build-service" ## BUT SHOULD BE FOR DOCKER --> "docker.io/<REG_USER>"
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
- If you use a private docker registry, then execute this command
```bash
ytt -f ./bundle/values.yaml \
    -f ./bundle/config/ \
    -f <PATH-TO-CA> \
    -v docker_repository='<PRIVATE_IMAGE_REPOSITORY>' \
    -v docker_username='<PRIVATE_REGISTRY_USERNAME>' \
    -v docker_password='<PRIVATE_REGISTRY-PASSWORD>' \
    | kbld -f ./bundle/.imgpkg/images.yml -f- \
    | kapp deploy -a tanzu-build-service -f- -y
```
**NOTE**: The `<PRIVATE_IMAGE_REPOSITORY>` should include as latest char a `/` (e.g: `<IP_ADDRESS>:<PORT>/`). Otherwise the `.dockerconfigjson` file generated for the `canonical-registry-secret` will include
as registry `http//index.docker.io/v1/`

- Install the `kp` cli

```bash
pivnet download-product-files --product-slug='build-service' --release-version=$TBS_VERSION --product-file-id=1000629
chmod +x kp-linux-0.3.1
cp kp-linux-0.3.1 ~/bin/kp
```
- finally, import the `Tanzu Build Service` dependencies` such as: lifecycle, buildpacks (go, java, python, ..) using the dependency descriptor `descriptor-<version>.yaml` file
  that you can download using pivnet
```bash
pivnet download-product-files --product-slug='tbs-dependencies' --release-version='100.0.155' --product-file-id=1036685
2021/09/14 11:11:26 Downloading 'descriptor-100.0.155.yaml' to 'descriptor-100.0.155.yaml'
kp import -f ./descriptor-<version>.yaml

e.g: kp import -f ./descriptor-100.0.155.yaml
Importing Lifecycle...
	Uploading '95.217.159.244:32500/lifecycle@sha256:c923a81a1c3908122e29a30bae5886646d6ec26429bad4842c67103636041d93'
Importing ClusterStore 'default'...
	Uploading '95.217.159.244:32500/tanzu-buildpacks_go@sha256:9fd3ba0f1f99f7dba25d22dc955233c7b38b7f1b55b038464968d1f1e37afd3d'
	Uploading '95.217.159.244:32500/tanzu-buildpacks_java@sha256:578bccbfc996184ea3181b4b0fa39f98f456db1e2e427ef163db98224cd9ea04'
	Uploading '95.217.159.244:32500/tanzu-buildpacks_nodejs@sha256:c2b47f6f74055bade5456c17dd92c5ef035fab7e075d0ce0b14afc15b2efa06c'
	Uploading '95.217.159.244:32500/tanzu-buildpacks_java-native-image@sha256:74d8f4ba944ee1e62e7fc68654ee09fb89e0b26cb8eeda3a587322e9e7bd6bf5'
	Uploading '95.217.159.244:32500/tanzu-buildpacks_dotnet-core@sha256:6d57e312e7ac86f78ece4afcc3967e5314fbb71fe592800fd6f0f58bd923945a'
	Uploading '95.217.159.244:32500/tanzu-buildpacks_python@sha256:1222d5f695222597687173b1b8612844f3ccd763eae86e99c3ebacc41390db40'
	 \ 578.31 MB
...	
```

**WARNING**: This step to import the `buildpacks` will take time !

- When done, play with the [demo](#Demo) :-)

- To delete the `build-service` using kapp

```bash
kapp delete -a tanzu-build-service -n build-service
```

## Demo

- Access the `TAP Accelerator UI` at the following address `http://<VM_IP>:<NODEPORT_ACCELERATOR_SERVER>`
  ```bash
  UI_NODE_PORT=$(kc get svc/acc-ui-server -n accelerator-system -o jsonpath='{.spec.ports[0].nodePort}')
  VM_IP=<VM_IP>
  echo http://$VM_IP:$UI_NODE_PORT
  # Open the address displayed
  ```
- Download the `spring petclinic example` by clicking on the `Generate project` from the example selected using the UI (e.g. `http://95.217.159.244:31052/dashboard/accelerators/spring-petclinic`)
- scp the file to the VM (optional)
- Unzip the spring petclinic app
- Create a new github repo and push the code to this repo using your `GITHUB_USER` (e.g http://github.com/<GITHUB_USER>/spring-pet-clinic-eks)
- Create a secret containing your docker hub creds

```bash
kubectl create secret docker-registry docker-hub-registry \
    --docker-username="<dockerhub-username>" \
    --docker-password="<dockerhub-password>" \
    --docker-server=https://index.docker.io/v1/ \
    --namespace tap-install
```
**NOTE**: If you use a local private docker registry, change the parameters accordingly (e.g. docker_server=95.217.159.244:32500) !

- Create a `sa` using the secret containing your docker registry creds

```bash
cat <<EOF | kc apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tap-service-account
  namespace: tap-install
secrets:
- name: docker-hub-registry
imagePullSecrets:
- name: docker-hub-registry
EOF
```

- Create a `ClusterRole` and `ClusterRoleBinding` to give `admin` role to the `sa`

```bash
cat <<EOF | kc apply -f -
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

- Create a kpack `image` CRD resource to let `kpack` to perform a `buildpack` build. Change the tag name according to the name of the repository where the project
  image will be pushed (e.g: docker.io/my_user/spring-petclinic-eks)

```bash
export GITHUB_USER="<GITHUB_USER>"
export PETCLINIC_IMAGE_TAG="<PETCLINIC_IMAGE_TAG>"

cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: Image
metadata:
  name: spring-petclinic-image
  namespace: tap-install
spec:
  tag: $PETCLINIC_IMAGE_TAG
  serviceAccount: tap-service-account
  builder:
    kind: ClusterBuilder
    name: default
  source:
    git:
      url: https://github.com/$GITHUB_USER/spring-pet-clinic-eks
      revision: main
EOF
```
**NOTE**: To delete the application deployed, do `kc delete images.kpack.io/spring-petclinic-image -n tap-install`

- Check the status of the `build` and/or the `image`

```bash
kp image list -n tap-install
NAME                      READY      LATEST REASON    LATEST IMAGE    NAMESPACE
spring-petclinic-image    Unknown    CONFIG

kp build list -n tap-install
BUILD    STATUS      IMAGE    REASON
1        BUILDING             CONFIG
```

- If a problem occurs, then you can check the content of the build's log and/or build's pod

```bash
kp build logs spring-petclinic-image -n tap-install 
...
kc get build spring-petclinic-image-build-1-bj96l -n tap-install -o yaml
```

- After several minutes, image should be pushed to the registry

```bash
kp build list -n tap-install
BUILD    STATUS     IMAGE                                                                                                                      REASON
1        SUCCESS    95.217.159.244:32500/spring-petclinic-eks@sha256:49fa45da83c4a212b23a0dcd89e8fb731fe9891039824d6bd37f9fefb279a135    CONFIG

kp image list -n tap-install
NAME                      READY    LATEST REASON    LATEST IMAGE                                                                                                               NAMESPACE
spring-petclinic-image    True     CONFIG           95.217.159.244:32500/spring-petclinic-eks@sha256:49fa45da83c4a212b23a0dcd89e8fb731fe9891039824d6bd37f9fefb279a135    tap-install
```

**REMARK**: If you use a private docker registry, then pull the image `docker pull 95.217.159.244:32500/spring-petclinic-eks@sha256:49fa45da83c4a212b23a0dcd89e8fb731fe9891039824d6bd37f9fefb279a135` !

- Deploy the `image` generated in the namespace where `Application Live View` is running with the
  labels `tanzu.app.live.view=true` and `tanzu.app.live.view.application.name=<app_name>`.

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
                  - image: <DOCKER_IMAGE_BUILD>
                    securityContext:
                      runAsUser: 1000
  template:
    - ytt: {}
  deploy:
    - kapp: {}
EOF
```

- Wait till the pod is created

```bash
kubectl get pods -n tap-install -w
NAME                                                   READY   STATUS              RESTARTS   AGE
petclinic-00001-deployment-f59c968c6-bfpdt             0/2     ContainerCreating   0          28s
```

- Get its Knative service URL

```bash
kubectl get ksvc -n tap-install
NAME        URL                                        LATESTCREATED     LATESTREADY   READY     REASON
petclinic   http://petclinic.tap-install.example.com   petclinic-00001                 Unknown   RevisionMissing
```

- In order to route the traffic of the `URL` of the Knative service using port-forward, it is needed to find the `NodePort` of the `Contour External Envoy proxy`

```bash
nodePort=$(kc get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
kubectl port-forward -n contour-external svc/envoy $nodePort:80 &
```

- Next, access using curl the service

```bash
curl -v -H "HOST: petclinic.tap-install.example.com" http://petclinic.tap-install.example.com:$nodePort

Curl regularly the service to keep the service alive
watch -n 5 curl \"HOST: petclinic.tap-install.example.com\" http://petclinic.tap-install.example.com:$nodePort
```

- Configure locally (= on your laptop) your `/etc/hosts` to map the URL of the service to the IP address of the VM running the k8s cluster

```bash
VM_IP="<VM_IP"
cat <<EOF >> /etc/hosts
$VM_IP petclinic.tap-install.example.com
EOF
```
**REMARK**: This step is needed if you wouls like to use as domain `<VM_IP>.nip.io` as we must patch the Knative Serving config-domain configmap
```bash
kubectl patch cm/config-domain -n knative-serving --type merge -p '{"data":{"95.217.159.244.nip.io":""}}'
```

- Access the service using your browser `http://petclinic.tap-install.example.com:<nodePort>`
- To access the `Applicatin View` UI, get the `NodePort` of the svc and open the address in your browser
```bash
nodePort=$(kc get svc/application-live-view-5112 -n tap-install -o jsonpath='{.spec.ports[0].nodePort}')
echo http://$VM_IP:$nodePort/apps
```
- Enjoy !!

### Demo shortcuts

```bash
# Access remotely the kube cluster
export KUBECONFIG=$HOME/.kube/h01-121
export VM_IP=95.217.159.244

export UI_NODE_PORT=$(kc get svc/acc-ui-server -n accelerator-system -o jsonpath='{.spec.ports[0].nodePort}')
echo "Accelerator UI: http://$VM_IP:$UI_NODE_PORT"
open -na "Google Chrome" --args --incognito http://$VM_IP:$UI_NODE_PORT
open http://$VM_IP:$UI_NODE_PORT

export LIVE_NODE_PORT=$(kc get svc/application-live-view-5112 -n tap-install -o jsonpath='{.spec.ports[0].nodePort}')
echo "Live view: http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps"
open -na "Google Chrome" --args --incognito http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps

export ENVOY_NODE_PORT=$(kc get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
echo "Petclinic demo: http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT"
open -na "Google Chrome" --args --incognito http://petclinic.tap-install.$VM_IP.nip.io:$ENVOY_NODE_PORT
```

## Additional tools

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
pivnet download-product-files --product-slug='build-service' --release-version='`TBS_VERSION' --product-file-id=1000629
chmod +x kp-linux-0.3.1
cp kp-linux-0.3.1 ~/bin/kp
```

- As this is easier to use the `docker client tool` than `ctr, crictl, ..`, please install it on a `containerd` linux machine like `dockerd`

```bash
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum list installed | grep docker
sudo yum -y remove docker-ce.x86_64
sudo yum -y remove docker-ce-cli.x86_64
sudo yum -y remove containerd.io.x86_64

sudo yum install docker-ce docker-ce-client containerd
sudo systemctl enable docker
sudo systemctl start docker
sudo gpasswd -a snowdrop docker
sudo reboot
```

### Clean

TODO: To be reviewed and improved
```bash
kc delete clusterrole/cloud-native-runtimes-tap-install-cluster-role
kc delete clusterrolebinding/cloud-native-runtimes-tap-install-cluster-rolebinding
kc delete sa/cloud-native-runtimes-tap-install-sa -n tap-install
kc delete -n tap-install secrets/cloud-native-runtimes-tap-install-values

kc delete -n tap-install sa/app-accelerator-tap-install-sa
kc delete clusterrole/app-accelerator-tap-install-cluster-role
kc delete clusterrolebinding/app-accelerator-tap-install-cluster-rolebinding

# CNR
kapp delete -a cloud-native-runtimes -n cloud-native-runtimes
kubectl delete ns cloud-native-runtimes
```