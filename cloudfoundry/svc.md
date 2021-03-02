## Deploy Service Catalog

Table of Contents
=================

  * [Minibroker](#minibroker)
  * [Install the Kubernetes Service Catalog](#install-the-kubernetes-service-catalog)
  * [OAB](#oab)
  * [Configure cf to use OAB](#configure-cf-to-use-oab)
  * [Using Postgresql service and cups](#using-postgresql-service-and-cups)

## Minibroker

- And deploy the mini-broker. More information] is available [here](https://svc-cat.io/docs/walkthrough/). 
 
```bash
helm repo add minibroker https://minibroker.blob.core.windows.net/charts
helm repo update
kc create ns minibroker
helm install minibroker --namespace minibroker minibroker/minibroker --set "deployServiceCatalog=false" --set "defaultNamespace=minibroker"
```
**REMARK**: If minibroker will be used with CF, then use the following [instructions](https://github.com/kubernetes-sigs/minibroker#usage-with-cloud-foundry)

- To play with CF and minibroker - see [here](https://github.com/kubernetes-sigs/minibroker#usage)
- Register the broker
```bash
cf create-service-broker minibroker user pass http://minibroker-minibroker.minibroker.svc.cluster.local
```
- Enable the needed services
```bash
cf service-access
cf enable-service-access mysql
cf enable-service-access redis
cf enable-service-access mongodb
cf enable-service-access mariadb
cf enable-service-access postgresql
```
- Create the `postgresql-svc` service. Pass as parameter the tags `postgres, postgresql` and database name
```bash
$ cf create-service postgresql 11-6-0 postgresql-svc -t "postgres,postgresql" -c '{"postgresDatabase":"music"}'
```

- or do the same using `mysql` if you prefer
```bash
$ cf create-service mysql 5-7-28 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
```

- Check the status of the service created
```bash
cf service postgresql-svc
Showing info of service postgresql-svc in org redhat.com / space demo as admin...

name:             postgresql-svc
service:          postgresql
tags:             postgres, postgresql
plan:             11-6-0
description:      Helm Chart for postgresql
documentation:
dashboard:
service broker:   minibroker

Showing status of last operation from service postgresql-svc...

status:    create succeeded
message:   service instance "4538ba15-7b6d-4693-bfe5-e9979d655eea" provisioned
started:   2020-04-23T15:53:53Z
updated:   2020-04-23T15:54:56Z

There are no bound apps for this service.

Upgrades are not supported by this broker.
```

- Verify the ENV VAR VCAP
```bash
cf env spring-music
Getting env variables for app spring-music2 in org redhat.com / space demo as admin...
OK

System-Provided:
{
 "VCAP_SERVICES": {
  "postgresql": [
   {
    "binding_name": null,
    "credentials": {
     "Protocol": "tcp-postgresql",
     "host": "peeking-goose-postgresql.minibroker.svc.cluster.local",
     "password": "87ElH9HEWG",
     "port": 5432,
     "postgresql-password": "87ElH9HEWG",
     "uri": "tcp-postgresql://postgres:87ElH9HEWG@peeking-goose-postgresql.minibroker.svc.cluster.local:5432/music",
     "username": "postgres"
    },
    "instance_name": "postgresql-svc",
    "label": "postgresql",
    "name": "postgresql-svc",
    "plan": "11-6-0",
    "provider": null,
    "syslog_drain_url": null,
    "tags": [
     "postgresql",
     "postgres",
     "database",
     "sql"
    ],
    "volume_mounts": []
   }
  ]
 }
}

{
 "VCAP_APPLICATION": {
  "application_id": "3a68fcb1-737c-4a1b-9e1b-0867ca012e52",
  "application_name": "spring-music",
  "application_uris": [
   "spring-music2.95.217.161.67.nip.io"
  ],
  "application_version": "7dc81a59-7676-479f-96ae-fe7ccaf450f2",
  "cf_api": "https://api.95.217.161.67.nip.io",
  "limits": {
   "disk": 1024,
   "fds": 16384,
   "mem": 1024
  },
  "name": "spring-music",
  "organization_id": "8c48a272-9c9c-4e4c-bd1a-8dc7891a1e38",
  "organization_name": "redhat.com",
  "process_id": "3a68fcb1-737c-4a1b-9e1b-0867ca012e52",
  "process_type": "web",
  "space_id": "2ba1ccf8-7f6d-4e06-86fb-7a535a8b7c45",
  "space_name": "demo",
  "uris": [
   "spring-music2.95.217.161.67.nip.io"
  ],
  "users": null,
  "version": "7dc81a59-7676-479f-96ae-fe7ccaf450f2"
 }
}

User-Provided:
SPRING_PROFILES_ACTIVE: postgres

No running env variables have been set

No staging env variables have been set
``` 
- Bind it to your application
```bash
cf bind-service spring-music postgresql-svc
Binding service postgresql-svc to app spring-music in org redhat.com / space demo as admin...
OK

TIP: Use 'cf restage spring-music' to ensure your env variable changes take effect
cf restage spring-music
```
- Change the active profile to `postgres` and restage
```bash
cf set-env spring-music SPRING_PROFILES_ACTIVE postgres
cf restage spring-music
```

- All commands using mysql
```bash
cf unbind-service spring-music mysql-svc
cf delete-service mysql-svc -f
cf delete spring-music -f
cf create-service mysql 5-7-28 mysql-svc -t "mysql" -c '{"mysqlDatabase":"music"}'
cf push spring-music -o cmoulliard/spring-music-app
cf set-env spring-music SPRING_PROFILES_ACTIVE mysql
cf bind-service spring-music mysql-svc
cf restage spring-music
```

**IMPORTANT**: If you prefer to use `cups` to define a user provided service, then use the following commands
```bash
cf cups my-postgresql-db -p '{ "uri" : "postgres://postgres:@interesting-orangutan-postgresql.minibroker.svc.cluster.local:5432/music", "username" : "postgres", "password" : "nFONm5TYFK" }'
cf bind-service spring-music my-postgresql-db
cf restage spring-music
cf logs spring-music --recent
```

- Open the application at the following address: `http://spring-music.95.217.161.67.nip.io/`

## Install the Kubernetes Service Catalog

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
kc edit ClusterServiceBroker/automation-broker
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
cat << _EOF_ > apb_postgresql_pod.yml
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
  namespace: demo
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
    image: docker.io/ansibleplaybookbundle/postgresql-apb:latest
    imagePullPolicy: IfNotPresent
    name: apb
    resources: {}
    terminationMessagePath: /dev/termination-log
_EOF_
```
- Deploy the workaround
```bash
kc apply -f apb_postgresql_pod.yml
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
