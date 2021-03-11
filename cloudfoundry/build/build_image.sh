REGISTRY_ADDRESS=kube-registry.infra.svc
REGISTRY_PROTOCOL=https
REGISTRY_PREFIX=cmoulliard
USER=admin
PASSWORD=snowdrop

echo "IMPORTANT: Copy the self signed cert here please using the name : server.crt !!!!! before to launch the script"

pushd cert-injection-webhook
pack build $REGISTRY_PREFIX/my-setup-ca-certs  \
    -e BP_GO_TARGETS="./cmd/setup-ca-certs"  \
    --publish  \
    --builder paketobuildpacks/builder:base
pack build $REGISTRY_PREFIX/my-cert-webhook  \
     -e BP_GO_TARGETS="./cmd/pod-webhook"  \
     --publish

ytt -f ./deployments/k8s \
      -v pod_webhook_image=$REGISTRY_PREFIX/my-cert-webhook \
      -v setup_ca_certs_image=$REGISTRY_PREFIX/my-setup-ca-certs \
      --data-value-file ca_cert_data=../server.crt \
      --data-value-yaml annotations="[kpack.io/build]" \
      > manifest.yaml

kapp delete -a cert-injection-webhook -y
kapp deploy -a cert-injection-webhook -f ./manifest.yaml -y
popd

echo "Run the k8s cmds"
rm -f release-0.2.2.yaml && wget https://github.com/pivotal/kpack/releases/download/v0.2.2/release-0.2.2.yaml

kubectl delete -f release-0.2.2.yaml
kubectl apply -f release-0.2.2.yaml --validate=false

cat <<EOF | kubectl apply -n kpack -f -
apiVersion: v1
kind: Secret
metadata:
  name: cert-key
