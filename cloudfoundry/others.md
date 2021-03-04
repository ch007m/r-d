## Install Developer console - Stratos

- Deploy it with the help of a helm chart on kind
```bash
cat << EOF > stratos.yml
console:
  service:
    type: NodePort
    nodePort: 30000
EOF

kubectl create ns console
helm install stratos stratos/console -n console --values ./stratos.yml 
```

- To access Stratos: Get the URL by running these commands in the same shell:
```bash
export NODE_PORT=$(kubectl get --namespace console -o jsonpath="{.spec.ports[0].nodePort}" services stratos-ui-ext)
export NODE_IP=$(kubectl get nodes --namespace console -o jsonpath="{.items[0].status.addresses[0].address}")
echo https://$NODE_IP:$NODE_PORT
```

- An alternative is to run the console using locally stratos (optional)
```bash
docker run -p 8444:443 splatform/stratos:latest
```
- Next register the API endpoint :-) and use as credential `admin` as user and pwd as defined within the cf-values.yml file
```bash
https://api.95.217.159.244.nip.io

```

