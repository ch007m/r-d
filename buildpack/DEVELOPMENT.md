## Snapshot Lifecycle build

To be able to use a new version of the `lifecycle` which is not yet released on https://github.com/buildpacks/lifecycle/releases
it is needed to build it locally using the following make command:

```bash
make clean build-linux-amd64 package-linux-amd64
```
**REMARK**: The rule `` is needed as it will include the `lifecycle.tpoml` descriptor and will generate an archive file containing the resources

Next, create a new builder image (or extend an existing) to package the snapshot build of the lifecycle. 

This can be achieved using two different approaches where we re-build a new builder image or extend an existing to override the lifecycle packaged within the image

1. Extend a builder image

From your terminal, move to the `out` directory of the lifecycle project which contains the compiled version of the lifecycle and 
create a new image

```bash
pushd $HOME/code/cncf/lifecycle/out/linux-amd64
SNAPSHOT_LIFECYCLE_VERSION="v0.12.0-SNAPSHOT-919b8add"

cat << EOF > Dockerfile
FROM redhat/buildpacks-builder-quarkus-jvm
COPY ./lifecycle /cnb/lifecycle
EOF
docker build -t builder-quarkus:$SNAPSHOT_LIFECYCLE_VERSION .
popd
```

To include the `hook` or `extension` content, it will be needed to also copy the resources located here:
```bash
FROM existing-builder COPY ./cnb/ext /cnb/ext
```

Next, check the if the lifecycle packaged is the proper one
```bash
$ docker run --rm -it builder-quarkus:$SNAPSHOT_LIFECYCLE_VERSION /cnb/lifecycle/creator -version
0.12.0-rc.1-4+919b8add
```

2 Build a new builder image

For that purpose, edit the `builder.toml` file of your builder project to specify using the `uri` variable, the path of the lifecycle archive

```toml
[lifecycle]
uri = "file:///$HOME/code/cncf/lifecycle/out/lifecycle-v0.12.0-rc.1-4+919b8add+linux.x86-64.tgz"
```

Example of command executed 
```bash
$ pack builder create redhat/buildpacks-builder-quarkus:latest --config ${builder_dir}/builder.toml -v

To check/verify the version packaged: 

```bash
$ docker run --rm -it redhat/buildpacks-builder-quarkus-jvm /cnb/lifecycle/creator -version
0.12.0-rc.1-4+919b8add
```

**Issue**: It is not possible using the current version of `pack builder` to provide as lifecycle uri an image (e.g uri = "buildpacksio/lifecycle:919b8ad-linux-arm64") 