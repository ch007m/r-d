## Steps executed to install our buildpacks

```bash
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks

# Generate the buildpacks image (pack ...)
./create-buildpacks.sh

# Tag and push the images to a private docker registry
export REGISTRY_URL="95.217.159.244:32500"
docker tag redhat/buildpacks-builder-quarkus-jvm:latest $REGISTRY_URL/redhat-buildpacks/quarkus-java:latest
docker tag redhat/buildpacks-stack-quarkus-run:jvm $REGISTRY_URL/redhat-buildpacks/quarkus:run
docker tag redhat/buildpacks-stack-quarkus-build:jvm $REGISTRY_URL/redhat-buildpacks/quarkus:build

docker push $REGISTRY_URL/redhat-buildpacks/quarkus-java:latest
docker push $REGISTRY_URL/redhat-buildpacks/quarkus:build
docker push $REGISTRY_URL/redhat-buildpacks/quarkus:run

# Create the clusterStore, ClusterBuilder and ClusterStack CR
kapp deploy -a runtime-buildpacks \
  -f buildpacks/runtime-clusterstore.yml \
  -f buildpacks/runtime-clusterstack.yml \
  -f buildpacks/runtime-clusterbuilder.yml

# To delete
kapp delete -a runtime-buildpacks
```

## Build the Quarkus application

```bash
kc delete -f buildpacks/runtime-kpack-image.yml
kc apply -f buildpacks/runtime-kpack-image.yml

# Check build status
kc get build.kpack.io -l image.kpack.io/image=quarkus-petclinic-image -n tap-install  
NAME                                    IMAGE                                                                                                            SUCCEEDED
quarkus-petclinic-image-build-1-7lkg4   95.217.159.244:32500/quarkus-petclinic@sha256:d7a49934e988e7c281b5de52b6b227a1926f4238c90b3a01ab654c7f554a82bd   True
```
## Deploy the Quarkus Application

```bash
kapp delete -a quarkus-petclinic
kapp deploy -a quarkus-petclinic -f buildpacks/quarkus-kapp.yml
```

## Trick to allow a quarkus application to work with Application Live View

Actually, this is already sort of possible via plugins that app live view allows to create. Essentially you’d need a new “app-flavour” for quarkus,
The label on such app needs to `tanzu.app.live.view.application.flavours: quarkus`.
You’d need to follow **[Extensibility](https://https://docs.vmware.com/en/Application-Live-View-for-VMware-Tanzu/0.1/docs/GUID-extensibility.html)** doc to create a UI plugin.

```
The backend endpoint would be:
/instance/{id}/actuator/**
(i.e. /instance/abc-id/actuator/app-memory)
```

Now if apps actuator path is configured with label: `tanzu.app.live.view.application.actuator.path: quarkus`
instead of the default which is actuator on the app you’d be hitting endpoint /`quarkus/app-memory` the response json
for which you should be able to handle in your UI plugin.