type: Opaque
data:
  server-key.pem: LS0tLS1CRUdJTiBFQyBQUklWQVRFIEtFWS0tLS0tCk1IY0NBUUVFSUw2VDRMNWtFT29RUXZBd2t5OEJIb1AySSsrTEtpSVBVZEF1MSsyb1hsWG9vQW9HQ0NxR1NNNDkKQXdFSG9VUURRZ0FFZkk5TCtwSlNVTjJkY2ovRlc4dnRGUHBmUG96T2VLT3lRZXBmeEorZEFJcTFJWllBdDF0MApGcWo1Q09ScFBSUUNmampvempRNDBxOXZBdlZpeUYzL0dnPT0KLS0tLS1FTkQgRUMgUFJJVkFURSBLRVktLS0tLQo=
  server.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURGakNDQWY2Z0F3SUJBZ0lRUUdMR0hDall0d1FIR1hPaVlFdHozakFOQmdrcWhraUc5dzBCQVFzRkFEQVYKTVJNd0VRWURWUVFERXdwcmRXSmxjbTVsZEdWek1CNFhEVEl4TURNd09ERXpNalF4TkZvWERUSXlNRE13T0RFegpNalF4TkZvd2VURUxNQWtHQTFVRUJoTUNRa1V4RGpBTUJnTlZCQWdUQlU1aGJYVnlNUkl3RUFZRFZRUUhFd2xHCmJHOXlaVzV1WlhNeEd6QVpCZ05WQkFvVEVsSmxaQ0JJWVhRZ1RXbGtaR3hsZDJGeVpURVJNQThHQTFVRUN4TUkKVTI1dmQyUnliM0F4RmpBVUJnTlZCQU1URFd0MVltVXRjbVZuYVhOMGNua3dXVEFUQmdjcWhrak9QUUlCQmdncQpoa2pPUFFNQkJ3TkNBQVI4ajB2NmtsSlEzWjF5UDhWYnkrMFUrbDgrak01NG83SkI2bC9FbjUwQWlyVWhsZ0MzClczUVdxUGtJNUdrOUZBSitPT2pPTkRqU3IyOEM5V0xJWGY4YW80SElNSUhGTUE0R0ExVWREd0VCL3dRRUF3SUYKb0RBVEJnTlZIU1VFRERBS0JnZ3JCZ0VGQlFjREFUQU1CZ05WSFJNQkFmOEVBakFBTUlHUEJnTlZIUkVFZ1ljdwpnWVNDRjJ0MVltVXRjbVZuYVhOMGNua3VhVzVtY21FdWMzWmpnaDlyZFdKbExYSmxaMmx6ZEhKNUxtbHVabkpoCkxuTjJZeTVqYkhWemRHVnlnaVZyZFdKbExYSmxaMmx6ZEhKNUxtbHVabkpoTG5OMll5NWpiSFZ6ZEdWeUxteHYKWTJGc2doVTVOUzR5TVRjdU1UVTVMakkwTkM1dWFYQXVhVytIQkYvWm4vU0hCQXBpd0ZBd0RRWUpLb1pJaHZjTgpBUUVMQlFBRGdnRUJBSFNSMUJwcWZrQzJHUlFuMUFoRFlibDJNZXpCNHVqdDNERS8xSjlJdVFWR0VCTWRxSnEyClNSdEw0ZVVrKzVIL2J0OXdIVWc2MHZibnVQTHNBcURxejBDclZPeHJPZUZwdlJ0MXRyejFLR0RzVUlnbHBUUlIKVE9pWUhBQmRVYkdINUJhMEt1T01aWW10SEpwODBzbUVCcUFzcExCQVNIakEvOHVWbE9JYnlnTjRkSzUvUVROcQo2VWRNK1dNTVMrSzdQd0g3R0dlOHgxR0o3WHRZVVd4RFE4QmdycWtmUEFwM25TY201R1VId3ZIR3ZJZGg5cTZ4CnBFS201ejhmaDJwMFdyWXRPbXhRTmFaUHlwd0lGTmZETEYxeXBYdVkweHd0SlNvNXF3RHV6V3hsbEZmNSs3N2YKZkRJSzBvb2pPMXFES3c5ZlZraSt6b2E4V0pGbXN1NEJLWEU9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0KLS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUN5RENDQWJDZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeE1ETXdPREE1TWpjME1Gb1hEVE14TURNd05qQTVNamMwTUZvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBTHhOCnVFSUc4TmtUV2MreHpFWFA4ZnpSSHNSQXBTOWdvRVBFYTVZYzk3bDNXZGcxbWErQ1ZVTlEzU1hqY0pUVkl3dEMKcHJ6OThKQjVhZHRRQ3JNUDZsOG5oQTJCWUowZUlneXZONTV0S0d6SmRJb3F0dFliUlVuK0V5dTNZUU1MU3ZveQpXUWRCelRkbUMraXV6dHZXY1MzM1dLdEczcHF2OU52d0Jxd3VEbDVIQ3NZWHFQWE9YeWFKY1gyd0JaSldWdEpsCjZlUS9pTDc3aDY3Ujhkd3J5enVwa2pzalV3SzBwZ2N0Z25HeC80S0c2YUJyeFhleWdmUUg5NEkxTjAzRHZpY2kKOEpIb2Mra3JUL3EyMWtqaUJEYXZ0UWQrNkkrRkNsZ3pybzZ3YWl0bFVHeWYrSjB3cjdMQmxzQUxtU05ZeFZHLwp3RWtlajc3RHdzbWVlM0dNSHNzQ0F3RUFBYU1qTUNFd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFKb2kxOXQ2YW1kNzFidkRJYmIyeUNHeGtvdVIKb0dZd2hxU3Z6Z0hQRmZuMSt2ckd1a1R5U3hjSTZsaGwrN0JjaVpkL1oramtVQ01xNDBHT1huV0N5QWE5SHBRQgoyWkdsZEhRdUplRnpJeTAxZUVMNUlDU3dMY2NDYzJtM2p3NmRVYnRnbldoUS9BalVZZno1OGZsTWFLUWhQbldqCkpmd1pSVW1rRm5jY25MR3ZPQzQxcTk2Zk9BazA5bWFiajlTZlduVEoydnBxdGJnTVRBTklVQjVtVkVZN3kzYXUKbG0zRjNFSGI2dkZLYklQcGVnSVZTWm1pV1dQNjVoZ2dUSFBnSmxCTkg1alBlRFdTSXk3bFBEMG9KREFvem1qZApzNGx0UlpyejNlZHdsR1U0SHNMc0dzeHZCNGJ3Yk16dkxDMHZEeFNtV1V3N085bXRONkowOHpkZWt1ST0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
