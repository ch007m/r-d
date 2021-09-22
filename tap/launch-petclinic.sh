export KUBECONFIG=$HOME/.kube/h01-121
export VM_IP=95.217.159.244
export NAMESPACE="tap-install"
export APPLICATION="petclinic"

export UI_NODE_PORT=$(kubectl get svc/acc-ui-server -n accelerator-system -o jsonpath='{.spec.ports[0].nodePort}')
echo "Accelerator UI: http://$VM_IP:$UI_NODE_PORT"
open -na "Google Chrome" --args --incognito http://$VM_IP:$UI_NODE_PORT

export LIVE_NODE_PORT=$(kubectl get svc/application-live-view-5112 -n $NAMESPACE -o jsonpath='{.spec.ports[0].nodePort}')
echo "Live view: http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps"
open -na "Google Chrome" --args --incognito http://$VM_IP.nip.io:$LIVE_NODE_PORT/apps

export ENVOY_NODE_PORT=$(kubectl get svc/envoy -n contour-external -o jsonpath='{.spec.ports[0].nodePort}')
echo "Petclinic demo: http://$APPLICATION.$NAMESPACE.$VM_IP.nip.io:$ENVOY_NODE_PORT"
open -na "Google Chrome" --args --incognito http://$APPLICATION.$NAMESPACE.$VM_IP.nip.io:$ENVOY_NODE_PORT