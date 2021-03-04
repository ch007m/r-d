## Cloud Foundry on Kubernetes

## Table of Contents

  * [Prerequisites](#prerequisites)
  * [Deployment of Cloud Foundry](#deployment-of-cloud-foundry)
  * [Deploy an application using cf](#deploy-an-application-using-cf)
     * [Push a docker image](#push-a-docker-image)
     * [Deploy a spring application accessing a Database](#deploy-a-spring-application-accessing-a-database)

## Prerequisites

To play with Cloud Foundry on Kubernetes, it is required to have :
- A Kubernetes cluster (>= 1.18)
- The Helm tool (>= 1.13)
- The kubectl client installed
- A docker daemon
- Homebrew

## Deploy an application using cf

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
```
- Select the target space and org
```bash
cf target -o "redhat.com" -s "demo"
```

- Enable the docker feature
```bash
cf enable-feature-flag diego_docker
```

## Deploy a Spring application accessing a Database

In order to play with this scenario, it is needed to install the `buildpack` client and `minibroker` project able to create a service such as a database
from a helm chart

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
