## Create a builder

```yaml
pack create-builder my-builder:bionic --builder-config ./builder.toml

or

./create-builder.sh
```

## To test it
```bash
git clone https://github.com/cloudfoundry-samples/spring-music && cd spring-music
pack build cmoulliard/spring-boot-music-app --builder cmoulliard/paketo-spring-boot-builder:latest --env 'BP_BUILT_ARTIFACT=build/libs/spring-music-*.jar'
```