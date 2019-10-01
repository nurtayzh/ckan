#!/bin/bash
# ckan-deploy_2019-07-23_v3.1
# See CHANGELOG.md and README.md for prerequisites and instructions
# contact: nurtay@protonmail.ch

# Exit if any error occurs
set -e

# Globals
path_ckan_vol_storage='/var/lib/docker/volumes/docker_ckan_storage/_data'
path_ckan_vol_home='/var/lib/docker/volumes/docker_ckan_home/_data'
# Staging
path_tmp_staging='/home/username/Documents' # temporary path at staging
path_ckan_docker_compose_staging='/home/username/ckan/contrib/docker'
addr_user_staging='username@example.fr'
addr_port_staging='http://example.fr:8082'
api_ckan_sysadmin_staging=''
# Development
path_ckan_docker_compose_dev='/home/osboxes/ckan/contrib/docker'
addr_port_dev='http://localhost:5000'
api_ckan_sysadmin_dev=''
# Production
path_tmp_prod='/home/osboxes/Documents' # temporary path at prod sever
path_ckan_docker_compose_prod='/home/osboxes/ckan/contrib/docker'
addr_port_prod='http://localhost:5000'
api_ckan_sysadmin_prod=''

function help() {
	printf "Usage:  $0 [fromStagingToDev | fromStagingToProd | fromDevToStaging | fromProdToStaging]\n"
	return 1
}

# Notifies if a command was executed successfully
function ok() {
	printf "||||||| FINISHED: $1\n"
}

# Migration requires rsync, python-pip, ckanapi
# The following function proposes to install them
function install_ckan_migration_tools() {
	read -p "Do you want to install rsync? (y | n) " -r 
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		yes | sudo apt-get install rsync
		ok "Install rsync"
	fi

	read -p "Do you want to install python-pip? (y | n) " -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		sudo apt update
		yes | sudo apt install python-pip
		ok "Install pip"
	fi

	read -p "Do you want to install ckanapi? (y | n) " -r
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		sudo pip install ckanapi
		ok "Install ckanapi"
	fi
	ok "Install CKAN migration tools"
}

# Function exports and uploads groups, orgs, datasets
# Usage: ckanapi_dump_load $addr_port_prod $addr_port_staging $api_ckan_sysadmin_staging
function ckanapi_dump_load() {
	# Note that $1 ($addr_port_[staging|dev|prod]) must be running
	# Export data
	sudo ckanapi dump organizations --all -O orgs.jsonl.gz -z -r $1
	sudo ckanapi dump datasets --all -O dsets.jsonl.gz -z -r $1
	sudo ckanapi dump groups --all -O groups.jsonl.gz -z -r $1
	ok "Export data"
	# Upload data
	sudo ckanapi load organizations -I orgs.jsonl.gz -z -r $2 -a $3
	sudo ckanapi load datasets -I dsets.jsonl.gz -z -r $2 -a $3 
	# previous version was: sudo ckanapi load datasets --upload-resources -I dsets.jsonl.gz -z -r $2 -a $3
	# but --upload-resources option didn't work, because of SRC_CKAN url: localhost:5000
	sudo ckanapi load groups --upload-logo -I groups.jsonl.gz -z -r $2 -a $3
	ok "Upload data"
}

# Function should take 3 parameters: 
# $path_ckan_docker_compose_[dev|prod]
# $addr_port_[dev|prod]
# $api_ckan_sysadmin_[dev|prod]
function deploy() {
	# Install CKAN migration tools
	install_ckan_migration_tools

	# At staging server: copy _data/ && run SRC_CKAN && user.sql available at staging
	printf "\n*****************************************************************************************\n"
	printf "IMPORTANT: After providing password for ssh, run the following commands one by one (look script for more):\n"
	# We have to copy, because otherwise we get Permission denied (13), because
	# rsync needs sudo access on the other side of ssh pipe
	printf "sudo cp -r $path_ckan_vol_storage $path_tmp_staging\n"
	# Export the user table
	printf "cd $path_ckan_docker_compose_staging && docker-compose up -d\n"
	printf "docker exec -it ckan_db /bin/bash -c 'pg_dump -h localhost -U ckan -a -O -t user -f user.sql ckan && exit'\n"
	printf "docker cp ckan_db:/user.sql $path_tmp_staging\n"
	printf "exit\n"
	printf "\n*****************************************************************************************\n"
	ssh -p 22 $addr_user_staging
	ok "At staging: copy _data/ && run SRC_CKAN && user.sql available at staging"

	# Transfer resource files
	sudo rsync -Pavvre "ssh -p 22" $addr_user_staging:$path_tmp_staging/_data $path_ckan_vol_storage
	ok "Transfer resource files"

	# Transfer users
	# Make user.sql accessible to the source CKAN container
	# and chown user.sql to the owner of $CKAN_HOME (ckan, UID 900)
	sudo rsync -Pavvre "ssh -p 22" $addr_user_staging:$path_tmp_staging/user.sql $path_ckan_vol_home/venv/src
	sudo chown 900:900 $path_ckan_vol_home/venv/src/user.sql
	ok "user.sql accessible to SRC_CKAN container && chown user.sql"
	# Now the file user.sql is accessible from within the ckan container
	cd $1 && docker-compose up -d
	printf "Password for user ckan is at $1/.env\n"
	docker exec -it ckan /bin/bash -c 'psql -U ckan -h db -f $CKAN_VENV/src/user.sql'
	ok "Transfer users"

	# Export and upload groups, orgs, datasets
	# Note that $addr_port_staging must be running
	ckanapi_dump_load $addr_port_staging $2 $3

	# Rebuild search index. Trigger a Solr index rebuild:
	docker exec -it ckan /usr/local/bin/ckan-paster --plugin=ckan search-index rebuild -c /etc/ckan/production.ini
	ok "Trigger a Solr index rebuild"

	# Cleaning up
	printf "\n*****************************************************************************************\n"
	printf "IMPORTANT: After providing password for ssh, run the following commands one by one (look script for more):\n"
	printf "cd $path_tmp_staging && sudo rm -rfv _data user.sql\n"
	printf "exit\n"
	printf "\n*****************************************************************************************\n"
	ssh -p 22 $addr_user_staging
	ok "At staging: remove _data, user.sql"
	sudo rm -v orgs.jsonl.gz dsets.jsonl.gz groups.jsonl.gz
	ok "Remove orgs.jsonl.gz dsets.jsonl.gz groups.jsonl.gz"
	cd $1 && docker-compose stop && docker-compose up -d
	ok "Deployment"
}

# Main program
if [[ $# -ne 1 || $1 = "--help" || $1 = "-h" ]]; then help

elif [[ $1 = "fromStagingToDev" ]]; then
	deploy $path_ckan_docker_compose_dev $addr_port_dev $api_ckan_sysadmin_dev

elif [[ $1 = "fromStagingToProd" ]]; then
	deploy $path_ckan_docker_compose_prod $addr_port_prod $api_ckan_sysadmin_prod

elif [[ $1 = "fromDevToStaging" ]]; then
	printf "TODO\n"

elif [[ $1 = "fromProdToStaging" ]]; then
	# TODO
else
	help
fi