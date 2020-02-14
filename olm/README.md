# OLM on k8s

The following document details the steps to follow to install the Operator Lifecycle Manager - `OLM` on a kubernetes cluster. 
The `OLM` manages different CRDs: `ClusterServiceVersion`, `InstallPlan`, `Subscription` and `OperatorGroup` which are used
to install an Operator using a subscription from a catalog.

The `CatalogSource` CRD allows to specify an external registry to poll the operators published on `quay.io` as a collection of packages/bundles.

More information is available at this [address](https://github.com/operator-framework/community-operators/blob/master/docs/testing-operators.md#testing-operator-deployment-on-kubernetes)

## Instructions

- Have access as `cluster-admin` to a k8s cluster
- Execute the following bash script to install the 2 operators managed by the Operator Lifecycle Manager: olm and catalog operator like also the different CRDs
```bash
./olm.sh 0.14.1
```
**REMARK**: The script will remove the image of the `catalogSource` deployed by default from `operatorhub` as we will install the `Openshift Operators catalog` !

# Install additional catalogs of operators

It is possible to install additional `Catalog(s)` of `operators` if you deploy top of a cluster the `Operator-marketplace`. This operator allows to fetch from an external repository
called an `operatorsource`, the metadata of the registry containing your operator packaged as a bundle or `upstream`, `community` or `certified operators.

This operator manages 2 CRDs: the `OperatorSource` and `CatalogSourceConfig`. The `OperatorSource` defines the external datastore that we are using to store operator bundles.
The `CatalogSourceConfig` is used to create an `OLM CatalogSource` consisting of operators from one `OperatorSource` so that these operators can then be managed by `OLM`.

**Note**: The upstream community operators are packaged on `quay.io` as a `application registry` containing a collection of `bundles` including the :
- CRDs
- Package definition and 
- ClusterServiceVersion
  
## Instructions

- Install the `Operator Marketplace` and the associated CRDs
```bash
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/01_namespace.yaml
kubectl apply --validate=false -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/02_catalogsourceconfig.crd.yaml
kubectl apply --validate=false -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/03_operatorsource.crd.yaml
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/04_service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/05_role.yaml
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/06_role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/upstream/08_operator.yaml
```

- Deploy the `OperatorSource` which points to the quay registry containing the `Openshift Operators`
```bash
kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-marketplace/master/deploy/examples/community.operatorsource.cr.yaml -n marketplace
```

- Next, verify if a `CatalogSource` has been created. This `catalogSource` contains the information needed to create a local `grpc` server 
```bash
kubectl get catalogsource -n marketplace        
NAME                  DISPLAY               TYPE   PUBLISHER   AGE
community-operators   Community Operators   grpc   Red Hat     72s
```

- Once the `OperatorSource` and `CatalogSource` are deployed, the following command can be used to list of the available operators specified with the field `.status.packages`:
```bash
kubectl get opsrc community-operators -n marketplace -o=custom-columns=NAME:.metadata.name,PACKAGES:.status.packages
NAME                  PACKAGES
community-operators   prometheus,planetscale,eclipse-che,t8c,3scale-community-operator,halkyon,submariner,keycloak-operator,api-operator,descheduler,spark-gcp,infinispan,opendatahub-operator,radanalytics-spark,argocd-operator-helm,myvirtualdirectory,openshift-pipelines-operator,kubeturbo,teiid,quay,ibm-spectrum-scale-csi-operator,special-resource-operator,postgresql,strimzi-kafka-operator,microcks,hazelcast-enterprise,kogito-operator,triggermesh,maistraoperator,lib-bucket-provisioner,ripsaw,esindex-operator,hawtio-operator,postgresql-operator-dev4devs-com,smartgateway-operator,resource-locker-operator,metering,opsmx-spinnaker-operator,knative-kafka-operator,composable-operator,etcd,cockroachdb,codeready-toolchain-operator,neuvector-community-operator,knative-eventing-operator,grafana-operator,kubefed,container-security-operator,multicloud-operators-subscription,apicast-community-operator,seldon-operator,open-liberty,akka-cluster-operator,iot-simulator,lightbend-console-operator,nexus-operator-hub,jenkins-operator,cert-utils-operator,syndesis,kiali,service-binding-operator,hyperfoil-bundle,must-gather-operator,twistlock,enmasse,jaeger,camel-k,node-problem-detector,knative-camel-operator,ibmcloud-operator,openebs,kubestone,traefikee-operator,aqua,spinnaker-operator,atlasmap-operator,apicurito,namespace-configuration-operator,federation,federatorai,microsegmentation-operator,awss3-operator-registry,event-streams-topic,ember-csi-operator
```
**NOTE**: The list of the packages can also be displayed using the following command : 
```bash
kubectl get packagemanifests -n marketplace
NAME                                CATALOG               AGE
argocd-operator-helm                Community Operators   5m19s
awss3-operator-registry             Community Operators   5m19s
myvirtualdirectory                  Community Operators   5m19s
opsmx-spinnaker-operator            Community Operators   5m19s
lightbend-console-operator          Community Operators   5m19s
...
```

## Deploy an OpenShift Operator using a subscription

- In order to install an operator, it is needed to have an `OperatorGroup` resource to define
```bash
kubectl apply -f resources/operator-group.yml -n marketplace
```

- To install the `openshift-pipelines-operator` operator, create a subscription and deploy it
```bash
kubectl apply -f resources/tekton-subscription.yml -n marketplace
```

- Check the status of the `ClusterServiceVersion` created using the following command:
```bash
kubectl get csv -n marketplace
NAME                                   DISPLAY                        VERSION   REPLACES   PHASE
openshift-pipelines-operator.v0.10.4   OpenShift Pipelines Operator   0.10.4               Installing
```

## Using new operator registry

More information about how to use the commands is available [here](https://github.com/operator-framework/operator-registry/tree/master/docs/design)

- Steps to follow to create a bundle using the new Bundle format of an operator and publish it on quay
```bash
cd /Users/dabou/Code/github/operator-registry
indexImage=quay.io/cmoulliard/olm-index:0.1.0
bundleImage=quay.io/cmoulliard/olm-prometheus:0.22.2
db=bin/local-registry.db

./bin/opm alpha bundle build -t ${bundleImage} -p prometheus -c preview -e preview -d bin/manifests/prometheus/
./bin/opm alpha bundle validate -t ${bundleImage} -b docker
docker push  quay.io/cmoulliard/olm-prometheus:0.22.2
```

- To add the bundle previsouly created to an index database
```bash
./bin/opm index add -b ${bundleImage} -t ${indexImage} -c docker --permissive
docker push quay.io/cmoulliard/olm-index:0.1.0
```

- To validate the bundle
```bash
./bin/opm alpha bundle validate -t ${bundleImage} -b docker
```
- To add the bundle to a local DB and exoport the content of the bundle
```bash
./bin/opm registry add -b ${bundleImage} -d ${db} -c docker  --permissive
./bin/opm index export --index=${indexImage} -o prometheus -c docker
```

- To play locally with the registry
```bash
./bin/opm registry serve -d ${db} -p 50052
grpcurl -plaintext localhost:50052 list api.Registry
grpcurl -plaintext localhost:50052 api.Registry/ListPackages
{
  "name": "prometheus"
}
 grpcurl -plaintext -d '{"name":"prometheus"}' localhost:50052 api.Registry/GetPackage
{
  "name": "prometheus",
  "channels": [
    {
      "name": "preview",
      "csvName": "prometheusoperator.0.32.0"
    }
  ],
  "defaultChannelName": "preview"
}
grpcurl -plaintext -d '{"pkgName":"prometheus","channelName":"preview"}' localhost:50052 api.Registry/GetBundleForChannel > result.json
```