EOF

kubectl delete deployment/kpack-controller -n kpack
cat <<EOF | kubectl apply -n kpack -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kpack-controller
  namespace: kpack
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kpack-controller
  template:
    metadata:
      labels:
        app: kpack-controller
        version: 0.2.2-rc.1
    spec:
      serviceAccountName: controller
      nodeSelector:
        kubernetes.io/os: linux
      volumes:
        - name: custom-certs
          secret:
            secretName: cert-key
      containers:
        - name: controller
          image: gcr.io/cf-build-service-public/kpack/controller@sha256:ec256da7e29eeecdd0821f499e754080672db8f0bc521b2fa1f13f6a75a04835
          volumeMounts:
            - name: custom-certs
              mountPath: /certs
          env:
            - name: SSL_CERT_DIR
              value: /certs
            - name: CONFIG_LOGGING_NAME
              value: config-logging
            - name: CONFIG_OBSERVABILITY_NAME
              value: config-observability
            - name: METRICS_DOMAIN
              value: kpack.io
            - name: SYSTEM_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: BUILD_INIT_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: build-init-image
                  key: image
            - name: BUILD_INIT_WINDOWS_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: build-init-windows-image
                  key: image
            - name: REBASE_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: rebase-image
                  key: image
            - name: COMPLETION_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: completion-image
                  key: image
            - name: COMPLETION_WINDOWS_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: completion-windows-image
                  key: image
            - name: LIFECYCLE_IMAGE
              valueFrom:
                configMapKeyRef:
                  name: lifecycle-image
                  key: image
          resources:
            requests:
              cpu: 20m
              memory: 100Mi
            limits:
              cpu: 100m
              memory: 400Mi
EOF

kubectl delete ClusterStore/default
cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: ClusterStore
metadata:
  name: default
spec:
  sources:
  - image: gcr.io/paketo-buildpacks/java
EOF

kubectl delete ClusterStack/base
cat <<EOF | kubectl apply -f -
apiVersion: kpack.io/v1alpha1
kind: ClusterStack
metadata:
  name: base
spec:
  id: "io.buildpacks.stacks.bionic"
  buildImage:
    image: "paketobuildpacks/build:base-cnb"
  runImage:
    image: "paketobuildpacks/run:base-cnb"
EOF

kubectl create ns demo

kubectl delete sa/tutorial-service-account -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tutorial-service-account
secrets:
- name: tutorial-registry-credentials
imagePullSecrets:
- name: tutorial-registry-credentials
EOF

kubectl delete secret/tutorial-registry-credentials -n demo
kubectl create secret docker-registry tutorial-registry-credentials \
     --docker-username=$USER \
     --docker-password=$PASSWORD\
     --docker-server=$REGISTRY_PROTOCOL://$REGISTRY_ADDRESS:5000/\
     -n demo

kubectl delete builder/my-builder -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: kpack.io/v1alpha1
kind: Builder
metadata:
  annotations:
    kpack.io/build: cert
  name: my-builder
spec:
  serviceAccount: tutorial-service-account
  tag: $REGISTRY_ADDRESS:5000/demo/default-builder
  stack:
    name: base
    kind: ClusterStack
  store:
    name: default
    kind: ClusterStore
  order:
  - group:
    - id: paketo-buildpacks/java
EOF

kubectl delete image/tutorial-image -n demo
cat <<EOF | kubectl apply -n demo -f -
apiVersion: kpack.io/v1alpha1
kind: Image
metadata:
  annotations:
    kpack.io/build: cert
  name: tutorial-image
spec:
  tag: $REGISTRY_ADDRESS:5000/tutorial
  serviceAccount: tutorial-service-account
  builder:
    name: my-builder
    kind: Builder
  source:
    git:
      url: https://github.com/spring-projects/spring-petclinic
      revision: master
EOF