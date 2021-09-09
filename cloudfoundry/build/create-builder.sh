#!/usr/bin/env bash

rm -rf paketo

pushd
buildpack=spring-boot
version=v1.5.1
mkdir -p paketo/${buildpack}
curl -Ls https://github.com/paketo-buildpacks/${buildpack}/archive/${version}.tar.gz | tar -x --strip-components=1 -C paketo/${buildpack} -z -f -
sed -i -e "s/{{\s*\.version}}/${version}/g" paketo/${buildpack}/buildpack.toml
cd paketo/${buildpack}
./scripts/build.sh
popd

pushd
buildpack=adopt-openjdk
version=v2.2.1

mkdir -p paketo/${buildpack}
curl -Ls https://github.com/paketo-buildpacks/${buildpack}/archive/${version}.tar.gz | tar -x --strip-components=1 -C paketo/${buildpack} -z -f -
sed -i -e "s/{{\s*\.version}}/${version}/g" paketo/${buildpack}/buildpack.toml
cd paketo/${buildpack}
./scripts/build.sh
popd

pack create-builder cmoulliard/snowdrop-spring-boot-builder --builder-config builder.toml --publish
