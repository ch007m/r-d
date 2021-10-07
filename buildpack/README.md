## Table of Contents

   * [Table of Contents](#table-of-contents)
   * [How to build a runtime using buildpack](#how-to-build-a-runtime-using-buildpack)
   * [0. Common steps](#0-common-steps)
   * [1. Pack client](#1-pack-client)
   * [2. Pod running the lifecycle creator](#2-pod-running-the-lifecycle-creator)
   * [3. kpack with a local docker registry](#3-kpack-with-a-local-docker-registry)
      * [Kpack controller](#kpack-controller)
      * [Deploy the runtime resources](#deploy-the-runtime-resources)
      * [Build an image](#build-an-image)
      * [Deploy the quarkus application](#deploy-the-quarkus-application)
   * [5. Tanzu Build Service (TBS) aka kpack](#5-tanzu-build-service-tbs-aka-kpack)


## How to build a runtime using buildpack

The goal of this project is to test/experiment different approach to build a runtime using:

- [pack] build client()
- [pod] build
- Tekton
- Shipwright

## 0. Common steps

To play with the different scenarios, a sample [runtime](https://github.com/snowdrop/quarkus-tap-petclinic/tree/main) project is available and can be cloned
```bash
git clone https://github.com/snowdrop/quarkus-tap-petclinic.git quarkus-petclinic && cd quarkus-petclinic
```

To use the builder image (packaging the `build` and `run` stacks) able to build a Quarkus project, then it is needed to use the `quarkus-buildpacks` project.
```bash
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks

# Generate the buildpack quarkus images (build, run and builder)
./create-buildpacks.sh
```

**NOTE**: If you plan to use a private container registry, then the images generated should be tagged/pushed to the registry (e.g. `local.registry:5000`)

```bash
# Tag and push the images to the private docker registry
export REGISTRY_HOST="registry.local:5000"
docker tag redhat/buildpacks-builder-quarkus-jvm:latest ${REGISTRY_HOST}/redhat-builder/quarkus:latest
docker tag redhat/buildpacks-stack-quarkus-run:jvm ${REGISTRY_HOST}/redhat-buildpacks/quarkus:run
docker tag redhat/buildpacks-stack-quarkus-build:jvm ${REGISTRY_HOST}/redhat-buildpacks/quarkus:build

docker push ${REGISTRY_HOST}/redhat-builder/quarkus:latest
docker push ${REGISTRY_HOST}/redhat-buildpacks/quarkus:build
docker push ${REGISTRY_HOST}/redhat-buildpacks/quarkus:run
```
You can create a kubernetes cluster locally using `docker desktop` and [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) client and the following script
able to run a k8s cluster, a TLS/secured registry

```bash
git clone https://github.com/snowdrop/k8s-infra.git && cd k8s-infra/kind
./k8s/kind-tls-secured-reg.sh
```
**NOTE**: The certificate generated is copied within the file `$HOME/local-registry.crt` and the user, password to be used to be authenticated with the registry are respectively` admin` and `snwodrop`

## 1. Pack client 

The easiest way to build a `runtime` sample is to use the [pack client](https://buildpacks.io/docs/tools/pack/) with the builder runtime image

**NOTE**: The command should be executed within the sample runtime project or path should be calculated to point to the runtime sample project

```bash
REGISTRY_HOST="registry.local:5000"
pack build ${REGISTRY_HOST}/quarkus-petclinic \
     --path ./ \
     --builder ${REGISTRY_HOST}/buildpacks-builder-quarkus-jvm
```

If you plan to use a different version of the lifecycle, append then the following parameter with the image: 
```bash
    --lifecycle-image buildpacksio/lifecycle:919b8ad-linux-arm64
```

## 2. Pod running the lifecycle creator

First, create a configMap containing the selfsigned certificate of the docker registry under the namespace `demo`
```bash
kubectl create ns demo
kc create -n demo cm local-registry-cert --from-file $HOME/local-registry.crt
```

Create a secret containing the `docker json cfg` file with `auths`
```bash
export REGISTRY_HOST="registry.local:5000"
kubectl create secret docker-registry registry-creds -n demo \
  --docker-server="${REGISTRY_HOST}" \
  --docker-username="admin" \
  --docker-password="snowdrop"
```
Next deploy the deployment resource able to perform a build using a runtime example (e.g. )
```bash
kubectl apply -f k8s/build-pod/manifest.yml
kubectl delete -f k8s/build-pod/manifest.yml
```
Watch the progression of the build 
```bash
kubectl -n demo logs -lapp=quarkus-petclinic-image-build -c build -f
```

## 3. kpack with a local docker registry

Install kind and a private secured/TLS registry locally (using registry version 2.6 !)
```bash
git clone kind-tls-pwd-registry https://github.com/snowdrop/k8s-infra.git && cd k8s-infra/kind
./k8s/kind-tls-secured-reg.sh
```
**NOTE**: The certificate generated is copied within the file `$HOME/local-registry.crt` and the user, password to be used to be authenticated with the registry are respectively` admin` and `snwodrop`

Build the quarkus buildpack images using the upstream project and push the images to the local registry: `local.registry:5000`
```bash
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks

# Generate the buildpack quarkus images (build, run and builder)
./create-buildpacks.sh

# Tag and push the images to the private docker registry
export REGISTRY_HOST="registry.local:5000"
docker tag redhat/buildpacks-builder-quarkus-jvm:latest ${REGISTRY_HOST}/redhat-buildpacks/quarkus-java:latest
docker tag redhat/buildpacks-stack-quarkus-run:jvm ${REGISTRY_HOST}/redhat-buildpacks/quarkus:run
docker tag redhat/buildpacks-stack-quarkus-build:jvm ${REGISTRY_HOST}/redhat-buildpacks/quarkus:build

docker push ${REGISTRY_HOST}/redhat-buildpacks/quarkus-java:latest
docker push ${REGISTRY_HOST}/redhat-buildpacks/quarkus:build
docker push ${REGISTRY_HOST}/redhat-buildpacks/quarkus:run
```

### Kpack controller

To be able to use the upstream [kpack](https://github.com/pivotal/kpack) project with a TLS secured registry, it is needed to install a webhook on kubernetes
able to inject the `selfsigned certificate` of the registry.

This is why it is needed to execute the following commands described hereafter to: 
- Build the images needed (to run a webhook, inject the certificate),
- Generate the k8s manifest yaml file deploying the webhook,
- To configure the webhook to fetch pod having a specific label (e.g. `image.kpack.io/image`),
- To be able to inject in a pod an `initContainer` which will, from a secret, deploy the certificate using `/usr/sbin/update-ca-certificates`, 

**NOTE**: Please use the `paketobuildpacks/builder:base` ad the default builder which is `tiny` do not include the command `/usr/sbin/update-ca-certificates` - see [ticket](https://github.com/vmware-tanzu/cert-injection-webhook/issues/9)!
```bash
git clone -b support-private-docker-registry https://github.com/ch007m/cert-injection-webhook.git && cd cert-injection-webhook
REGISTRY_HOST="registry.local:5000"
pack build ${REGISTRY_HOST}/setup-ca-cert -e BP_GO_TARGETS="./cmd/setup-ca-certs" -B paketobuildpacks/builder:base
pack build ${REGISTRY_HOST}/pod-webhook -e BP_GO_TARGETS="./cmd/pod-webhook"
docker push ${REGISTRY_HOST}/setup-ca-cert
docker push ${REGISTRY_HOST}/pod-webhook
  
LABELS="image.kpack.io/image"
ytt   -f ./deployments/k8s \
      -v pod_webhook_image="${REGISTRY_HOST}/pod-webhook" \
      -v setup_ca_certs_image="${REGISTRY_HOST}/setup-ca-cert" \
      -v docker_server="${REGISTRY_HOST}/" \
      -v docker_username="admin" \
      -v docker_password="snowdrop" \
      --data-value-file ca_cert_data=$HOME/local-registry.crt \
      --data-value-yaml labels="[${LABELS}]" \
      > manifest.yaml

kapp deploy -a inject-cert-webhook -f manifest.yaml -y
kapp delete -a inject-cert-webhook -y
```
**NOTE**: The label `image.kpack.io/image` allows to inject the cert within all the pods which are created to build an image using kpack and buildpack builders.

Next, we can deploy kpack using ytt and overlay files. They have been created part of this project to patch the upstream release.yaml file in order the issues reported [issue-845](https://github.com/pivotal/kpack/issues/845) and [issue-844](https://github.com/pivotal/kpack/issues/844).
They will allow to inject the registry selfsigned certificate and to let the kpack controller to be logged with the registry using the mounted `.dockercfgjson` file

```bash
ytt -f ./k8s/kpack-upstream/values.yaml \
    -f ./k8s/kpack-upstream/config/ \
    -f $HOME/local-registry.crt \
    -v docker_repository="${REGISTRY_HOST}/" \
    -v docker_username="admin" \
    -v docker_password="snowdrop" \
    | kapp deploy -a kpack -f- -y

kapp delete -a kpack
```

### Deploy the runtime resources
Create a secret to access your local registry
```bash
kubectl create ns demo
kubectl create secret docker-registry registry-creds -n demo \
  --docker-server="https://${REGISTRY_HOST}" \
  --docker-username="admin" \
  --docker-password="snowdrop"
  
kubectl delete -n demo secret/registry-creds  
```

Deploy the kpack runtime CRs (Store, Builder and Stack)
```bash
kapp deploy -a runtime-kpack \
  -f k8s/runtime-kpack/sa.yml \
  -f k8s/runtime-kpack/clusterstore.yml \
  -f k8s/runtime-kpack/clusterbuilder.yml \
  -f k8s/runtime-kpack/clusterstack.yml -y

kapp delete -a runtime-kpack -y
```

### Build an image
To build a quarkus buildpack image using the code of the local project
```bash
# To be executed at the root of the project ;-)
kp image create quarkus-petclinic-image \
  --tag registry.local:5000/quarkus-petclinic \
  --local-path ./ \
  -c runtime \
  -n demo \
  --registry-ca-cert-path $HOME/local-registry.crt
```
To list the image and status
```bash
kp image list -n demo
kp image status quarkus-petclinic-image -n demo
```
To delete the image/build
```bash
kp image delete quarkus-petclinic-image -n demo
```

### Deploy the quarkus application
We can now deploy the application
```bash
kapp deploy -a quarkus-petclinic \
  -n demo \
  -f ./k8s/service.yml \
  -f ./k8s/deployment.yml

kapp delete -a quarkus-petclinic -n -y
```
and play with it from the browser `http://localhost:31000` :-)

## 5. Tanzu Build Service (TBS) aka kpack

If you prefer to use Tanzu Build Service and not kpack, then follow the steps described hereafter

Fetch the TBS images and push them to your local registry
```bash
imgpkg copy -b "registry.pivotal.io/build-service/bundle:1.2.2" --to-repo registry.local:5000/kpack --registry-ca-cert-path $HOME/local-registry.crt
```
Extract the files to configure TBS to use your local registry
```bash
imgpkg pull -b "registry.local:5000/kpack:1.2.2" -o ./k8s/kpack --registry-ca-cert-path $HOME/local-registry.crt
```
Deploy TBS using your custom config
```bash
ytt -f ./k8s/kpack/values.yaml \
    -f ./k8s/kpack/config/ \
    -f $HOME/local-registry.crt \
    -v docker_repository="registry.local:5000/" \
    -v docker_username="admin" \
    -v docker_password="snowdrop" \
    | kbld -f ./k8s/kpack/.imgpkg/images.yml -f- \
    | kapp deploy -a kpack -f- -y

kapp delete -a kpack
```