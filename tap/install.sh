
KUBE_CFG_FILE=${1:-config}
export KUBECONFIG=$HOME/.kube/${KUBE_CFG_FILE}

TANZU_TEMP_DIR="./tanzu"

VM_IP=${VM_IP:-"<CHANGE_ME>"}
REGISTRY_HOSTNAME_OR_IP=${REGISTRY_HOSTNAME_OR_IP:-"<CHANGE_ME>"}
REGISTRY_PORT=${REGISTRY_PORT:-"<CHANGE_ME>"}
REGISTRY_SERVER=$REGISTRY_HOSTNAME_OR_IP:$REGISTRY_PORT
REGISTRY_USERNAME=${REGISTRY_USERNAME:-"<CHANGE_ME>"}
REGISTRY_PASSWORD=${REGISTRY_PASSWORD:-"<CHANGE_ME>"}

CERT_PATH=${CERT_PATH:-"<CHANGE_ME>"}

TANZU_REG_USERNAME=${TANZU_REG_USERNAME:-"<CHANGE_ME>"}
TANZU_REG_PASSWORD=${TANZU_REG_PASSWORD:-"<CHANGE_ME>"}

TANZU_PACKAGES_VERSION="0.2.0"

TANZU_FLUX_VERSION="v0.15.4"
TANZU_KAPP_VERSION="v0.27.0"
TANZU_SECRET_CONTROLLER="v0.5.0"

TANZU_TAP_CLOUD_NATIVE_RUNTIMES_VERSION="1.0.2"
TANZU_TAP_APP_ACCELERATOR_VERSION="0.3.0"
TANZU_TAP_APP_LIVE_VIEW_VERSION="0.2.0"
TANZU_TAP_CONVENTION_SERVICE="0.4.2"
TANZU_TAP_SOURCE_CONTROLLER="0.1.2"
TANZU_TAP_BUILD_SERVICE_VERSION="1.3.0"
TANZU_TAP_CARTOGRAPHER="0.0.6"
TANZU_TAP_DEFAULT_SUPPLY_CHAIN="0.2.0"
TANZU_TAP_DEVELOPER_CONVENTION="0.2.0"
TANZU_TAP_SERVICE_BINDING="0.5.0"
TANZU_TAP_SC_SECURITY_STORE="1.0.0-beta.0"
TANZU_TAP_SC_SECURITY_SCAN="1.0.0-beta.0"
TANZU_TAP_API_PORTAL="1.0.2"
TANZU_TAP_SCP_TOOLKIT="0.3.0"

DEMO_WORKSPACE_NAME="demo"

CERT_MANAGER="v1.5.3"

function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}

echo "### Create tanzu directory ####"
if [ ! -d $TANZU_TEMP_DIR ]; then
    mkdir -p $TANZU_TEMP_DIR
fi

pushd $TANZU_TEMP_DIR

# Install the needed components: kapp controller, secretgen, cert-manager, fluxcd
kapp deploy -a cert-manager -f https://github.com/jetstack/cert-manager/releases/download/$CERT_MANAGER/cert-manager.yaml -y

kapp deploy -a kc -f https://github.com/vmware-tanzu/carvel-kapp-controller/releases/download/$TANZU_KAPP_VERSION/release.yml -y
sleep 1m
kapp deploy -a sg -f https://github.com/vmware-tanzu/carvel-secretgen-controller/releases/download/$TANZU_SECRET_CONTROLLER/release.yml -y

kubectl create namespace flux-system
kubectl create clusterrolebinding default-admin \
        --clusterrole=cluster-admin \
        --serviceaccount=flux-system:default
kapp deploy -a flux-source-controller -n flux-system \
   -f https://github.com/fluxcd/source-controller/releases/download/$TANZU_FLUX_VERSION/source-controller.crds.yaml \
   -f https://github.com/fluxcd/source-controller/releases/download/$TANZU_FLUX_VERSION/source-controller.deployment.yaml -y

# Deploy TAP
# Step 1. Create the TAP namespace
kubectl create ns tap-install

