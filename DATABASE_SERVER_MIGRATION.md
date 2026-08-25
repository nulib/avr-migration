## Export Databases

- [ ] get old hostname out of `${ENVIRONMENT}/infrastructure/db` secret
- [ ] avr (`avr/terraform`):
  - [ ] get old password from `terraform state show module.db_schema.random_string.role_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=avr PGPASSWORD=` with correct values
  - [ ] `pg_dump -Fc --no-owner --no-acl --exclude-table-data='public.searches' --exclude-table-data='public.sessions' -f avr_staging.dump avr`
- [ ] arch (`arch/terraform`):
  - [ ] get old password from `terraform state show module.db_schema.random_string.role_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=arch PGPASSWORD=` with correct values
  - [ ] `pg_dump -Fc --no-owner --no-acl --exclude-table-data='public.searches' -f arch_staging.dump arch`
- [ ] fedora4 (`infrastructure/fcrepo`):
  - [ ] get old password from `terraform state show module.fcrepo_schema.random_string.role_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=fcrepo PGPASSWORD=` with correct values
  - [ ] `pg_dump -Fc --no-owner --no-acl -f fedora4_staging.dump fcrepo`

## Upgrade infrastructure

- [ ] avr (`avr/terraform`):
  - [ ] `terraform plan -var-file ${ENVIRONMENT}.tfvars ${ENVIRONMENT}.plan
  - [ ] `terraform apply ${ENVIRONMENT}.plan
- [ ] arch (`arch/terraform`):
  - [ ] `terraform plan -var-file ${ENVIRONMENT}.tfvars ${ENVIRONMENT}.plan
  - [ ] `terraform apply ${ENVIRONMENT}.plan
- [ ] fedora 4 & 6 (`infrastructure/fcrepo`):
  - [ ] `terraform plan -var-file ${ENVIRONMENT}.tfvars ${ENVIRONMENT}.plan
  - [ ] `terraform apply ${ENVIRONMENT}.plan

## Restore Databases
- [ ] get new hostname out of `${ENVIRONMENT}/infrastructure/aurora` secret
- [ ] avr (`avr/terraform`):
  - [ ] get new password from `terraform state show random_string.app_db_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=avr PGPASSWORD=` with correct values
  - [ ] `pg_restore -d avr --no-owner avr_staging.dump`
- [ ] arch (`arch/terraform`):
  - [ ] get new password from `terraform state show random_string.app_db_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=arch PGPASSWORD=` with correct values
  - [ ] `pg_restore -d arch --no-owner arch_staging.dump`
- [ ] fedora4 (`infrastructure/fcrepo`):
  - [ ] get new password from `terraform state show random_string.fedora4_db_password`
  - [ ] `export PGHOST= PGPORT= PGUSER=fedora4 PGPASSWORD=` with correct values
  - [ ] `pg_restore -d fcrepo --no-owner fedora4_staging.dump`
