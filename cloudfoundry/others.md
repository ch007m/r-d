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
helm install stratos -n console --values ./stratos.yml stratos/console
kubectl port-forward stratos-0 --address localhost,<EXTERNAL_IP_ADDRESS> 30000:443 -n console
Next, open your browser at the address

https://<EXTERNAL_IP_ADDRESS>:30000
```

- An alternative is to run the console using locally stratos
```bash
docker run -p 8444:443 splatform/stratos:latest
```

