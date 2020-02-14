## Instructions

If OLM is deployed like the `operatorhub` catalog, then deploy the prometheus operator using the following commands:
```bash
kc -n demo apply -f resources/prometheus/single-operatorgroup.yml
kc -n demo apply -f resources/prometheus/subscription.yml
```

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

- Deploy the Spring Boot Prometheus application on the cluster, its service and ingress route
```bash
kc apply -n demo -f resources/prometheus/application/01-dep.yml
kc apply -n demo -f resources/prometheus/application/02-svc.yml
kc apply -n demo -f resources/prometheus/application/03-ingress.yml
```

- Create a Prometheus instance, service account, clusterrole, clusterrolebinding, ingress route
```bash
kc apply -n demo -f resources/prometheus/server
```

- And finally deploy the `ServiceMonitor` monitoring our Spring Boot application
```bash
kc apply -n demo -f resources/prometheus/application/04-servicemonitor.yml
```

- Open your browser at the following address and watch the resources: http://prometheus.88.99.186.195.nip.io/graph

- To clean the resources
```bash
kc delete -n demo -f resources/prometheus/application
kc delete -n demo -f resources/prometheus/server
```