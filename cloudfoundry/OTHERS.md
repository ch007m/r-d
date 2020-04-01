## Install Developer console - Stratos

```bash
export node_ip=95.217.161.67
kc create ns stratos
cat << _EOF_ > stratos.yml
console:
  service:
    externalIPs: ["${node_ip}"]
    servicePort: 8443
_EOF_

helm repo add suse https://kubernetes-charts.suse.com/
helm install stratos --namespace stratos --values ./stratos.yml suse/console
```
