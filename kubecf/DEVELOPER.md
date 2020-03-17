## Cloud Foundry Kubernetes

## Table of Contents

   * [Prerequisites](#prerequisites)
   * [Install Tanzu cf-for-k8s](#install-tanzu-cf-for-k8s)
      * [Deploy an application using cf](#deploy-an-application-using-cf)
   * [Install KubeCF](#install-kubecf)
      * [Using Kind](#using-kind)
      * [Additional features needed for kind](#additional-features-needed-for-kind)
      * [Using kubeadm, kubelet](#using-kubeadm-kubelet)
      * [Play with CF Push](#play-with-cf-push)
      * [Backlog of issues](#backlog-of-issues)


## Prerequisites

To play with the new Cloud Foundry Kubernetes distribution, it is required to have :
- A Kubernetes cluster (>= 1.14)
- The Helm tool (>= 1.13)
- The kubectl client installed
- A docker daemon
- Homebrew

## Install Tanzu cf-for-k8s

TODO - See instructions [here](https://github.com/cloudfoundry/cf-for-k8s/blob/master/docs/deploy.md)

- Install the needed tools
```bash
brew tap k14s/tap
brew install ytt kbld kapp imgpkg kwt vendir
#brew install cloudfoundry/tap/bosh-cli
#chmod u+x /home/linuxbrew/.linuxbrew/Cellar/bosh-cli/6.2.1/bin/bosh
wget https://github.com/cloudfoundry/bosh-cli/releases/download/v6.2.1/bosh-cli-6.2.1-linux-amd64
mv bosh-cli-6.2.1-linux-amd64 bosh
chmod +x ./bosh
sudo mv ./bosh /usr/local/bin/bosh
```
- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```
- Create a kind cluster
```bash
sudo kind create cluster --name cf-k8s --config=./deploy/kind/cluster.yml
```
- Got the k8s config
```bash
mkdir ~/.kube
sudo kind get kubeconfig --name cf-k8s  > ~/.kube/config
```

- Generate the `install` values such as domain name, app domain, certificates, ... using the bosh client 
```bash
./hack/generate-values.sh 95.217.134.196.nip.io > /tmp/cf-values.yml
```

### Deploy an application using cf

- Next, deploy `cf-4-k8s` using the `kapp` tool and some additional files
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config-optional/remove-resource-requirements.yml -f config-optional/use-nodeport-for-ingress.yml)
```

- Setup the `cf` client to access the API and be authenticated
```bashkc 
cf api --skip-ssl-validation https://api.95.217.134.196.nip.io
cf auth admin <admin_pwd>
```
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
- Push the docker image of an application
```bash
cf push diego-docker-app -o cloudfoundry/diego-docker-app
```
- Validate the `app` is reachable
```bash
curl http://diego-docker-app.95.217.134.196.nip.io/env
{"BAD_QUOTE":"'","BAD_SHELL":"$1","CF_INSTANCE_ADDR":"0.0.0.0:8080","CF_INSTANCE_INTERNAL_IP":"10.244.0.32","CF_INSTANCE_IP":"10.244.0.32","CF_INSTANCE_PORT":"8080","CF_INSTANCE_PORTS":"[{\"external\":8080,\"internal\":8080}]","HOME":"/home/some_docker_user","HOSTNAME":"diego-docker-app-demo-3c087bf83d-0","KUBERNETES_PORT":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP":"tcp://10.96.0.1:443","KUBERNETES_PORT_443_TCP_ADDR":"10.96.0.1","KUBERNETES_PORT_443_TCP_PORT":"443","KUBERNETES_PORT_443_TCP_PROTO":"tcp","KUBERNETES_SERVICE_HOST":"10.96.0.1","KUBERNETES_SERVICE_PORT":"443","KUBERNETES_SERVICE_PORT_HTTPS":"443","LANG":"en_US.UTF-8","MEMORY_LIMIT":"1024m","PATH":"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/myapp/bin","POD_NAME":"diego-docker-app-demo-3c087bf83d-0","PORT":"8080","SOME_VAR":"some_docker_value","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP":"tcp://10.100.236.5:8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_ADDR":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_PORT_8080_TCP_PROTO":"tcp","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_HOST":"10.100.236.5","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT":"8080","S_CD8A51EC_F591_488B_B98D_5884B15C156B_SERVICE_PORT_HTTP":"8080","VCAP_APPLICATION":"{\"cf_api\":\"https://api.95.217.134.196.nip.io\",\"limits\":{\"fds\":16384,\"mem\":1024,\"disk\":1024},\"application_name\":\"diego-docker-app\",\"application_uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"name\":\"diego-docker-app\",\"space_name\":\"demo\",\"space_id\":\"f148f02d-fcf3-4657-a3ea-f3f8cae530ad\",\"organization_id\":\"c4f7aa9b-18cf-4687-8073-719f61cc4168\",\"organization_name\":\"redhat.com\",\"uris\":[\"diego-docker-app.95.217.134.196.nip.io\"],\"process_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"process_type\":\"web\",\"application_id\":\"7e52ed45-3a98-41ca-ac94-21b69cf06f9f\",\"version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\",\"application_version\":\"63884c6e-3e6d-45a9-b16a-40cc3e3d5c48\"}","VCAP_APP_HOST":"0.0.0.0","VCAP_APP_PORT":"8080","VCAP_SERVICES":"{}"}[snowdrop@k03-k116 cf-for-k8s]$
```

- Clean the cluster
```bash
sudo kind delete cluster --name cf-k8s
```

## Install KubeCF

To use [`kubecf`](https://kubecf.suse.dev/), you will install 2 helm charts in order to deploy:

- cf-operator: https://cloudfoundry-incubator.github.io/quarks-helm/
- kubecf: https://github.com/cloudfoundry-incubator/kubecf/tree/master/deploy/helm/kubecf

**NOTES**

The `cf-operator` is the underlying generic tool to deploy a (modified) BOSH deployment like `Kubecf` for use.
It has to be installed in the same Kubernetes cluster that Kubecf will be deployed to.

In this default deployment, kubecf is launched without Ingress, and it uses the `Eirini` scheduler.

### Using Kind

- Install first [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
```bash
cd ~/temp
alias sudo='sudo env PATH=$PATH'
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
chmod +x ./kind
sudo mv kind /usr/local/bin
```
- Create a [kind config file]() mapping and exposing additional ports and configuring ingress
```bash
cat << _EOF_  > cfg.yml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
        authorization-mode: "AlwaysAllow"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
_EOF_
```
- Create a kubernetes cluster
```bash
sudo kind create cluster --name kubecf --config=cfg.yml
sudo kind get kubeconfig --name kubecf > .kubeconfig
```

- Create an alias to use `kc` instead of `kubectl` and export the `KUBECONFIG` env var
```bash
alias kc=kubectl
export KUBECONFIG=.kubeconfig
```
- Trust the `kubernetes root CA` on the `kind docker container`
``` bash 
docker exec -it "kubecf-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'
Updating certificates in /etc/ssl/certs...
0 added, 0 removed; done.
Running hooks in /etc/ca-certificates/update.d...
done.
```
- Create a namespace for the cf-operator and install it
```bash
kc create namespace cf-operator
helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```
- Create the following `values.yaml` file with the `Node IP` address that we could use within the vm
```bash
node_ip=$(kubectl get node kubecf-control-plane \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }')
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
features:
  eirini:
    enabled: true
  ingress:
    enabled: false
    tls:
      crt: ~
      key: ~
    annotations: {}
    labels: {}
services:
  router:
    externalIPs:
    - ${node_ip}
kube:
  service_cluster_ip_range: 0.0.0.0/0
  pod_cluster_ip_range: 0.0.0.0/0
_EOF_
```

- Install the `KubeCF` helm chart
```bash
helm install kubecf \
   --namespace kubecf \
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```

### Additional features needed for kind

- Create a Cluster Admin Group for the group `system:bootstrappers` used to access the console/dashboard using a Token created as a secret with token-id, token-secret, auth-extra-groups: system:bootstrappers:worker
```bash
export NODE_IP=95.217.134.196
export TOKEN_PUBLIC=<CHANGE.ME>
export TOKEN_SECRET=<CHANGE.ME>

cat << _EOF_  > security-dashboard.yml
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cluster-admin-for-bootstrappers
subjects:
- kind: Group
  name: system:bootstrappers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io

---
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-${TOKEN_PUBLIC}
  namespace: kube-system

type: bootstrap.kubernetes.io/token
stringData:
  # Human readable description. Optional.
  description: snowdrop-admin-user

  # Token ID and secret. Required.
  token-id: ${TOKEN_PUBLIC}
  token-secret: ${TOKEN_SECRET}

  # Allowed usages.
  usage-bootstrap-authentication: "true"
  usage-bootstrap-signing: "true"
  auth-extra-groups: system:bootstrappers:worker
_EOF_

kc apply -f security-dashboard.yml
```

- Install the k8s dashboard
```bash
kc apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta8/aio/deploy/recommended.yaml
```

- Deploy [Ingress](https://kind.sigs.k8s.io/docs/user/ingress/) controller
```bash
kc apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kc apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/baremetal/service-nodeport.yaml
kc patch deployments -n ingress-nginx nginx-ingress-controller -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx-ingress-controller","ports":[{"containerPort":80,"hostPort":80},{"containerPort":443,"hostPort":443}]}],"nodeSelector":{"ingress-ready":"true"},"tolerations":[{"key":"node-role.kubernetes.io/master","operator":"Equal","effect":"NoSchedule"}]}}}}'
```
- Create an `ingress resource` to access the dashboard from any machine
```bash
cat << _EOF_  > ingress-dashboard.yml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    kubernetes.io/ingress.class: nginx
  labels:
    app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  rules:
  - host: k8s-console.${NODE_IP}.nip.io
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
        path: /
_EOF_

kc apply -f ingress-dashboard.yml
```

- To destroy/clean the cluster
```bash
sudo kind delete cluster --name kubecf
```

### Using kubeadm, kubelet

**NOTE**: The scenario reported here will fail due to a problem with the Certificate needed by the UAA application. [Ticket](https://github.com/cloudfoundry-incubator/kubecf/issues/483) has been created and should be fiexed with
release [1.2.0](https://github.com/cloudfoundry-incubator/kubecf/issues?q=is%3Aopen+is%3Aissue+milestone%3A1.2.0)

- SSH to the vm where k8s >= 1.15 is deployed
```bash
ssh -i ~/.ssh/id_rsa_snowdrop_hetzner_k03-k116 snowdrop@95.217.134.196 -p 47286
```
- Install Helm tool within the VM

```bash
mkdir temp && cd temp
sudo yum install wget
wget https://get.helm.sh/helm-v3.1.1-linux-amd64.tar.gz
tar -vxf helm-v3.1.1-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
alias kc=kubectl
```

- Create a namespace for the cf-operator and install it
```bash
kc create ns cf-operator

helm repo add quarks https://cloudfoundry-incubator.github.io/quarks-helm/
helm search repo quarks
helm install cf-operator quarks/cf-operator --namespace cf-operator --set "global.operator.watchNamespace=kubecf"
```

- Create the following `values.yaml` file with the VM Ethernet IP address that we could use from our laptop
```bash
NODE_NAME=k03-k116
node_ip=$(kubectl get node ${NODE_NAME} \
  --output jsonpath='{ .status.addresses[?(@.type == "InternalIP")].address }')
cat << _EOF_  > values.yaml
system_domain: ${node_ip}.nip.io
services:
  router:
    externalIPs:
    - ${node_ip}
kube:
  service_cluster_ip_range: 0.0.0.0/0
  pod_cluster_ip_range: 0.0.0.0/0
_EOF_
```

- Install the `KubeCF` helm chart
```bash
helm install kubecf \
   --namespace kubecf \
   --values values.yaml https://github.com/cloudfoundry-incubator/kubecf/releases/download/v1.0.0/kubecf-v1.0.0.tgz
```

- Watch the pods
```bash
kubectl -n kubecf get pods -w
```

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
cf push --hostname spring-music
Deprecation warning: Use of the '--hostname' command-line flag option is deprecated in favor of the 'routes' property in the manifest. Please see https://docs.cloudfoundry.org/devguide/deploy-apps/manifest-attributes.html#routes for usage information. The '--hostname' command-line flag option will be removed in the future.

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

### Backlog of issues

- `CF Push` - X509 certificate issue : https://github.com/cloudfoundry-incubator/kubecf/issues/487
- `kubecf-diego` - Diego fails to start on K8s when it is used instead of `Eirini` with `Kind`: https://github.com/cloudfoundry-incubator/kubecf/issues/484
- `kubecf-diego-api-0` pod is crashing due to x509 certificate issue using externalIP top k8s - : https://github.com/cloudfoundry-incubator/kubecf/issues/483
