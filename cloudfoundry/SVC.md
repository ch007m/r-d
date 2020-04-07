## Deploy Service Catalog

- Deploy first the Service Catalog API and change the webhook service secure port as the same port is already used by Istio
```bash
git clone https://github.com/kubernetes-sigs/service-catalog.git
kubectl create ns catalog
cat << _EOF_ > svc.yml
image: quay.io/kubernetes-service-catalog/service-catalog:canary

webhook:
  service:
    port: 443
    type: NodePort
    nodePort:
      securePort: 31444
_EOF_

helm install catalog service-catalog/charts/catalog -n catalog --values ./svc.yml
```
- Next, install the Service Catalog Client `svcat`
```bash
curl -sLO https://download.svcat.sh/cli/latest/linux/amd64/svcat
chmod +x ./svcat
sudo mv ./svcat /usr/local/bin/
```

## OAB

- Follow these instructions to install the Automation Broker (aka Ansible Service Broker)
```bash
cat << _EOF_ > oab.yml
apiVersion: v1
kind: Namespace
metadata:
  name: oab
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: automation-broker-apb
  namespace: oab
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: automation-broker-apb
roleRef:
  name: cluster-admin
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: automation-broker-apb
    namespace: oab
---
apiVersion: v1
kind: Pod
metadata:
  name: automation-broker-apb
  namespace: oab
spec:
  serviceAccount: automation-broker-apb
  containers:
    - name: apb
      image: docker.io/automationbroker/automation-broker-apb:latest
      args:
        - "provision"
        - "-e create_broker_namespace=true"
        - "-e broker_auto_escalate=true"
        - "-e wait_for_broker=true"
        - "-e broker_basic_auth_enabled=true"
      imagePullPolicy: IfNotPresent
  restartPolicy: Never
_EOF_

kc apply -f oab.yml
```
- As we have enabled the basic auth, it is then needed to change manually the config of the `ClusterServiceBroker`
  and to add the reference of the secret containing the `username` and `password` to access using basic auth http the Broker.
  **Remark**: This is needed for CF
```bash
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ClusterServiceBroker
metadata:
  name: automation-broker
spec:
  authInfo:
    basic:
      secretRef:
        namespace: automation-broker
        name: broker-auth
```
- Wait a few minutes and next verify if classes, plans, brokers have been created using the `svcat get classes|brokers|plans` command

## Configure cf to use OAB

- Register the Service Broker
```bash
cf create-service-broker oab admin admin https://broker.automation-broker.svc:1338/ansible-service-broker
```

- Enable some services
```bash
cf service-access
cf enable-service-access dh-prometheus-apb
cf enable-service-access dh-postgresql-apb
```

- Create a service
```bash
cf create-service dh-postgresql-apb dev mypostgresql
```
- Bind the service and restart it
```bash
cf bind-service spring-music mypostgresql
cf restart
```

**Issue**: https://github.com/openshift/ansible-service-broker/issues/1290

- Plan B : Create a Service instance manually
```bash
cat << _EOF_ > serviceinstance.yml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: postgresql
  namespace: demo
spec:
  clusterServiceClassExternalName: dh-postgresql-apb
  clusterServicePlanExternalName: dev
  parameters:
    app_name: "postgresql"
    postgresql_user: "luke"
    postgresql_password: "secret"
    postgresql_database: "my_data"
    postgresql_version: "9.6"
_EOF_

kc apply -f serviceinstance.yml -n cf-workloads
svcat describe instance postgresql -n cf-workloads
```

*Issue* : see ticket - https://github.com/openshift/ansible-service-broker/issues/1291

- Workaround. Create manually the APB pod to provision the DB
```bash
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ansible-broker-apb
  namespace: demo
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: ansible-broker-apb
roleRef:
  name: cluster-admin
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
subjects:
  - kind: ServiceAccount
    name: ansible-broker-apb
    namespace: demo 
---
apiVersion: v1
kind: Pod
metadata:
  labels:
    apb-action: provision
    apb-fqname: dh-postgresql-apb
    apb-pod-name: apb-test
  name: apb-test
spec:
  serviceAccount: ansible-broker-apb
  containers:
  - args:
    - provision
    - --extra-vars
    - '{"_apb_last_requesting_user":"system:serviceaccount:catalog:service-catalog-controller-manager","_apb_plan_id":"dev","_apb_service_class_id":"1dda1477cace09730bd8ed7a6505607e","_apb_service_instance_id":"4eba4471-a357-46b5-8fd3-dc96033e06d4","app_name":"postgresql","cluster":"kubernetes","namespace":"demo","postgresql_database":"my_data","postgresql_password":"secret","postgresql_user":"luke","postgresql_version":"9.6"}'
    env:
    - name: POD_NAME
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: metadata.name
    - name: POD_NAMESPACE
      valueFrom:
        fieldRef:
          apiVersion: v1
          fieldPath: metadata.namespace
    image: docker.io/ansibleplaybookbundle/postgresql-apb:v3.10
    imagePullPolicy: IfNotPresent
    name: apb
    resources: {}
    terminationMessagePath: /dev/termination-log
```

- Next, create binding
```bash
cat << _EOF_ > servicebinding.yml
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  name: postgresql-binding
spec:
  instanceRef:
    name: postgresql
_EOF_

kc apply -f servicebinding.yml -n cf-workloads
svcat describe binding mini-binding -n cf-workloads
```

## Minibroker

- And deploy the mini-broker. More information] is available [here](https://svc-cat.io/docs/walkthrough/). 
 
```bash
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
kc create ns minibroker
helm install minibroker -n minibroker minibroker/minibroker
```
- If minibroker will be used with CF, then use the following [instructions](https://github.com/kubernetes-sigs/minibroker#usage-with-cloud-foundry)
```bash
helm install minibroker -n minibroker minibroker/minibroker \
	--set "deployServiceCatalog=false" \
    --set "defaultNamespace=minibroker"
```

- To play with CF and minibroker - see [here](https://github.com/kubernetes-sigs/minibroker#usage)

## Using Postgresql service and cups

- Create a service to access the PostgreSQL DB
```bash
cat << _EOF_ > mypostgresql.yml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: mypostgresql
  name: mypostgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mypostgresql
  template:
    metadata:
      labels:
        app: mypostgresql
    spec:
      containers:
        - env:
            - name: POSTGRESQL_DATABASE
              value: my_data
            - name: POSTGRESQL_PASSWORD
              value: secret
            - name: POSTGRESQL_USER
              value: luke
          image: centos/postgresql-10-centos7
          name: mypostgresql
          ports:
            - containerPort: 5432
              protocol: TCP
          resources: {}
          volumeMounts:
            - mountPath: /var/lib/pgsql/data
              name: mypostgresql-volume
      volumes:
        - emptyDir: {}
          name: mypostgresql-volume
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: mypostgresql
  name: mypostgresql
spec:
  ports:
    - name: 5432-tcp
      port: 5432
      protocol: TCP
      targetPort: 5432
  selector:
    app: mypostgresql
_EOF_

kc apply -f mypostgresql.yml -n cf-workloads
```

- Create cups
```bash
cf cups myspostgresql -p '{"uri":"postgresql://postgres:@mypostgresql.cf-workloads.svc:5432/music"}'
```
- Bind the service to the application
```bash
cf bind-service spring-music myspostgresql
```
- Restart the application
```bash
cf restart
```
- To unbind 
```bash
cf unbind-service spring-music myspostgresql
```
