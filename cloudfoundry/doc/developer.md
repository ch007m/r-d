## Cloud Foundry on Kubernetes

## Table of Contents

  * [Prerequisites](#prerequisites)
  * [Set up Cloudfoundry using cf-for-k8s](#set-up-cloudfoundry-using-cf-for-k8s)
  * [Deploy some applicatyions](#deploy-an-application-using-the-cf-client)
    * [Push an application using an existing container image](#push-an-application-using-an-existing-container-image)
    * [Push an application using buildpack](#push-an-application-using-buildpack)
    * [Deploy a Spring application accessing a Database](#deploy-a-spring-application-accessing-a-database)

## Prerequisites

To play with Cloud Foundry on Kubernetes, it is required to have :
- A Kubernetes cluster (>= 1.18) - [see](../all_in_one.md#create-a-k8s-cluster)
- The Helm tool (>= 1.13)
- The kubectl client installed
- A docker daemon
- Some [tools](tools.md)

## Set up Cloudfoundry using cf-for-k8s

See [instructions](./cf-for-k8s.md)

## Deploy an application using the cf client

- Configure the `cf` client to access the API and be authenticated
```bash
IP=<VM_ETH0_IP_ADDRESS>
cf api --skip-ssl-validation https://api.${IP}.nip.io
```

- The admin password has been generated within the `/tmp/cf-values.yml` and is available under the variable: `cf_admin_password`
```bash
export admin_pass=$(cat /tmp/cf-values.yml | yq e '.cf_admin_password' -)
```
- We authenticate using those credentials
```bash
cf auth admin "${admin_pass}"
```
- Let’s create a `demo` organization and a `redhat.com` space
```bash
cf create-org redhat.com
cf create-space demo -o redhat.com
cf create-user developer password
```
- Select the target space and org
```bash
cf target -o "redhat.com" -s "demo"
```
- Enable the docker feature
```bash
cf enable-feature-flag diego_docker
```
### Push an application using an existing container image

- Push the docker image of an application
```bash
cf push test-app1 -o cloudfoundry/diego-docker-app
```

### Push an application using buildpack

- Test an application compiled locally and pushed to a container registry
```bash
git clone https://github.com/cloudfoundry-samples/test-app.git
cd test-app
cf push test-app2
```
- Validate if the `test-app2` is reachable
```bash
curl -k  https://test-app2-meditating-nyala-ea.apps.95.217.159.244.nip.io/env
{"BAD_QUOTE":"'","BAD_SHELL":"$1","CF_INSTANCE_ADDR":"0.0.0.0:8080","CF_INSTANCE_INTERNAL_IP":"10.244.0.32","CF_INSTANCE_IP":"10.244.0.32","CF_INSTANCE_PORT":"8080","CF_INSTANCE_PORTS":"[{\"external\":8080,\"internal\":8080}]","HOME":"/home/some_docker_user","HOSTNAME":"diego-docker-app-demo-3c087bf83d-0","KUBERNETES_PORT":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP_ADDR":"10.96.0.1","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_SERVICE_HOST":"10.96.0.1","KUBERNETES_SERVICE_PORT":"443","KUBERNETES_SERVICE_PORT_HTTPS":"443","LANG":"en_US.UTF-8","MEMORY_LIMIT":"1024m","PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/myapp/bin","POD_NAME":"diego-docker-app-demo-3c087bf83d-0","PORT":"8080","SOME_VAR":"some_docker_value","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_ADDR":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PROTO":"tcp","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_HOST":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT_HTTP":"8080","VCAP_APPLICATION":"{\"cf_api\":\"https://api.95.217.134.196.nip.io\",\"limits\":{\"fds\":16384,\"mem\":1024,\"disk\":1024},\"application_name\":\"diego-docker-app\",\"application_uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"name\":\"diego-docker-app\",\"space_name\":\"demo\",\"space_id\":\"f148f02d-fcf3-4657-a3ea-f3f8cae530ad\",\"organization_id\":\"c4f7aa9b-18cf-4687-8073-719f61cc4168\",\"organization_name\":\"redhat.com\",\"uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"process_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"process_type\":\"web\",\"application_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\",\"application_version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\"}","VCAP_APP_HOST":"0.0.0.0","VCAP_APP_PORT":"8080","VCAP_SERVICES":"{}"}[snowdrop@k03-k116 cf-for-k8s]$
```

### Deploy a Spring application accessing a Database

In order to play with this scenario, it is needed to install the `buildpack` client (aka `pack`) and `minibroker` project able to create a service such as a database
from a helm chart/service catalog.

- Install `pack` client using the command: 
```bash
brew tap buildpack/tap
brew install pack
```

- Deploy the minibroker project which provides a collection of services as a `ServiceCatalog`. More information is available [here](https://svc-cat.io/docs/walkthrough/). 
 
```bash
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
helm repo update
kubectl create ns minibroker
helm install minibroker minibroker/minibroker -n minibroker  --set "deployServiceCatalog=false" --set "defaultNamespace=minibroker"
```

- Register the broker under `Cloudfoundry`
```bash
cf create-service-broker minibroker user pass http://minibroker-minibroker.minibroker.svc.cluster.local
```
- Enable the needed services
```bash
cf service-access
cf enable-service-access mysql
cf enable-service-access postgresql
```

- Create the `mysql-svc` service. Pass as parameter the tags `mysql` which is needed and used by the Java CfEnv library to match the profile of the application
  with the name of the service as defined by `VCAP_SERVICES`. It is also needed to specify the database name as it will be used by the Spring music application datasource
```bash
cf create-service mysql 5-7-30 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
```
- Optional. Check the status of the service created
```bash
cf service mysql-svc
```
- Git clone the spring music project and build it locally
```bash
git clone https://github.com/cmoulliard/spring-music.git && cd spring-music
./gradlew clean assemble
```

- Package the container image using the `buildpack` tool and push it to your images registry
```bash
podman pull gcr.io/paketo-buildpacks/builder:base
pack build spring-music-app -p ./ --builder gcr.io/paketo-buildpacks/builder:base --env 'BP_BUILT_ARTIFACT=build/libs/spring-music-*.jar'
podman tag spring-music-app cmoulliard/spring-music-app
podman push cmoulliard/spring-music-app
```
**REMARK**: We build manually the image instead of using `kpack` on cf-for-k8s as the release `v0.1.0` injects a wrong Spring Cloud library within the image which conflicts with the project `Pivotal CfEnv` 
when the spring boot application starts !

- Push and create the `spring music` application
```bash
cf push spring-music -o cmoulliard/spring-music-app
```
- Bind the service to your application
```bash
cf bind-service spring-music mysql-svc
```
- Change the active profile to `mysql` and `restage` the application
```bash
cf set-env spring-music SPRING_PROFILES_ACTIVE mysql
cf restage spring-music
```

- Open the application at the following address: `http://spring-music.<K8S_CLUSTER_IP>.nip.io/`

- All commands using mysql
```bash
cf unbind-service spring-music mysql-svc
cf delete-service mysql-svc -f
cf delete spring-music -f
cf create-service mysql 5-7-30 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
cf push spring-music -o cmoulliard/spring-music-app
cf set-env spring-music SPRING_PROFILES_ACTIVE mysql
cf bind-service spring-music mysql-svc
cf restage spring-music
```
- Check if the Application is well started, play with it ;-)
