## Common tools

- Install wget, helm, jq, brew, maven, k9s
```bash
sudo yum install -y wget epel-release jq maven
```
- Upgrade curl otherwise brew will complaint
```bash
sudo rpm -Uvh http://www.city-fan.org/ftp/contrib/yum-repo/rhel7/x86_64/city-fan.org-release-2-1.rhel7.noarch.rpm
sudo yum -y --enablerepo=city-fan.org install libcurl libcurl-devel
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

- To install the client supporting CF API `v7`, execute this brew command
```bash
brew install cloudfoundry/tap/bosh-cli
```

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