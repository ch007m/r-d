## How to play with it

### Locally

- See this [ticket](https://github.com/GoogleContainerTools/jib/issues/2106)
- Login in to quay.io
```bash
docker login -u="<USER>" -p="<PWD>" quay.io
```
- Instructions
```bash

git clone https://github.com/cmoulliard/hello-world-springboot.git && cd hello-world-springboot
mvn compile com.google.cloud.tools:jib-maven-plugin:2.0.0:build \
   -Djib.from.image=registry.redhat.io/redhat-openjdk-18/openjdk18-openshift \
   -Dimage=quay.io/<QUAY_ID>/<QUAY_REPO> \
   -Djib.from.auth.username=<RED_HAT_USERNAME> \
   -Djib.from.auth.password=<RED_HAT_PWD>
```

### Using Tekton and JIB

Before to use Tekton and JIB, be sure that the serviceaccount that it will use has been granted with the following
cluster role `registry-editor`. See [doc link](https://docs.openshift.com/container-platform/3.11/install_config/registry/accessing_registry.html#access-user-prerequisites)

- Create a secret to save your Red Hat username/password account
```bash
oc create secret generic rh-account --from-literal=RH_USERNAME=<RED_HAT_USERNAME> --from-literal=RH_PASSWORD=<RED_HAT_PWD>
secret/rh-account created
```

- To create the resources
```bash
oc new-project test
oc apply -f tekton/jib
```

- To clean up
```bash
oc delete task,taskrun,pipelineresource,sa,svc,route,role,rolebinding --all
```