# Step 2: Create an imagepullsecret
tanzu imagepullsecret add tap-registry \
  --username $TANZU_REG_USERNAME \
  --password $TANZU_REG_PASSWORD \
  --registry registry.tanzu.vmware.com \
  --export-to-all-namespaces \
  -n tap-install

# Step 3: Add Tanzu Application Platform package repository to the cluster by running:
tanzu package repository add tanzu-tap-repository \
    --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:$TANZU_PACKAGES_VERSION \
    -n tap-install
sleep 2m

# Step 4: Install the Cloud Native Runtimes package
# Get the list of the parameters using: tanzu package available get cnrs.tanzu.vmware.com/$TANZU_TAP_CLOUD_NATIVE_RUNTIMES_VERSION --values-schema -n tap-install
# Create a cnr-values.yaml using the following sample as a guide: https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/0.2/tap-0-2/GUID-install.html#install-cnr
cat <<EOF > cnr.yml
---
provider: local
EOF

tanzu package install cloud-native-runtimes \
   -p cnrs.tanzu.vmware.com \
   -v $TANZU_TAP_CLOUD_NATIVE_RUNTIMES_VERSION \
   -n tap-install \
   -f cnr.yml \
   --poll-timeout 30m

# Step 5: Create a secret containing the dockercfgjson file and mount it to the serviceaccount default of the demo namespace
kubectl create ns $DEMO_WORKSPACE_NAME
kubectl create secret generic pull-secret --from-literal=.dockerconfigjson={} --type=kubernetes.io/dockerconfigjson -n $DEMO_WORKSPACE_NAME
kubectl annotate secret pull-secret secretgen.carvel.dev/image-pull-secret="" -n $DEMO_WORKSPACE_NAME

# Step 6: Configure and install: Application Accelerator
cat <<EOF > app-accelerator.yml
server:
  # Set this service_type to "NodePort" for local clusters like minikube
  service_type: "NodePort"
  watched_namespace: $DEMO_WORKSPACE_NAME
EOF

tanzu package install app-accelerator \
   -p accelerator.apps.tanzu.vmware.com \
   -v $TANZU_TAP_APP_ACCELERATOR_VERSION \
   -n tap-install \
   -f app-accelerator.yml

# Step 7: Install Convention Controller
tanzu package install convention-controller \
    -p controller.conventions.apps.tanzu.vmware.com \
    -v $TANZU_TAP_CONVENTION_SERVICE \
    -n tap-install

# Step 8: Install Source Controller
tanzu package install source-controller \
     -p controller.source.apps.tanzu.vmware.com \
     -v $TANZU_TAP_SOURCE_CONTROLLER \
     -n tap-install

# Step 9: Install TBS
# command to convert the CERT in oneline: awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' cert-name.pem
REG_CERT="$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' $CERT_PATH)"
cat <<EOF > tbs-values.yml
ca_cert_data: "$REG_CERT"
kp_default_repository: $REGISTRY_SERVER/build-service
kp_default_repository_username: $REGISTRY_USERNAME
kp_default_repository_password: $REGISTRY_PASSWORD
tanzunet_username: $TANZU_REG_USERNAME
tanzunet_password: $TANZU_REG_PASSWORD
EOF

tanzu package install tbs \
   -p buildservice.tanzu.vmware.com \
   -v $TANZU_TAP_BUILD_SERVICE_VERSION \
   -n tap-install \
   -f tbs-values.yml \
   --poll-timeout 30m

# Step 10: Install Supply Chain Choreographer
tanzu package install cartographer \
  --package-name cartographer.tanzu.vmware.com \
  --version $TANZU_TAP_CARTOGRAPHER \
  -n tap-install

# Step 11: Install the Default supply chain
# tanzu package available get default-supply-chain.tanzu.vmware.com/0.2.0 --values-schema -n tap-install
cat <<EOF > default-supply-chain-values.yml
---
registry:
  server: $REGISTRY_SERVER
  repository: $DEMO_WORKSPACE_NAME
service_account: default
EOF

tanzu package install default-supply-chain \
 --package-name default-supply-chain.tanzu.vmware.com \
 --version $TANZU_TAP_DEFAULT_SUPPLY_CHAIN \
 --values-file default-supply-chain-values.yml \
 -n tap-install

