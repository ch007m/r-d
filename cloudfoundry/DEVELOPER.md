## Cloud Foundry Kubernetes

## Table of Contents

  * [Prerequisites](#prerequisites)
  * [Using cf-for-k8s](#using-cf-for-k8s)
  * [Using kubecf](#using-kubecf)

  * [Deploy an application using cf](#deploy-an-application-using-cf)
     * [Push a docker image](#push-a-docker-image)
     * [Push and build a spring application](#push-and-build-a-spring-application)
     * [Play with CF Push](#play-with-cf-push)


## Prerequisites

To play with Cloud Foundry on Kubernetes, it is required to have :
- A Kubernetes cluster (>= 1.14)
- The Helm tool (>= 1.13)
- The kubectl client installed
- A docker daemon
- Homebrew

## Using cf-for-k8s

See intructions [here](CF-4-K8s.md)

## Using kubecf

See intructions [here](KUBECF.md)

## Deploy an application using cf

- Setup the `cf` client to access the API and be authenticated
```bash
IP=<VM_ETH0_IP_ADDRESS>
cf api --skip-ssl-validation https://api.${IP}.nip.io
cf auth admin <admin_pwd>
```
**Remark**: The admin password has been generated within the `/tmp/cf-values/` file and is available at the field `cf_admin_password`

- Enable the docker feature
```bash
cf enable-feature-flag diego_docker
```
- Create an `ORG` and `SPACE` to deploy an application
```bash
cf create-org redhat.com
cf create-space demo -o redhat.com
cf target -o "redhat.com" -s "demo"
```

### Push a docker image

- Push the docker image of an application
```bash
cf push test-app -o cloudfoundry/diego-docker-app
```
- Validate the `app` is reachable
```bash
curl http://test-app.95.217.134.196.nip.io/env
{"BAD_QUOTE":"'","BAD_SHELL":"$1","CF_INSTANCE_ADDR":"0.0.0.0:8080","CF_INSTANCE_INTERNAL_IP":"10.244.0.32","CF_INSTANCE_IP":"10.244.0.32","CF_INSTANCE_PORT":"8080","CF_INSTANCE_PORTS":"[{\"external\":8080,\"internal\":8080}]","HOME":"/home/some_docker_user","HOSTNAME":"diego-docker-app-demo-3c087bf83d-0","KUBERNETES_PORT":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP_ADDR":"10.96.0.1","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_SERVICE_HOST":"10.96.0.1","KUBERNETES_SERVICE_PORT":"443","KUBERNETES_SERVICE_PORT_HTTPS":"443","LANG":"en_US.UTF-8","MEMORY_LIMIT":"1024m","PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/myapp/bin","POD_NAME":"diego-docker-app-demo-3c087bf83d-0","PORT":"8080","SOME_VAR":"some_docker_value","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_ADDR":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PROTO":"tcp","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_HOST":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT_HTTP":"8080","VCAP_APPLICATION":"{\"cf_api\":\"https://api.95.217.134.196.nip.io\",\"limits\":{\"fds\":16384,\"mem\":1024,\"disk\":1024},\"application_name\":\"diego-docker-app\",\"application_uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"name\":\"diego-docker-app\",\"space_name\":\"demo\",\"space_id\":\"f148f02d-fcf3-4657-a3ea-f3f8cae530ad\",\"organization_id\":\"c4f7aa9b-18cf-4687-8073-719f61cc4168\",\"organization_name\":\"redhat.com\",\"uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"process_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"process_type\":\"web\",\"application_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\",\"application_version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\"}","VCAP_APP_HOST":"0.0.0.0","VCAP_APP_PORT":"8080","VCAP_SERVICES":"{}"}[snowdrop@k03-k116 cf-for-k8s]$
```

### Push and build a spring application

- Git clone a spring example project and build it
```bash
git clone https://github.com/cloudfoundry-samples/spring-music
cd spring-music/
./gradlew assemble
```

- Next push it to CF
```bash
cf push spring-music
```

TODO

### Play with CF Push

- Maven and JDK should be installed on the VM
```bash
sudo yum install maven
```

- Install first the `cf` client as documented [here](https://github.com/cloudfoundry/cli#downloads)
```bash
cd temp
curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
```

- If you want to use the Developer console - stratos, install it using the following helm chart
```bash
kc create ns consolehelm status my-console
helm repo add stratos https://cloudfoundry.github.io/stratos
helm install my-console stratos/console --namespace console
```
**NOTE**: TODO: Add ingress and create a resource to access the console !

- Next, access the CF API using the node ip address as registered
```bash
cf api --skip-ssl-validation api.172.17.0.2.nip.io
Setting api endpoint to api.172.17.0.2.nip.io...
OK

api endpoint:   https://api.172.17.0.2.nip.io
api version:    2.146.0
Not logged in. Use 'cf login' or 'cf login --sso' to log in.
```

- We fetch the random generated credentials for the default `admin user` 
```bash
export admin_pass=$(kubectl get secret \
          --namespace kubecf kubecf.var-cf-admin-password \
          -o jsonpath='{.data.password}' \
          | base64 --decode)
```

- We authenticate using those credentials
```bash
cf auth admin "${admin_pass}"
API endpoint: https://api.172.17.0.2.nip.io
Authenticating...
OK

Use 'cf target' to view or set your target org and space.
```
- Let’s create a `demo` organization, a `space` and a `development user`
```bash
cf create-org redhat.com
cf create-space demo -o redhat.com
cf create-user developer password
cf set-space-role developer redhat.com demo SpaceDeveloper
cf set-space-role developer redhat.com demo SpaceManager
```
- Switch to the developer user
```bash
cf login -u developer -p password
API endpoint: https://api.172.17.0.2.nip.io
Authenticating...
OK
Targeted org redhat.com
Targeted space demo

API endpoint:   https://api.172.17.0.2.nip.io (API version: 2.146.0)
User:           developer
Org:            redhat.com
Space:          demo
```
- Install a Spring Boot application and build it
```bash
git clone https://github.com/cloudfoundry-samples/spring-music
cd spring-music/
./gradlew assemble
```
- Next push it on the k8s cluster
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
- Check if the Application is well started, play with it
- Test an application with a [database](https://tanzu.vmware.com/tutorials/getting-started/introduction)
