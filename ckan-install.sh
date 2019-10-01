#!/bin/bash
# ckan-install_2019-07-25_v1.2
# See CHANGELOG.md and README.md for prerequisites and instructions
# contact: nurtay@protonmail.ch


## GLOBALS 

# For staging:
#deb_ver='buster'
#usr="username"
#CKAN_URL='example.fr'
#CKAN_PORT='5000'

# Staging on P17SM at Ecole de la paix
deb_ver='disco' # Ubuntu 19.04
usr="username"
CKAN_URL='localhost'
CKAN_PORT='5000'

# For development:
#deb_ver='stretch'
#usr="osboxes"
#CKAN_URL='localhost'
#CKAN_PORT='5000'

# For production
# deb_ver='stretch'
# usr="username"
# CKAN_URL='example.fr'
# CKAN_PORT='5000'

# For all:
myPath="/home/$usr/bin/ckan" # directory where CKAN to be cloned
# VOL_CKAN_CONFIG="/var/lib/docker/volumes/docker_ckan_config/_data/"
VOL_CKAN_CONFIG="/var/snap/docker/common/var-lib-docker/volumes/docker_ckan_config/_data/"
# tmp='/etc/apt/sources.list'
mkdir -p $myPath 

# Exit if any error occurs
set -e

# Echo after each installation
fin() {
  echo "------> Finished: $1"
}

# ************************************************************* Install git
read -p "Do you want to install git? (y | n) " -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Comment deb cdrom
    sed -i '/^deb cdrom/s/^/#/' $tmp
    fin "Comment deb cdrom"

	# Add one line in sources.list and update
	echo "deb http://deb.debian.org/debian/ $deb_ver main contrib" >> $tmp
	apt-get update 
	yes | apt-get upgrade 
	yes | apt-get dist-upgrade
	yes | apt-get -f install
	fin "Add one line in sources.list and update"

	apt update
	yes | apt install git
	git --version
	fin "Install git"
fi

# ************************************************************* Install Docker
read -p "Do you want to install Docker? (y | n) " -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then
	# Install packages to allow apt to use a repository over HTTPS
	yes | apt-get install \
	    apt-transport-https \
	    ca-certificates \
	    curl \
	    gnupg2 \
	    software-properties-common
	fin "Install packages to allow apt to use a repository over HTTPS"

	# Add Docker’s official GPG key
	curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
	fin "Add Docker’s official GPG key"

	# Use the following command to set up the stable repository. To add the nightly or test repository, add the word nightly or test (or both) after the word stable
	add-apt-repository \
	 "deb [arch=amd64] https://download.docker.com/linux/debian \
	 $(lsb_release -cs) \
	 stable"
	fin "set up the stable repository"

	# Install the latest version of Docker CE and containerd, or go to the next step to install a specific version
	apt-get update
	yes | apt-get install docker-ce docker-ce-cli containerd.io
	fin "Install the latest version of Docker CE and containerd, or go to the next step to install a specific version"

	# Verify that Docker CE is installed correctly by running the hello-world image
	docker run hello-world
	fin "Verify that Docker CE is installed correctly by running the hello-world image"

	# Add your user to the docker group.
	usermod -aG docker $usr # $USER
	fin "Add your user to the docker group"
fi

# ************************************************************* Install Docker Compose
read -p "Do you want to install Docker Compose? (y | n) " -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Download the current stable release of Docker Compose
	curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	fin "Download the current stable release of Docker Compose"

	# Apply executable permissions to the binary
	chmod +x /usr/local/bin/docker-compose
	fin "Apply executable permissions to the binary"

	docker-compose --version
	fin "Install Docker Compose"
fi

# ************************************************************* Install CKAN
# Clone stable CKAN into a directory of your choice
cd $myPath
git clone --branch ckan-2.8.2 https://github.com/ckan/ckan.git
fin "Clone CKAN"