# Step 12: Install the developer-conventions
tanzu package install developer-conventions \
  --package-name developer-conventions.tanzu.vmware.com \
  --version $TANZU_TAP_DEVELOPER_CONVENTION \
  -n tap-install

# Step 13: Configure and install: Application View
kubectl create ns app-live-view
cat <<EOF > app-live-view.yml
---
connector_namespaces: [default]
server_namespace: app-live-view
EOF

tanzu package install app-live-view \
   -p appliveview.tanzu.vmware.com \
   -v $TANZU_TAP_APP_LIVE_VIEW_VERSION \
   -n tap-install \
   -f ./app-live-view.yml

# Step 14: Install Service Bindings
tanzu package install service-bindings \
    -p service-bindings.labs.vmware.com \
    -v $TANZU_TAP_SERVICE_BINDING \
    -n tap-install

# Step 15: Install Supply Chain Security Tools - Store
# tanzu package available get scst-store.tanzu.vmware.com/1.0.0-beta.0 --values-schema -n tap-install
cat <<EOF > scst-store-values.yml
db_password: "PASSWORD-0123"
db_host: "metadata-store-db"
EOF
tanzu package install metadata-store \
  --package-name scst-store.tanzu.vmware.com \
  --version 1.0.0-beta.0 \
  --namespace tap-install \
  --values-file scst-store-values.yml

# Step 16: Install Supply Chain Security Tools - Sign
# TODO

# Step 17: Install Supply Chain Security Tools - Scan
# TODO

# Step 18: Install the API Portal
# Check the latest release available: tanzu package available list -n tap-install api-portal.tanzu.vmware.com
tanzu package install api-portal \
   -n tap-install \
   -p api-portal.tanzu.vmware.com \
   -v $TANZU_TAP_API_PORTAL

# Step 19: Install Services Control Plane (SCP) Toolkit
# Check the latest release available: tanzu package available list -n tap-install scp-toolkit.tanzu.vmware.com
tanzu package install scp-toolkit \
     -n tap-install \
     -p scp-toolkit.tanzu.vmware.com \
     -v $TANZU_TAP_SCP_TOOLKIT

# Step 20: Check the packages installed
tanzu package installed list -n tap-install

# Step 21: Set Up Developer Namespaces to Use Installed Packages
tanzu imagepullsecret add registry-credentials \
   --registry $REGISTRY_SERVER/ \
   --username $REGISTRY_USERNAME \
   --password $REGISTRY_PASSWORD \
   -n $DEMO_WORKSPACE_NAME

# Add placeholder read secrets, a service account, and RBAC rules to the developer namespace:
cat <<EOF | kubectl -n $DEMO_WORKSPACE_NAME apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default # use value from "Install Default Supply Chain"
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry

---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: kapp-permissions
  annotations:
    kapp.k14s.io/change-group: "role"
rules:
  - apiGroups:
      - servicebinding.io
    resources: ['servicebindings']
    verbs: ['*']
  - apiGroups:
      - serving.knative.dev
    resources: ['services']
    verbs: ['*']
  - apiGroups: [""]
    resources: ['configmaps']
    verbs: ['get', 'watch', 'list', 'create', 'update', 'patch', 'delete']

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kapp-permissions
  annotations:
    kapp.k14s.io/change-rule: "upsert after upserting role"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kapp-permissions
subjects:
  - kind: ServiceAccount
    name: default # use value from "Install Default Supply Chain"
EOF

## Patch the KNative Serving config-domain configmap to expose as domain: <VM_IP>.nip.io
PATCH="{\"data\":{\"$VM_IP.nip.io\": \"\"}}"
kubectl patch cm/config-domain -n knative-serving \
  --type merge \
  -p $PATCH

## Create an ingress rouyte to access the Accelerator UI
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tap-accelerator
  namespace: accelerator-system
spec:
  rules:
    - host: app.$VM_IP.nip.io
      http:
        paths:
          - backend:
              service:
                name: acc-ui-server
                port:
                  number: 8877
            path: /
            pathType: Prefix
EOF
popd
