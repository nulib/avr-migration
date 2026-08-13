# AVR Migration

- `${ENVIRONMENT}`: full name of the environment (`staging` or `production`)
- `${ENV}`: abbreviated name of the environment (`s` or `p`)
- `${AWS_ACCOUNT}`: AWS account ID for the environment
- `${GITHUB_ID}`: The GitHub username of the user who should be able to authenticate as `ec2-user` on the instance

## Setup EC2 Instance

- Amazon Linux 2023 on `m5.xlarge`
- VPC: `stack-${ENV}-vpc`
- `stack-${ENV}-bastion` and `stack-${ENV}-db-client` security groups
- 100GB gp3 volume
- User data:
  ```
  #!/bin/bash

  sudo -Hiu ec2-user bash -c 'curl https://github.com/${GITHUB_ID}.keys >> $HOME/.ssh/authorized_keys'
  ```
- Add to your *local machine's* `$HOME/.ssh/config` for convenience:
  ```
  Host avr-upgrade.${ENVIRONMENV}
    HostName ${NEW_INSTANCE_IP_ADDRESS} # Must be changed every time instance is started
    User ec2-user
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ForwardAgent yes
  ```

### Install Dependencies & Tools and Configure Environment
```shell
curl -s https://raw.githubusercontent.com/nulib/avr-migration/refs/heads/main/util/setup.sh | sh
exec $SHELL
```

## Avalon 7.8 .. 8.2

