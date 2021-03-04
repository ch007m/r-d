## Create K8s cluster using Ansible

### Prerequisite
- `hcloud` client is needed
  `brew install hcloud`
- Configure the `snowdrop` context
  ```bash
  hcloud context create snowdrop
  $token: <HETZNER_API_TOKEN>
  ```

### How to create the VM
- Create a VM on Hetzner & deploy a k8s cluster
```bash
pushd ~/code/snowdrop/infra-jobs-productization/k8s-infra
export k8s_version=118
export VM_NAME=h01-${k8s_version}
export PASSWORD_STORE_DIR=~/.password-store-snowdrop
ansible-playbook hetzner/ansible/hetzner-delete-server.yml -e vm_name=${VM_NAME} -e hetzner_context_name=snowdrop
ansible-playbook ansible/playbook/passstore_controller_inventory_remove.yml -e vm_name=${VM_NAME} -e pass_provider=hetzner
ansible-playbook ansible/playbook/passstore_controller_inventory.yml -e vm_name=${VM_NAME} -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version} -e operation=create
ansible-playbook hetzner/ansible/hetzner-create-server.yml -e vm_name=${VM_NAME} -e salt_text=$(gpg --gen-random --armor 1 20) -e hetzner_context_name=snowdrop -e pass_provider=hetzner -e k8s_type=masters -e k8s_version=${k8s_version}
ansible-playbook ansible/playbook/sec_host.yml -e vm_name=${VM_NAME} -e provider=hetzner
ansible-playbook kubernetes/ansible/k8s.yml --limit ${VM_NAME}
popd

ok: [h01-118] => {
    "msg": [
        "You can also view the kubernetes dashboard at",
        "https://k8s-console.95.217.159.244.nip.io/",
        "",
        "Using the Boot Token: ",
        "k3hxzh.p5kiogsey4hnccpv"
    ]
}

```

- SSH to the VM
```bash
ssh-hetznerc ${VM_NAME}
```

- Add missing PV
```bash
mkdir /tmp/pv00{6,7,8,9,10,11}
sudo chown -R 1001:1001 /tmp
sudo chmod -R 700 /tmp

create_pv() {
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0$1
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: $2Gi
  hostPath:
    path: /tmp/pv0$1
    type: ""
  persistentVolumeReclaimPolicy: Recycle
  volumeMode: Filesystem
EOF
}

create_pv 06 20
create_pv 07 20
create_pv 08 20
create_pv 09 100
create_pv 10 8
create_pv 11 8
```
- Patch the dashboard service to use the external IP address
```bash
IP=<IP_ADDRESS_OF_THE_VM>
kubectl patch svc kubernetes-dashboard -n kubernetes-dashboard -p '{"spec":{"externalIPs":["$IP"]}}'
```