### Setup
```shell
curl -LO --output-dir bin https://github.com/nulib-labs/fcrepo-export-stream/releases/download/v0.1.0/fcrepo_export
curl -LO --output-dir bin https://github.com/fcrepo-exts/fcrepo-import-export/releases/download/fcrepo-import-export-0.3.0/fcrepo-import-export-0.3.0.jar
export DOMAIN=rdc-staging.library.northwestern.edu
export FEDORA_SOURCE=http://fcrepo.internal.${DOMAIN}:8080
export NETID=<your NetID>
export FEDORA_DEST=http://localhost:8080
export ENVIRONMENT=prod
```

### Export
```shell
ssh -fND 8123 ${NETID}@bastion.stack.${DOMAIN}
export ALL_PROXY=socks5h://localhost:8123

./bin/fcrepo_export -r $FEDORA_BASE/rest/avr -d data/${ENVIRONMENT}/fcrepo4.7.5_export

unset ALL_PROXY
pkill -f "ssh -fND"
```

### Import
```shell
java -jar bin/fcrepo-import-export-0.3.0.jar \
  --dir=data/${ENVIRONMENT}/fcrepo4.7.5_migrate --user=fedoraAdmin:fedoraAdmin \
  --mode=import -M $FEDORA_SOURCE,$FEDORA_DEST \
  --resource=$FEDORA_DEST/rest/avr --binaries
```
