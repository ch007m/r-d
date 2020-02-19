## Instructions

### Compile the Spring Boot Prometheus example

- Git clone the `dekorate` project and build the example of Spring Boot Prometheus
```bash
git clone https://github.com/dekorateio/dekorate.git & cd dekorate/examples/spring-boot-with-prometheus-on-kubernetes-example
mvn clean install
```
- Build the project as a container image and push it on your registry
```bash
docker build -t cmoulliard/spring-boot-prometheus .
docker push cmoulliard/spring-boot-prometheus
```

### Deploy the Prometheus Operator

If OLM is deployed like the `operatorhub` catalog, then deploy the prometheus operator using the following commands:
```bash
kc -n demo apply -f resources/prometheus/olm/single-operatorgroup.yml
kc -n demo apply -f resources/prometheus/olm/prometheus-subscription.yml
```

### Deploy the application and create the Prometheus CRs

- Deploy the Spring Boot Prometheus application on the cluster, its service and ingress route
```bash
kc apply -n demo -f resources/prometheus/application/01-dep.yml
kc apply -n demo -f resources/prometheus/application/02-svc.yml
kc apply -n demo -f resources/prometheus/application/03-ingress.yml
```

- Check if you can access the endpoint of the service using a curl request or the metrics
```
curl http://sb-monitor.88.99.186.195.nip.io
curl http://sb-monitor.88.99.186.195.nip.io/actuator/prometheus
```

- Create a Prometheus instance, service account, clusterrole, clusterrolebinding, ingress route
```bash
kc apply -n demo -f resources/prometheus/server
```

- And finally deploy the `ServiceMonitor` to monitor our Spring Boot application
```bash
kc apply -n demo -f resources/prometheus/application/04-servicemonitor.yml
```

- Open your browser at the following address and watch the resources `http://prometheus.88.99.186.195.nip.io/graph`

- To clean the resources
```bash
kc delete -n demo -f resources/prometheus/application
kc delete -n demo -f resources/prometheus/server
```

## Configure Grafana to use prometheus server/metrics

- Deploy the Grafana `Subscription`
```bash
kc -n demo apply -f resources/grafana/olm
```

- Tell to the operator to create a Grafana instance, service, ingress route, Dashboard and datasource to grab
  information from prometheus server
```bash
kc -n demo apply -f resources/grafana/
```

- Open the grafana console at this address: http://grafana-console.88.99.186.195.nip.io

- clean the resources
```bash
kc -n demo delete -f resources/prometheus/grafana/
```