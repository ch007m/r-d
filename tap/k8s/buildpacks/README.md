## Steps executed to install our buildpacks

```
git clone https://github.com/quarkusio/quarkus-buildpacks.git && cd quarkus-buildpacks./create-buildpacks.sh
docker tag redhat/buildpacks-builder-quarkus-jvm:latest 95.217.159.244:32500/redhat-buildpacks/quarkus-java:latest
docker tag redhat/buildpacks-stack-quarkus-run:jvm 95.217.159.244:32500/redhat-buildpacks/quarkus:run
docker tag redhat/buildpacks-stack-quarkus-build:jvm 95.217.159.244:32500/redhat-buildpacks/quarkus:build

docker push 95.217.159.244:32500/redhat-buildpacks/quarkus-java:latest
docker push 95.217.159.244:32500/redhat-buildpacks/quarkus:build
docker push 95.217.159.244:32500/redhat-buildpacks/quarkus:run

kc delete -f buildpacks/runtime-clusterstore.yml -f buildpacks/runtime-clusterstack.yml -f buildpacks/runtime-clusterbuilder.yml
kc apply -f buildpacks/runtime-clusterstore.yml -f buildpacks/runtime-clusterstack.yml -f buildpacks/runtime-clusterbuilder.yml
```

## Deploy the Quarkus Application and build it

```
kc delete -f buildpacks/runtime-kpack-image.yml
kc apply -f buildpacks/runtime-kpack-image.yml
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
