## Common tools

See official [page](https://github.com/cloudfoundry/cf-for-k8s/blob/develop/docs/getting-started-tutorial.md#tooling)

- Install wget, helm, jq, brew, maven, k9s
```bash
sudo yum install -y wget epel-release jq maven
```
- Upgrade curl otherwise brew will complaint
```bash
sudo rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-2-1.rhel7.noarch.rpm
sudo yum -y --enablerepo=city-fan.org install libcurl libcurl-devel
```  
- Install git 2
```bash
sudo yum remove git*
sudo yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
sudo yum install git
```  
- Install `brew` tool on the linux box
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >> /home/snowdrop/.bash_profile
eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
alias sudo='sudo env PATH=$PATH'
```

- Install the tools needed to deploy `cf-for-k8s` such as :
```bash
brew install gcc 
brew tap vmware-tanzu/carvel
brew install ytt kbld kapp imgpkg kwt vendir yq
```

- Deploy helm3
```bash
brew install helm
```

- To install the BOSH client 
```bash
brew install cloudfoundry/tap/bosh-cli
```  

- The CF client `v7`
```bash
brew install cloudfoundry/tap/cf-cli@7
```

### Nice to have (optional)

- Deploy the `k9s` user tool
```bash
brew install k9s
```

- Install the `httpie` tool showing better json responses than curl
```bash
brew install httpie
```
- To build an image using `buildpack`
```bash
brew tap buildpack/tap
brew install pack
```
- Deploy `cfssl` tool to generate cert/pem and request to be signed
```bash
brew install cfssl
```