## Overlay kpack release file

To allow kpack to handle https query to a private container registry, it is needed to mount as
a secret the self signed certificate of the registry from a secret and set up the env var `SSL_CERT_DIR`
to include it.
Using `ytt` tool and `overlay` strategy will allow to pack the `Deployment` resource of the `kpack-controller`

```bash
ytt -f add_all.yml -f release-0.2.2.yaml > manifest.yml
```