# Sensitive settings and environment variables, change URL and PORT, add CKAN_MAX_UPLOAD_SIZE_MB
cd $myPath/ckan/contrib/docker
cp .env.template .env
sed -i s/localhost:5000/$CKAN_URL:$CKAN_PORT/g .env
sed -i s/CKAN_PORT=5000/CKAN_PORT=$CKAN_PORT/g .env
echo "CKAN_MAX_UPLOAD_SIZE_MB=500" >> .env
fin "Sensitive settings and environment variables, change URL and PORT, add CKAN_MAX_UPLOAD_SIZE_MB"

# Build the images
cd $myPath/ckan/contrib/docker
docker-compose up -d --build
fin "Build the images"

# If the CKAN logs show problems connecting to the database, restart the ckan container a few times
cd $myPath/ckan/contrib/docker
docker-compose restart ckan
docker-compose restart ckan
fin "If the CKAN logs show problems connecting to the database, restart the ckan container a few times"

# Configure datastore database
docker exec ckan /usr/local/bin/ckan-paster --plugin=ckan datastore set-permissions -c /etc/ckan/production.ini | docker exec -i db psql -U ckan
fin "Configure datastore database"

# Add datastore datapusher to ckan.plugins and enable the datapusher option ckan.datapusher.formats
sed -i '/^ckan.plugins/s/$/ datastore datapusher/' $VOL_CKAN_CONFIG/production.ini
sed -i '/^#.*ckan.datapusher.formats/s/^#//' $VOL_CKAN_CONFIG/production.ini
fin "Add datastore datapusher to ckan.plugins and enable the datapusher option ckan.datapusher.formats"

# Restart the ckan container to apply changes to the production.ini
# cd $myPath/ckan/contrib/docker
# docker-compose restart ckan
# fin "Restart the ckan container to apply changes to the production.ini"

# Rename containers (ex: db -> ckan_db)
cd $myPath/ckan/contrib/docker
sed -Ei 's/(container_name:\s)datapusher/\1ckan_datapusher/' docker-compose.yml
sed -Ei 's/(container_name:\s)db/\1ckan_db/' docker-compose.yml
sed -Ei 's/(container_name:\s)solr/\1ckan_solr/' docker-compose.yml
sed -Ei 's/(container_name:\s)redis/\1ckan_redis/' docker-compose.yml
fin "Rename containers (ex: db -> ckan_db)"

# Create the CKAN admin user (admin is the login)
# email: admin@example.org
# pass: JohnDoe1
docker exec -it ckan /usr/local/bin/ckan-paster --plugin=ckan sysadmin -c /etc/ckan/production.ini add admin
fin "Create the CKAN admin user (admin is the login)"

# -------------- Add pdf_view extension
# Inside the running container, activate the virtualenv and Install the ckanext-pdfview
docker exec -it ckan /bin/bash -c 'source $CKAN_VENV/bin/activate && cd $CKAN_VENV/src/ && pip install ckanext-pdfview'
fin "Inside the running container, activate the virtualenv and Install the ckanext-pdfview"
# Add pdf_view to the ckan.plugins setting 
#                     ckan.views.default_views
sed -i '/^ckan.plugins/s/$/ pdf_view/' $VOL_CKAN_CONFIG/production.ini
sed -i '/^ckan.views.default_views/s/$/ pdf_view/' $VOL_CKAN_CONFIG/production.ini
fin "Add pdf_view to the ckan.plugins setting and to ckan.views.default_views"
cd $myPath/ckan/contrib/docker
docker-compose stop && docker-compose up -d
fin "Add pdf_view extension"


:<<'MIGHT_NEED'
# Fix SSL problem
yes | apt install python-pip
pip --version
pip install requests[security]
fin "Fix SSL problem"

# max upload size
cd $myPath/ckan/ckanext/datapusher
docker cp datapusher:/usr/src/app/datapusher/jobs.py .
cd $myPath/ckan/contrib/docker
echo "CKAN_MAX_UPLOAD_SIZE_MB=15" >> .env
fin "max upload size"
MIGHT_NEED
