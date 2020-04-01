## Install cf-for-k8s (aka VMWare Tanzu)

### Deploy the tools and configure cf-4-k8s

Additional information about how to install/configure is available with the project [instructions](https://github.com/cloudfoundry/cf-for-k8s/blob/master/docs/deploy.md)

- Install wget, helm, jq, brew, maven, k9s
```bash
sudo yum install wget -y
sudo yum install epel-release -y
sudo yum install jq -y 
sudo yum install maven -y
```

- Deploy helm3
```bash
mkdir temp && cd temp
wget https://get.helm.sh/helm-v3.1.2-linux-amd64.tar.gz
tar -vxf helm-v3.1.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin
```
- Install `brew` tool on the linux box
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
sudo yum groupinstall 'Development Tools'
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> /home/snowdrop/.bash_profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
```
- Install the tools needed to populate the kubernetes resources using ytt, kapp

```bash
brew tap k14s/tap
brew install ytt kbld kapp imgpkg kwt vendir
```

- Deploy the `bosh` client as it will be used during the next step to generate k8s resources
```bash
wget https://github.com/cloudfoundry/bosh-cli/releases/download/v6.2.1/bosh-cli-6.2.1-linux-amd64
mv bosh-cli-6.2.1-linux-amd64 bosh
chmod +x ./bosh
sudo mv ./bosh /usr/local/bin/bosh
```

- Install the CF Client to demo within the VM
```bash
curl -L "https://packages.cloudfoundry.org/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
```

- Git clone the project
```bash
git clone https://github.com/cloudfoundry/cf-for-k8s.git && cd cf-for-k8s
```

- Generate the `install` values such as domain name, app domain, certificates, ... using the bosh client 
```bash
IP=<VM_ETH0_IP_ADDRESS>
./hack/generate-values.sh -d ${IP}.nip.io > /tmp/cf-values.yml
```
- Edit the `/tmp/cf-values.yml` file to add your registry credentials
```yaml
...
log_cache_client:
  id: log-cache
  secret: <secret>>

app_registry:
  hostname: https://index.docker.io/v1/
  repository: <repo>
  username: <username>
  password: <password>
```

- Next, deploy `cf-4-k8s` using the `kapp` tool and some additional files
```bash
kapp deploy -a cf -f <(ytt -f config -f /tmp/cf-values.yml -f config-optional/remove-resource-requirements.yml -f config-optional/use-nodeport-for-ingress.yml)
```

### Additional features (optional)

### Kind cluster

- See how to install `kind` tool - [here](KIND.md)
- Create a kind cluster
```bash
sudo kind create cluster --name cf-k8s --config=./deploy/kind/cluster.yml
sudo docker exec -it "kubecf-control-plane" bash -c 'cp /etc/kubernetes/pki/ca.crt /etc/ssl/certs/ && update-ca-certificates && (systemctl list-units | grep containerd > /dev/null && systemctl restart containerd)'
```
- Got the k8s config
```bash
mkdir ~/.kube
sudo kind get kubeconfig --name cf-k8s  > ~/.kube/config
```

### Stratos console 

See [instructions](OTHERS.md)

