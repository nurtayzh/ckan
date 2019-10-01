### ckan-install

# [1.1] 2019-07-22
## Added: 
- Globals for production

# [1.2] 2019-07-25
## Added: 
- Global variables for "Staging on P17SM at Ecole de la paix"
- Creation of $myPath directory, if doesn't exist

## Updated:
- Install Docker-Compose 1.24.1 instead of 1.24.0

## Removed:
- TODO comment


# --------------------------------------------------------------------------------

### ckan-deploy

# [2.0] 2019-07-22
## Added:
- Script for fromStagingToProd conditional option
- Script for fromProdToStaging conditional option
- Globals (variables) for production
- Globals (variables) for staging
- Instructions for changing database password, for secutiry reasons
- Instructions for website configuration
- Function install_ckan_migration_tools() to avoid repetition
- Function ckanapi_dump_load() to avoid repetition

## Updated:
- Using install_ckan_migration_tools() function instead of repeating code in every conditional option
- Using ckanapi_dump_load() function instead of repeating code in every conditional option

# [2.1] 2019-07-23
## Added:
- CHANGELOG.md file

## Updated:
- Fixed rsync for # Transfer resource files
- More readable instruction

# [3.0] 2019-07-23
## Added:
- Function deploy(): abstraction to avoid repetition
- Call to deploy() at fromStagingToDev and fromStagingToProd

## Removed:
- Repetetive script at fromStagingToDev and fromStagingToProd
- echo at install_ckan_migration_tools() function

# [3.1] 2019-07-24
## Updated:
- Fixed (cleaned) fromProdToStaging script

## Removed:
- `--upload-resources`  option at ckanapi: caused server error, because couldn't access SRC_CKAN url: localhost:5000


# --------------------------------------------------------------------------------

### production.ini
## Added:
- licenses_group_url = `file:///var/lib/docker/volumes/docker_ckan_home/_data/venv/src/ckan.json`
	reference: https://boykoc.github.io/ckan/configuration/2018/06/13/adding-custom-licenses-in-ckan.html


# --------------------------------------------------------------------------------

### ckan.json
## Added:
- CC-BY-3.0-IGO
- CC-BY-NC-SA-4.0
- other

## Updated:
- moved to `/var/lib/docker/volumes/docker_ckan_home/_data/venv/src/`
- chown 900:900 `/var/lib/docker/volumes/docker_ckan_home/_data/venv/src/ckan.json`
- chmod 644 `/var/lib/docker/volumes/docker_ckan_home/_data/venv/src/ckan.json `