- [ ] [Migrate Fedora data](#avr-fedora-4x-to-6x-data-migration) from 4.x to 6.x
- [ ] Stand up Fedora 6.x
- [ ] Checkout correct branch
    ```
    cd $HOME/avalon
    git switch nu/deploy/${ENVIRONMENT}
    ```
- [ ] Install dependencies
    ```
    bundle config set --local without production
    bundle config set --local with aws development test postgres
    bundle install
    ```
- [ ] Generate DB encryption keys and add to `terraform/${ENVIRONMENT}.tfvars`
    ```
    bundle exec rails db:encryption:init
    ```
- [ ] Apply terraform updates
    ```
    cd terraform
    terraform init
    terraform plan -var-file ${ENVIRONMENT}.tfvars -out ${ENVIRONMENT}.plan
    # Check output
    terraform apply ${ENVIRONMENT}.plan
    ```
- [ ] Generate local `.envrc` from AWS Config
    ```
    script/avr_environment > .envrc-${ENVIRONMENT}
    ln -fs .envrc-${ENVIRONMENT} .envrc
    
    direnv allow
    ```
- [ ] Upload solr configs
  - Launch zk-shell
    ```
    zk-shell zookeeper-1.internal.${DOMAIN}
    ```
  - Upload `solr.xml` and `security.json` if needed
  - Run in zk-shell
    ```
    cp file:///home/ec2-user/avalon/solr/conf /configs/avalon true true true true
    exit
    ```
- [ ] Create solr index
    ```
    bundle exec rails zookeeper:create
    ```
- [ ] Run database migrations
    ```
    export RAILS_ENV=production
    bundle exec rails db:migrate
    bundle exec rails avalon:migrate:admin_units unit_admin_username=${AVR_ADMIN_EMAIL}
    bundle exec rails r script/update_collection_units.rb 
    ACTIVE_RECORD_ENCRYPTION_MIGRATION=true bundle exec rails r 'ApiToken.all.each(&:encrypt)'
    ```
- [ ] Sync migrated OCFL back to local storage
    ```
    cd $HOME/avr-migration
    rclone sync --progress --delete-excluded s3:stack-s-fedora6-ocfl/ data/staging/fcrepo6_export/data/ocfl-root/
    ```
- [ ] Initialize Avalon's reindex table
    ```
    cd $HOME/avalon
    script/hasmodel_to_db.rb -o $HOME/avr-migration/data/staging/fcrepo6_export/data/ocfl-root/
    ```
- [ ] Reindex all nodes
    ```
    for model in Hydra::AccessControl,Hydra::AccessControls::Permission Admin::Collection MediaObject MasterFile Derivative; do
      nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "$model" --skip-identification &
    done
    nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --skip-identification &
    ```
- [ ] Wait for all 6 background processes to complete
- [ ] Fix any indexing errors
    ```
    bundle exec rails r script/reindex_cleanup.rb 
    ```
- [ ] Run (as a test) with `bundle exec guard -i`, but customizations will not be present

## AVR Fedora 4.x to 6.x Data Migration

### Download Fedora import/export and upgrade utilities
```shell
mkdir -p bin
curl -Lo bin/fcrepo_export https://github.com/nulib-labs/fcrepo-export-stream/releases/download/v0.3.0/fcrepo_export.linux.x64
curl -LO --output-dir bin https://github.com/fcrepo-exts/fcrepo-import-export/releases/download/fcrepo-import-export-1.2.0/fcrepo-import-export-1.2.0.jar
curl -LO --output-dir bin https://github.com/avalonmediasystem/fcrepo-upgrade-utils/releases/download/6.3.0-AVALON/fcrepo-upgrade-utils-6.3.0-AVALON.jar
chmod 0755 bin/fcrepo_export
```

### Set up environment
```shell
# Use rdc.library for production
export DOMAIN=rdc-staging.library.northwestern.edu
export FEDORA_BASE=http://fcrepo.internal.${DOMAIN}:8080
mkdir -p data/${ENVIRONMENT}
```

### Export data from Fedora 4.x
```shell
mkdir -p data
./bin/fcrepo_export -r $FEDORA_BASE/rest/avr -d data/${ENVIRONMENT}/fcrepo4.7.5_export
./bin/fcrepo_export cleanup --apply --dir data/${ENVIRONMENT}/fcrepo4.7.5_export
```

### Upgrade exported data from 4.x to 5.x
```shell
java -jar bin/fcrepo-upgrade-utils-6.3.0-AVALON.jar --input-dir data/${ENVIRONMENT}/fcrepo4.7.5_export --output-dir data/${ENVIRONMENT}/fcrepo5_export \
  --source-version 4.7.5 --target-version 5+ 2>&1 | tee logs/upgrade_5_`date +%Y%m%dT%H%M%S`.log
```

### Upgrade exported data from 5.x to 6.x
```shell
java --add-opens java.base/java.util.concurrent=ALL-UNNAMED -jar bin/fcrepo-upgrade-utils-6.3.0-AVALON.jar \
  --input-dir data/${ENVIRONMENT}/fcrepo5_export --output-dir data/${ENVIRONMENT}/fcrepo6_export  --source-version 5+ --target-version 6+ \
  --base-uri $FEDORA_BASE/rest 2>&1 | tee logs/upgrade_6_`date +%Y%m%dT%H%M%S`.log
```

### Configure Fedora properties files

- Use the template files in `config` to create `config/fcrepo.properties` and `config/fcrepo-local.properties`
- The database and S3 bucket you use should be accessible from the EC2 instance you are on
- The instance should have an IAM role with read/write access to the bucket

### Run Fedora in Docker using local data to get the OCFL content indexed

```shell
docker compose --profile local up
```
- The initial startup will require all the content in the bucket to be indexed into the database. This may take a long time. Watch the log for something like
  ```
  (IndexBuilderImpl) Index rebuild completed 2321 objects successfully and 0 objects had errors in 328 seconds
  ```
- Spot check data by going to `http://INSTANCE_IP:8080/fcrepo/rest`
- Press `^C` to stop the Docker container before continuing

### Copy OCFL data to S3

```shell
rclone sync --progress data/${ENVIRONMENT}/fcrepo6_export/data/ocfl-root/ s3:stack-${ENV}-fedora6-ocfl/
```

### Run Fedora in Docker using S3 data to make sure everything is in the right place

```shell
docker compose --profile s3 up
```
- Spot check data again by going to `http://INSTANCE_IP:8080/fcrepo/rest`
- Press `^C` to stop the Docker container before continuing

### Deploy Fedora to ECS

- Best done as part of the AVR Terraform process
- Task role needs access to the bucket
- Task needs to run in the same VPC as the database
- Use the `Dockerfile` in this repo to add the correct config to the container
  - Same config used by the `s3` Docker Compose profile

## Solr 9.0 notes

- The Solr 9 / Zookeeper 3.9 cluster is in the `infrastructure` repo
- After the cluster comes up and stabilizes, use `zk-shell` to copy `solr.xml` and `security.json` to Zookeeper
- You should then be able to `bundle exec rails zookeeper:upload` and `bundle exec rails zookeeper:create` to create the collection
- There's a `stack-${ENV}-solr-backup` bucket where Zookeeper automatically backs up its configs, and Solr can use as a snapshot repository (no more EFS!)

### Reindexing

Run the `script/hasmodel_to_db.rb` script to populate the reindexing database from the OCFL root

```shell
# Note the --skip-identification flag avoids having to re-walk the Fedora tree to gather nodes needing to be reindexed
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "Hydra::AccessControl,Hydra::AccessControls::Permission" --skip-identification &
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "Admin::Collection" --skip-identification &
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "MediaObject" --skip-identification &
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "MasterFile" --skip-identification &
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --only-models "Derivative" --skip-identification &
RAILS_ENV=production nohup bundle exec rails r script/reindex.rb -v --parallel-indexing --parallel-threads 1 --skip-identification &
```

Use `script/reindex_cleanup.rb` to fix collections and media objects that errored on the first pass
