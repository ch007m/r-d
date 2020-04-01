## Install kind client

- Execute the following instrcutions to install the kind client
```bash
curl -Lo ./kind https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64
chmod +x ./kind
sudo mv  ./kind /usr/local/bin
```
- More information is available on the [project web site](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)