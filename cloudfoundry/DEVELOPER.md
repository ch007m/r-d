## Cloud Foundry on Kubernetes

## Table of Contents

  * [Prerequisites](#prerequisites)
  * [Deployment of Cloud Foundry](#deployment-of-cloud-foundry)
  * [Deploy an application using cf](#deploy-an-application-using-cf)
     * [Push a docker image](#push-a-docker-image)
     * [Deploy a spring application accessing a Database](#deploy-a-spring-application-accessing-a-database)
     * [Push and build a spring application](#push-and-build-a-spring-application)

## Prerequisites

To play with Cloud Foundry on Kubernetes, it is required to have :
- A Kubernetes cluster (>= 1.14)
- The Helm tool (>= 1.13)
- The kubectl client installed
- A docker daemon
- Homebrew

## Deployment of Cloud Foundry

2 projects have been created to install Cloud Foundry on Kubernetes but the one which is currently packaged, as commercial
product, by VMWare for their product `Tanzu application Service` is `cf-for-k8s`.

- [cf-for-k8s](https://github.com/cloudfoundry/cf-for-k8s) - see [intructions](CF-4-K8s.md)
- [KubeCf](https://kubecf.suse.dev/) - see [intructions](KUBECF.md)

**REMARK**: `cf-for-k8` leverages Kubernetes native features such as `Controller, Secret, ConfigMap,...` and is built top of Kubernetes ecosystem projects: `istio`, `fluentd`, `kpack`, .... then `KubeCf`

The following sections of this documentation will rely on `cf-for-k8s` installation.

## Deploy an application using cf

- Setup the `cf` client to access the API and be authenticated
```bash
IP=<VM_ETH0_IP_ADDRESS>
cf api --skip-ssl-validation https://api.${IP}.nip.io
```
**Remarks**: 

- For `cf-4-k8s`: The admin password has been generated within the `/tmp/cf-values/` file and is available at the field `cf_admin_password`
```bash
export admin_pass=<cf_admin_password>
```
- For `kubecf`: We can fetch the random generated credentials for the default `admin user` 
```bash
export admin_pass=$(kubectl get secret \
          --namespace kubecf kubecf.var-cf-admin-password \
          -o jsonpath='{.data.password}' \
          | base64 --decode)
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

### Push a docker image

- Push the docker image of an application
```bash
cf push test-app -o cloudfoundry/diego-docker-app
```
- Validate the `app` is reachable
```bash
curl http://test-app.95.217.161.67.nip.io/env
{"BAD_QUOTE":"'","BAD_SHELL":"$1","CF_INSTANCE_ADDR":"0.0.0.0:8080","CF_INSTANCE_INTERNAL_IP":"10.244.0.32","CF_INSTANCE_IP":"10.244.0.32","CF_INSTANCE_PORT":"8080","CF_INSTANCE_PORTS":"[{\"external\":8080,\"internal\":8080}]","HOME":"/home/some_docker_user","HOSTNAME":"diego-docker-app-demo-3c087bf83d-0","KUBERNETES_PORT":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP_ADDR":"10.96.0.1","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_SERVICE_HOST":"10.96.0.1","KUBERNETES_SERVICE_PORT":"443","KUBERNETES_SERVICE_PORT_HTTPS":"443","LANG":"en_US.UTF-8","MEMORY_LIMIT":"1024m","PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/myapp/bin","POD_NAME":"diego-docker-app-demo-3c087bf83d-0","PORT":"8080","SOME_VAR":"some_docker_value","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_ADDR":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PROTO":"tcp","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_HOST":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT_HTTP":"8080","VCAP_APPLICATION":"{\"cf_api\":\"https://api.95.217.134.196.nip.io\",\"limits\":{\"fds\":16384,\"mem\":1024,\"disk\":1024},\"application_name\":\"diego-docker-app\",\"application_uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"name\":\"diego-docker-app\",\"space_name\":\"demo\",\"space_id\":\"f148f02d-fcf3-4657-a3ea-f3f8cae530ad\",\"organization_id\":\"c4f7aa9b-18cf-4687-8073-719f61cc4168\",\"organization_name\":\"redhat.com\",\"uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"process_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"process_type\":\"web\",\"application_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\",\"application_version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\"}","VCAP_APP_HOST":"0.0.0.0","VCAP_APP_PORT":"8080","VCAP_SERVICES":"{}"}[snowdrop@k03-k116 cf-for-k8s]$
```

### Deploy a spring application accessing a Database

In order to play with this scenario, it is needed to install the `buildpack` client and `minibroker` project able to create a service such as a database
from a helm chart

- Install `pack` client using the command: 
```bash
brew tap buildpack/tap
brew install pack
```

- Deploy the minibroker project. More information] is available [here](https://svc-cat.io/docs/walkthrough/). 
 
```bash
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
helm repo update
kc create ns minibroker
helm install minibroker --namespace minibroker minibroker/minibroker --set "deployServiceCatalog=false" --set "defaultNamespace=minibroker"
```

- Register the broker under Cloudfoundry
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
$ cf create-service mysql 5-7-28 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
```
- Optional. Check the status of the service created
```bash
cf service mysql-svc
```
- Git clone the spring music project and build it locally
```bash
git clone https://github.com/cmoulliard/spring-music.git && cd spring-music
./gradlew build
```

- Package the container image using the `buildpack` tool and push it to your images registry
```bash
pack build spring-music-app -p ./ --builder gcr.io/paketo-buildpacks/builder:base --env 'BP_BUILT_ARTIFACT=build/libs/spring-music-*.jar'
docker tag spring-music-app cmoulliard/spring-music-app
docker push cmoulliard/spring-music-app
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
cf create-service mysql 5-7-28 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
cf push spring-music -o cmoulliard/spring-music-app
cf set-env spring-music SPRING_PROFILES_ACTIVE mysql
cf bind-service spring-music mysql-svc
cf restage spring-music
```

### Push and build a spring application

- Git clone a Spring Boot example project and build it
```bash
git clone https://github.com/cloudfoundry-samples/spring-music
cd spring-music/
./gradlew assemble
```

- Next push it to CF
```bash
cf push spring-music

Pushing from manifest to org redhat.com / space demo as developer...
Using manifest file /home/snowdrop/temp/spring-music/manifest.yml
Getting app info...
Updating app with these attributes...
  name:                spring-music
  path:                /home/snowdrop/temp/spring-music/build/libs/spring-music-1.0.jar
  command:             JAVA_OPTS="-agentpath:$PWD/.java-buildpack/open_jdk_jre/bin/jvmkill-1.16.0_RELEASE=printHeapHistogram=1 -Djava.io.tmpdir=$TMPDIR -XX:ActiveProcessorCount=$(nproc) -Djava.ext.dirs=$PWD/.java-buildpack/container_security_provider:$PWD/.java-buildpack/open_jdk_jre/lib/ext -Djava.security.properties=$PWD/.java-buildpack/java_security/java.security $JAVA_OPTS" && CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_jre/bin/java-buildpack-memory-calculator-3.13.0_RELEASE -totMemory=$MEMORY_LIMIT -loadedClasses=20232 -poolType=metaspace -stackThreads=250 -vmOptions="$JAVA_OPTS") && echo JVM Memory Configuration: $CALCULATED_MEMORY && JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY" && MALLOC_ARENA_MAX=2 SERVER_PORT=$PORT eval exec $PWD/.java-buildpack/open_jdk_jre/bin/java $JAVA_OPTS -cp $PWD/. org.springframework.boot.loader.JarLauncher
  disk quota:          1G
  health check type:   port
  instances:           1
  memory:              1G
  stack:               cflinuxfs3
  env:
    JBP_CONFIG_SPRING_AUTO_RECONFIGURATION
  routes:
    spring-music.172.17.0.2.nip.io

Updating app spring-music...
Mapping routes...
Comparing local files to remote cache...
Packaging files to upload...
Uploading files...
 679.77 KiB / 679.77 KiB [===============================================================================================================================================] 100.00% 1s

Waiting for API to complete processing files...

Stopping app...

Staging app and tracing logs...
   2020/03/17 14:27:00 executor-started
   2020/03/17 14:26:54 downloader-started
   2020/03/17 14:26:54 Installing dependencies
   2020/03/17 14:26:58 downloader-done
   -----> Java Buildpack v4.26 | https://github.com/cloudfoundry/java-buildpack.git#e06e00b
   -----> Downloading Jvmkill Agent 1.16.0_RELEASE from https://java-buildpack.cloudfoundry.org/jvmkill/bionic/x86_64/jvmkill-1.16.0-RELEASE.so (0.0s)
   -----> Downloading Open Jdk JRE 1.8.0_242 from https://java-buildpack.cloudfoundry.org/openjdk/bionic/x86_64/openjdk-jre-1.8.0_242-bionic.tar.gz (2.4s)
   Expanding Open Jdk JRE to .java-buildpack/open_jdk_jre (1.3s)
   -----> Downloading Open JDK Like Memory Calculator 3.13.0_RELEASE from https://java-buildpack.cloudfoundry.org/memory-calculator/bionic/x86_64/memory-calculator-3.13.0-RELEASE.tar.gz (0.0s)
   Loaded Classes: 20114, Threads: 250
   -----> Downloading Client Certificate Mapper 1.11.0_RELEASE from https://java-buildpack.cloudfoundry.org/client-certificate-mapper/client-certificate-mapper-1.11.0-RELEASE.jar (0.0s)
   -----> Downloading Container Security Provider 1.16.0_RELEASE from https://java-buildpack.cloudfoundry.org/container-security-provider/container-security-provider-1.16.0-RELEASE.jar (0.1s)
   2020/03/17 14:27:29 executor-done
   2020/03/17 14:27:30 uploader-started
   2020/03/17 14:27:34 uploader-done

Waiting for app to start...

name:                spring-music
requested state:     started
isolation segment:   placeholder
routes:              spring-music.172.17.0.2.nip.io
last uploaded:       Tue 17 Mar 15:27:32 CET 2020
stack:               cflinuxfs3
buildpacks:          client-certificate-mapper=1.11.0_RELEASE container-security-provider=1.16.0_RELEASE
                     java-buildpack=v4.26-https://github.com/cloudfoundry/java-buildpack.git#e06e00b java-main java-opts java-security jvmkill-agent=1.16.0_RELEASE
                     open-jdk-like-jr...

type:            web
instances:       1/1
memory usage:    1024M
start command:   JAVA_OPTS="-agentpath:$PWD/.java-buildpack/open_jdk_jre/bin/jvmkill-1.16.0_RELEASE=printHeapHistogram=1 -Djava.io.tmpdir=$TMPDIR -XX:ActiveProcessorCount=$(nproc)
                 -Djava.ext.dirs=$PWD/.java-buildpack/container_security_provider:$PWD/.java-buildpack/open_jdk_jre/lib/ext
                 -Djava.security.properties=$PWD/.java-buildpack/java_security/java.security $JAVA_OPTS" &&
                 CALCULATED_MEMORY=$($PWD/.java-buildpack/open_jdk_jre/bin/java-buildpack-memory-calculator-3.13.0_RELEASE -totMemory=$MEMORY_LIMIT -loadedClasses=20232
                 -poolType=metaspace -stackThreads=250 -vmOptions="$JAVA_OPTS") && echo JVM Memory Configuration: $CALCULATED_MEMORY && JAVA_OPTS="$JAVA_OPTS $CALCULATED_MEMORY" &&
                 MALLOC_ARENA_MAX=2 SERVER_PORT=$PORT eval exec $PWD/.java-buildpack/open_jdk_jre/bin/java $JAVA_OPTS -cp $PWD/. org.springframework.boot.loader.JarLauncher
     state     since                  cpu    memory    disk      details
#0   running   2020-03-17T14:27:36Z   0.0%   0 of 1G   0 of 1G
```
- Check if the Application is well started, play with it ;-)
