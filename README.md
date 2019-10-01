
### ckan-install

Installing git, Docker, Docker Compose, CKAN, pdf_view ckan extension

## PREREQUISITES:
- Uncomment globals for (staging or development)
- Root access

## INSTRUCTIONS:
- Run script from root

# ------------------------------------------------------------

### ckan-deploy

Installing rsync, python-pip, ckanapi.
Transfering resources and users from one CKAN instance to another.
Dumping and loading organizations, datasets, groups from one CKAN instance to another.

## PREREQUISITES:
- Must have two scripts: 	
	ckan-install (installation of new CKAN)
	ckan-deploy (migration from existing CKAN instance (SRC_CKAN) to a new one (DEST_CKAN))
- (Except for fromProdToStaging option) Must have direct ssh to SRC_CKAN (which must be running)
- User at DEST_CKAN must have sudo access

## INSTRUCTIONS:
- First, open ckan-install script, read instructions and run it
- In your browser, open installed CKAN, log in as sysadmin, go to sysadmins profile, 
		find api-key and put it in api_ckan_sysadmin_ (in this script)
- Then, in this script, change other variables (if needed), addr_user_, addr_port_, etc., 
- Run this script
- Optional: open .env file (/path/to/ckan/contrib/docker/.env),
			change password for database ('ckan' by default), and restart containers
- Configure website manually (name, about, logo, etc.)
