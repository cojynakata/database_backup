#!/bin/bash

echo -e "#################################################################################
# This script has been developed to help setting up scheduled database backups	#
# It requires mysqldump to be installed and a successful connection		#
# to the database you wish to back up to be available				#
# (eg. mysql service must be started on default port 3306, firewall rule, etc)	#
#################################################################################\n"


# function to check if the current OS is supported
function check_OS {
if [ ! -f /etc/redhat-release ]; then
	##non-rhel dist
	DIST=$(cat /etc/issue | head -1 | cut -d' ' -f1)
	if [ "$DIST" == "Ubuntu" ]; then
		VERSION=$(cat /etc/issue | head -1 | cut -d' ' -f2 | cut -d'.' -f1)
		if [ "$VERSION" -gt "14" ] || [ "$VERSION" -lt "12" ]; then
			echo "Detected OS: $DIST version $VERSION"
			echo -e "\nSorry, currently the only supported distributions are Centos/RHEL 5/6/7, Debian7 and Ubuntu 12.xx, 14.xx\n"
			exit
    fi
    VERSION=$(cat /etc/issue | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
	elif [ "$DIST" == "Debian" ]; then
     VERSION=$(cat /etc/issue | head -1 | cut -d' ' -f3)
		if [ $VERSION != 7 ]; then
			echo "Detected OS: $DIST version $VERSION"
			echo -e "\nSorry, currently the only supported distributions are Centos/RHEL 5/6/7, Debian7 and Ubuntu 12.xx, 14.xx\n"
			exit
		fi     
  else
		echo -e "\nSorry, currently the only supported distributions are Centos/RHEL 5/6/7, Debian7 and Ubuntu 12.xx, 14.xx\n"
		exit
	fi	
	##rhel dist	
elif [ `cat /etc/redhat-release | grep -i "hat" | wc -l` -gt 0 ]; then
	DIST="Red Hat"
	VERSION=$(cat /etc/redhat-release | grep -Eo '[0-9]{1,4}' | head -1)
elif [ `cat /etc/redhat-release | grep -i "centos" | wc -l` -gt 0 ]; then
	DIST="CentOS"
	VERSION=$(cat /etc/redhat-release | grep -Eo '[0-9]{1,4}' | head -1)
else
	echo "Unsuported OS. Aborted"
	exit
fi
echo "Detected OS: $DIST version $VERSION"
	}

# function to check if holland is installed
function check_holland() {
	if [ "$DIST" == "Red Hat" ] || [ "$DIST" == "CentOS" ]; then
		if [ `rpm -qa holland holland-common holland-mysqldump | wc -l` -eq "3" ]; then
			return 0
		else
			return 1
		fi
	elif [ "$DIST" == "Ubuntu" ] || [ "$DIST" == "Debian" ]; then
		if [ `dpkg --get-selections holland holland-common holland-mysqldump | grep install | wc -l` -eq "3" ]; then
			return 0
		else
			return 1
		fi
	fi
	}

#function to check if the packages exists in any of the enabled repositories
function holland_repo() {
	if [ "$DIST" == "Red Hat" ] || [ "$DIST" == "CentOS" ]; then
		if [ `yum list holland holland-common holland-mysqldump | grep holland | wc -l` -eq "3" ]; then
			return 0
		else
			return 1
		fi
	elif [ "$DIST" == "Ubuntu" ] || [ "$DIST" == "Debian" ]; then
		if [ `apt-cache search holland | grep holland-mysqldump | wc -l` -eq "1" ]; then
			return 0
		else
			return 1
		fi
	fi
	}

#function to install the holland repository
function holland_repo_install() {
	if [ "$DIST" == "Red Hat" ] && [ "$VERSION" -lt "7" ]; then
		echo "Fetching repo: http://download.opensuse.org/repositories/home:/holland-backup/RedHat_RHEL-$VERSION/home:holland-backup.repo"
		wget -q -P /etc/yum.repos.d/ http://download.opensuse.org/repositories/home:/holland-backup/RedHat_RHEL-$VERSION/home:holland-backup.repo
	elif [ "$DIST" == "Red Hat" ] && [ "$VERSION" -eg "7" ]; then
		echo "Fetching repo: http://download.opensuse.org/repositories/home:/holland-backup/RHEL-$VERSION/home:holland-backup.repo"
		wget -q -P /etc/yum.repos.d/ http://download.opensuse.org/repositories/home:/holland-backup/RedHat_RHEL-$VERSION/home:holland-backup.repo
	elif [ "$DIST" == "CentOS" ] && [ "$VERSION" -lt "7" ]; then
		echo "Fetching repo: http://download.opensuse.org/repositories/home:/holland-backup/CentOS_CentOS-$VERSION/home:holland-backup.repo"
		wget -q -P /etc/yum.repos.d/ http://download.opensuse.org/repositories/home:/holland-backup/CentOS_CentOS-$VERSION/home:holland-backup.repo
	elif [ "$DIST" == "CentOS" ] && [ "$VERSION" -eg "7" ]; then
		echo "Fetching repo: http://download.opensuse.org/repositories/home:/holland-backup/CentOS-$VERSION/home:holland-backup.repo"
		wget -q -P /etc/yum.repos.d/ http://download.opensuse.org/repositories/home:/holland-backup/CentOS-$VERSION/home:holland-backup.repo
	elif [ "$DIST" == "Ubuntu" ]; then
		wget -q http://download.opensuse.org/repositories/home:/holland-backup/xUbuntu_$VERSION/Release.key -O - | sudo apt-key add -
		echo "deb http://download.opensuse.org/repositories/home:/holland-backup/xUbuntu_$VERSION/ ./" > /etc/apt/sources.list.d/holland.list
		echo "Updating packages list! Please wait..."
		apt-get update 2>&1 > /dev/null	
	elif [ "$DIST" == "Debian" ]; then
		wget -q http://download.opensuse.org/repositories/home:/holland-backup/Debian_7.0/Release.key -O - | sudo apt-key add -
		echo "deb http://download.opensuse.org/repositories/home:/holland-backup/Debian_7.0/ ./" > /etc/apt/sources.list.d/holland.list
		echo "Updating packages list! Please wait..."
		apt-get update 2>&1 > /dev/null
	fi

	if holland_repo $DIST $VERSION; then
		return 0
	else 
		echo "The repository install failed! Please add the holland repository manually from: http://download.opensuse.org/repositories/home:/holland-backup/"
    exit
	fi
	}

# function to install holland and mysqldump packages
function holland_install() {
	while ! holland_repo $DIST $VERSION; do
	read -p "The holland components could not be found in the available repositories! Do you wish to install the official holland repository?[Y/n] " yn
	case $yn in
		[Yy]* ) holland_repo_install $DIST $VERSION;;
		[Nn]* ) echo "Aborted!"; exit;;
		* ) echo -e "\nPlease answer yes[Y] or no[N]";;
	esac
	done
	echo "The required components have been found in the repositories. Going on with installing packages: holland holland-common and holland-mysqldump"
	echo "Please wait..."

	# installing holland and components		
	if [ "$DIST" == "Red Hat" ] || [ "$DIST" == "CentOS" ]; then
		yum install holland holland-common holland-mysqldump -y 2>&1 > /dev/null
		if [ `yum list holland holland-common holland-mysqldump | grep holland | wc -l` -eq "3" ]; then
			echo -e "\nHolland successfully installed!"
		else
			echo -e "\nThere was an issue installing Holland. Please manually install the following packages and re-run this script: holland holland-common and holland-mysqldump"
			break
		fi
	elif [ "$DIST" == "Ubuntu" ] || [ "$DIST" == "Debian" ]; then
		apt-get install holland holland-common holland-mysqldump -y 2>&1 > /dev/null
		if [ `apt-cache search holland | grep holland-mysqldump | wc -l` -eq "1" ]; then
			echo "Holland successfully installed!"
		else
			echo "There was an issue installing Holland. Please manually install the following packages and re-run this script: holland holland-common and holland-mysqldump"
			break
		fi		
	fi	
	}

# function to set a local backup destination
function backup_local_destination(){
	CDIR=`cat /etc/holland/holland.conf | grep "backup_directory" | cut -d'=' -f2 | tr -d '[[:space:]]'`
	echo -e "\nThe current directory for backups is: $CDIR"
	! true #forcing the exit status to non 0 for the next while loop
	while [ $? -ne 0 ]; do 
		echo -e "\nPlease type a new location or press enter to leave unchanged;\nWARNING! this change is globally and will affect all the holland backups;\nIf the directory doesn't exists, it will be created;"
    read -p "Location: [`cat /etc/holland/holland.conf | grep "backup_directory" | cut -d'=' -f2` ]: " DIR
		DIR=`echo $DIR | tr -d '[[:space:]]'`
		if [ -z $DIR ]; then
			echo "Backup destination not changed!"
			DIR=$CDIR
		else
			mkdir -p $DIR
			echo $CDIR
			sed -i 's|'backup_directory\ =\ $CDIR'|'backup_directory\ =\ $DIR'|g' /etc/holland/holland.conf
		fi
	done
	echo -e "Backup location: $DIR\n"	
	}

# function for API backup method
function api_selected() {
	echo -e "\nAPI method selected. This method will only work with Rackspace cloud databases!\nTIP: hold the CTRL key if you need to use the DEL or BACKSPACE keys"
	mkdir -p /etc/dbcloud_backup/
	#functions
	
	function get_token() {
		OUTPUT=$(curl -s -d '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username": "'"$USERNAME"'","apiKey": "'"$APIKEY"'"}}}' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens')
		TOKEN=$(echo $OUTPUT | jq '.access.token.id' | cut -d'"' -f2)
		EXPIRE=$(echo $OUTPUT | jq '.access.token.expires' | cut -d'"' -f2 | grep -oh "[0-9]" | tr -d '\n' | cut -c -14)
		DDI=$(echo $OUTPUT | jq '.access.token.tenant.id' | cut -d'"' -f2)
		
		if [ -z $TOKEN ]; then
			echo "There was a problem generating a token. Please check if the account details you provided are correct and if the page https://identity.api.rackspacecloud.com/v2.0/tokens is reachable from your server"
			exit
		else
			echo -e "\nSaving info and token to /etc/dbcloud_backup/dbcloud_backup.conf"
			echo -e "DDI: $DDI\nUSERNAME: $USERNAME\nAPIKEY: $APIKEY\nTOKEN: $TOKEN\nEXPIRE: $EXPIRE" > /etc/dbcloud_backup/dbcloud_backup.conf
			cat /etc/dbcloud_backup/dbcloud_backup.conf
		fi
	}
	
	function get_account_info() {
		if [[ "$1" == "OVR" ]]; then
			while [ -z $USERNAME ]; do 
				read -p "Enter your Rackspace account username [eg. admin]: " USERNAME
			done
			
			while [ -z $APIKEY ]; do
				read -p "Enter your username's API key (info: http://www.rackspace.com/knowledge_center/article/view-and-reset-your-api-key): " APIKEY
			done
			get_token
		else
			USERNAME=$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep USERNAME | cut -d' ' -f2)
			APIKEY=$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep APIKEY | cut -d' ' -f2)
			DDI=$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep DDI | cut -d' ' -f2)
			EXPIRE=$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep EXPIRE | cut -d' ' -f2 | grep -oh "[0-9]" | tr -d '\n' | cut -c -14)
			DATE=$(date -u +%Y%m%d%H%M%S) #get current time in UTC
			if [[ $DATE -lt $EXPIRE ]]; then
				echo -e "Token still valid!\n"
				TOKEN=$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep TOKEN | cut -d' ' -f2)
			else
				echo -e "Token expired! Requesting a new one!"
				get_token
			fi
		fi
		}

	function download_jq() {
		wget -q -O /usr/bin/jq http://stedolan.github.io/jq/download/linux64/jq
		if [ $? -eq 0 ]; then
			echo -e "jq has been saved to /usr/bin/jq\n"
			chmod u+x /usr/bin/jq
		else
			echo "There was an issue downloading jq. Please download/install the package manually: http://stedolan.github.io/jq/download/"
			exit
		fi
		}

		if [ ! -f /usr/bin/jq ]; then
			while true; do
				read -p "jq (a lightweight JSON processor) is needed for this method and could not be found in your PATH. Do you want to download it right now?[y/n] " yn
				case $yn in
					[Yy]* ) download_jq; break;;
					[Nn]* ) echo "Aborted!"; exit;;
					* ) echo -e "\nPlease answer yes[Y] or no[N]";;
				esac
			done
		else
			echo -e "jq was found on the system at: `which jq`\n"
		fi
		
		if [ -f /etc/dbcloud_backup/dbcloud_backup.conf ]; then
			mkdir -p /etc/dbcloud_backup/
			while true; do
			echo -e "File /etc/dbcloud_backup/dbcloud_backup.conf already exists and contains the following information:\n`cat /etc/dbcloud_backup/dbcloud_backup.conf`"
			read  -p "
Do you want to overwrite it?[y/n] " yn
			case $yn in
				[Yy]* ) get_account_info OVR; break;;
				[Nn]* ) get_account_info; break;;
				* ) echo -e "\nPlease answer yes[Y] or no[N]";;
			esac
			done
		else
			echo "File /etc/dbcloud_backup/dbcloud_backup.conf was not found. Getting account information and generating file:"
			get_account_info OVR
		fi
	
function create_cloud_backup_script() {
echo -e "\nDeploying cloud backup script to /etc/dbcloud_backup/dbcloud_backup.sh
Please note that for each instance that will be backed up using this script an additional file will be created under /etc/dbcloud_backup/
Do not try to manually modify any of them unless you know what you do!\n"

echo "#!/bin/bash

LOCATION=\$1
UUID=\$2
SCHEDULE_PERIOD=\$3
RETENTION=\$4
TIME=\$(date +%Y%m%d%H%M)

function get_token() {
OUTPUT=\$(curl -s -d '{\"auth\":{\"RAX-KSKEY:apiKeyCredentials\":{\"username\": \"'\"\$USERNAME\"'\",\"apiKey\": \"'\"\$APIKEY\"'\"}}}' -H 'Content-Type: application/json' 'https://identity.api.rackspacecloud.com/v2.0/tokens')
TOKEN=\$(echo \$OUTPUT | jq '.access.token.id' | cut -d'\"' -f2)
EXPIRE=\$(echo \$OUTPUT | jq '.access.token.expires' | cut -d'\"' -f2 | grep -oh \"[0-9]\" | tr -d '\n' | cut -c -14)
DDI=\$(echo \$OUTPUT | jq '.access.token.tenant.id' | cut -d'\"' -f2)

if [ -z \$TOKEN ]; then
        echo \"There was a problem generating a token. Please check if the account details you provided are correct and if the page https://identity.api.rackspacecloud.com/v2.0/tokens is reachable from your server\"
        exit
else
        echo -e \"\nSaving info and token to /etc/dbcloud_backup/dbcloud_backup.conf\"
        echo -e \"DDI: \$DDI\nUSERNAME: \$USERNAME\nAPIKEY: \$APIKEY\nTOKEN: \$TOKEN\nEXPIRE: \$EXPIRE\" > /etc/dbcloud_backup/dbcloud_backup.conf
        cat /etc/dbcloud_backup/dbcloud_backup.conf
fi
}

USERNAME=\$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep USERNAME | cut -d' ' -f2)
APIKEY=\$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep APIKEY | cut -d' ' -f2)
DDI=\$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep DDI | cut -d' ' -f2)
EXPIRE=\$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep EXPIRE | cut -d' ' -f2 | grep -oh \"[0-9]\" | tr -d '\n' | cut -c -14)
DATE=\$(date -u +%Y%m%d%H%m%S) #get current time in UTC
if [[ \$DATE -lt \$EXPIRE ]]; then
        echo -e \"Token still valid!\n\" > /dev/null
        TOKEN=\$(cat /etc/dbcloud_backup/dbcloud_backup.conf | grep TOKEN | cut -d' ' -f2)
else
        echo -e \"Token expired! Requesting a new one!\n\" > /dev/null
        get_token
fi

BACKUP=\$(curl -s -X POST -d '{
    \"backup\": {
        \"instance\": \"'\"\"\$UUID\"\"'\",
        \"description\": \"automatic_backup\",
        \"name\": \"'\"\"\$SCHEDULE_PERIOD\"_\"\$TIME\"\"'\"
    }
}
' -H \"Content-Type: application/json\" -H \"X-Auth-Token: \$TOKEN\" https://\$LOCATION.databases.api.rackspacecloud.com/v1.0/\$DDI/backups)

ID=\$(echo \$BACKUP | jq '.backup.id' | cut -d'\"' -f2)

if [ -z \"\$ID\" ]; then
        echo \"There was a problem requesting for a new backup - \$TIME\" >> /etc/dbcloud_backup/\$UUID_backup_log.conf
	return 2
else
        echo \"Backup requested: \$SCHEDULE_PERIOD\"_\"\$TIME \$ID\" >> /etc/dbcloud_backup/\"\$UUID\"_backup_log.conf
fi

# cleanup
while [ \`cat /etc/dbcloud_backup/\"\$UUID\"_backup_log.conf | grep Backup | wc -l\` -gt \$RETENTION ]; do
	TBD=\`cat /etc/dbcloud_backup/\"\$UUID\"_backup_log.conf | head -1 | awk {'print \$4'}\`
	DELETE=\$(curl -s -X DELETE -H 'X-Auth-Token: '\"\$TOKEN\"'' https://\$LOCATION.databases.api.rackspacecloud.com/v1.0/\$DDI/backups/\$TBD)
	if [ -z \"\$DELETE\" ]; then
		echo \"Delete request sent\" > /dev/null
		sed -i \"/\$TBD/d\" /etc/dbcloud_backup/\"\$UUID\"_backup_log.conf
	else
		echo \"There was an error while deleting the backup\" > /dev/null
		return 2
	fi
done" > /etc/dbcloud_backup/dbcloud_backup.sh
			}
	
		function create_cloudb_cron() {
			SCHEDULE_PERIOD=$1
			if [ `grep "$UUID" /etc/cron.$1/ -R | wc -l` == "0" ]; then
				echo -e "Creating cronjob for clouddb instance $UUID in /etc/cron.$1/clouddb\n"
				echo "`which bash` /etc/dbcloud_backup/dbcloud_backup.sh $LOCATION $UUID $SCHEDULE_PERIOD $RETENTION" >> /etc/cron.$1/clouddb
				chmod +x /etc/cron.$1/clouddb
			else
				echo -e "Another $1 cronjob exists for the instace $UUID! Skipping...\n"
				chmod +x /etc/cron.$1/clouddb
			fi	
			}

		function create_cloudb_backupset() {
			create_cloud_backup_script
			echo -e "How many backups do you want to keep for this cloud database?\nPlease note that this setting will only affect the cloud database backups created using this script.\nAll the backups will have the text \"automated_backup\" in the description field.\nThe oldest backup will be removed when the specified limit is reached." 
			read -p "Answer: [eg. 5] " RETENTION
	
		while true; do		
read -p "How often should the backup be performed? This will create a cron job in the apropriate configuration cron file:
		1) Hourly
		2) Daily
		3) Weekly
		4) Monthly
Option number: " CRON
		case $CRON in
			1 ) create_cloudb_cron hourly $RETENTION; break;;
			2 ) create_cloudb_cron daily $RETENTION; break;;
			3 ) create_cloudb_cron weekly $RETENTION; break;;
			4 ) create_cloudb_cron monthly $RETENTION; break;;			
			* ) echo -e "\nPlease select one of options";;
		esac
		done			
			}

		function select_clouddb() {
			LOCATION=$1
			OUTPUT=$(curl -s -H "X-Auth-Token: $TOKEN" https://$LOCATION.databases.api.rackspacecloud.com/v1.0/$DDI/instances)
			LIST=`echo $OUTPUT | jq '.' | grep "\"name\":" | wc -l`
			if [ $LIST -gt 0 ]; then
				echo -e "\nListing all the cloud databases for account $DDI in region `echo $LOCATION | tr '[:lower:]' '[:upper:]'`:"
				for ((i = 0; i < $LIST; i++)); do
					echo -e "\nCloud database $((i+1)):"
					echo "--------------------"	
					echo "Name: `echo $OUTPUT | jq '.instances['$i'].name'`"
					echo "Hostname: `echo $OUTPUT | jq '.instances['$i'].hostname'`"
					echo "UUID: `echo $OUTPUT | jq '.instances['$i'].id'`"
				done
				echo -e "\nPlease enter the UUID of the cloud database for which you would like to set the scheduled backups:"
				read -p "CloudDB UUID: " UUID
				create_cloudb_backupset

				# testing the backup
				while true; do
				read -p "All done! Do you want to force an initial backup right now? [Y/n] " yn
				case $yn in
					[Yy]* ) `which bash` /etc/dbcloud_backup/dbcloud_backup.sh $LOCATION $UUID $SCHEDULE_PERIOD $RETENTION; break;;
					[Nn]* ) echo "Aborted!"; exit;;
					* ) echo -e "\nPlease answer yes[Y] or no[N]";;
				esac
				done
				
				if [ $? == 0 ]; then
					echo -e "\nThe inital backup completed successfully. The next backup will run as scheduled!"
					echo "All the backups are stored in your \"MySQL Backups\" section in your Rackspace cloud control panel"
				else
					echo -e "\nThere was an issue while performing the backup. Please try to run the backup manually "
				fi
				
				exit			
			
			else
				echo -e "\nNo cloud databases could be found for account $DDI in region `echo $LOCATION | tr '[:lower:]' '[:upper:]'`\nPlase check that you have at least one ACTIVE cloud database created in the selected region."
			fi
			}
	
		while true; do
	echo
	read -p "Select the region of your database?
1) DFW (Dallas)
2) ORD (Chicago)
3) IAD (Virginia)
4) SYD (Syndney)
5) LON (London)
6) HKG (Hong Kong)
Option number: " LOCATION
		case $LOCATION in
		1 ) select_clouddb dfw; break;;
		2 ) select_clouddb ord; break;;
		3 ) select_clouddb iad; break;;
		4 ) select_clouddb syd; break;;
		5 ) select_clouddb lon; break;;
		6 ) select_clouddb hkg; break;;
			* ) echo -e "\nPlease answer with the option number";;
		esac
		done
			
		
		exit
		}

# function for holland agent backup method
function holland_selected() {
	echo -e "Holland agent method selected\nTIP: hold the CTRL key if you need to use the DEL or BACKSPACE keys\n"
	check_OS
	echo "Checking if holland is installed..."
		while ! check_holland $DIST $VERSION; do
		read -p "Components are missing! Do you wish to install them now?[Y/n] " yn
		case $yn in
			[Yy]* ) holland_install $DIST $VERSION;;
			[Nn]* ) echo "Aborted!"; exit;;
			* ) echo -e "\nPlease answer yes[Y] or no[N]";;
		esac
		done
		echo "`holland --version | grep Holland` found on the system!"

# function to check and add a cron job
function create_cron() {
	if [ `grep "bk $name" /etc/cron.$1/ -R | wc -l` == "0" ]; then
		echo -e "Creating $name holland backupset cronjob in /etc/cron.$1/holland..\n"
		echo "`which holland` bk $name" >> /etc/cron.$1/holland
		chmod +x /etc/cron.$1/holland
	else
		echo -e "Another $1 cronjob exists for $name holland backupset! Skipping...\n"
		chmod +x /etc/cron.$1/holland
	fi	
	}
	
	## building a new holland backupset configuration ##
	function db_con_test(){
		#echo "hostname=$1, username=$2, password=$3"
		if [ -z $3 ]; then
			echo "quit" | mysql -h $1 -u $2 > /dev/null 2>&1
		else
			echo "quit" | mysql -h $1 -u $2 -p$3 > /dev/null 2>&1
		fi
		
		if [ "$?" -ne "0" ]; then
			echo -e "The mysql connection failed using the provided details. Please troubleshoot the connection manually and run this script again"
			exit
		else
			if [ -z $3 ]; then
				if [ `echo "show databases;" | mysql -h $1 -u $2 | grep -v information_schema | grep -v performance_schema | tail -n +2 | wc -l` == "0" ]; then
					echo "The connection has been successfully established. At the moment there are no databases to back up. If this is not expected, please make sure that the provided mysql user has access to the database you want to backup."
				else
					echo -e "\nThe following database(s) will be backed up:"
					mysqlshow -h $1 -u $2 | grep -v information_schema | grep -v performance_schema
					echo "If something is not right with this list, please make sure that the provided mysql user has access to the database you want to backup."
				fi
			else
				if [ `echo "show databases;" | mysql -h $1 -u $2 -p$3 | grep -v information_schema | grep -v performance_schema | tail -n +2 | wc -l` == "0" ]; then
					echo "The connection has been successfully established. At the moment there are no databases to back up. If this is not expected, please make sure that the provided mysql user has access to the database you want to backup."
				else
					echo -e "\nThe following database(s) will be backed up:"
					mysqlshow -h $1 -u $2 -p$3 | grep -v information_schema | grep -v performance_schema
					echo "If something is not right with this list, please make sure that the provided mysql user has access to the database you want to backup."
				fi
			fi
			con_ok=1	
		fi
		}
	
	echo -e "\nAdding a new scheduled backup..."
	function create_backupset(){
		
# 	setting the backup location (cloud files to be developed)
#		while true; do
#			echo
#			read -p "Select the backup destination:
#		1) local
#		2) rackspace cloud files
#	Answer: " option
#			case $option in
#				1 ) backup_local_destination; break;;
#				2 ) backup_cloud_destination; break;;
#				* ) echo -e "\nPlease answer with 1 or 2";;
#			esac
#		done
		
		backup_local_destination
		
		while [ -z $name ]; do
			read -p "Enter a name for the new holland backupset: [eg: daily_backup] " name
		done
		/usr/sbin/holland mk-config mysqldump > /etc/holland/backupsets/$name.conf
		echo -e "New backupset /etc/holland/backupsets/$name.conf created\n"
			if [ "$1" -eq "1" ]; then
				HOST=localhost
				if [ `cat /root/.my.cnf | grep root | cut -d'=' -f2 | wc -l` -eq "1" ]; then
					USER=`cat /root/.my.cnf | grep user | cut -d'=' -f2 | tr -d '[[:space:]]'`
					PASS=`cat /root/.my.cnf | grep password | cut -d'=' -f2 | tr -d '[[:space:]]'`
					echo -e "\nThe following mySQL root account credentials have been found on the system: \nusername: $USER \npassword: $PASS"
					while true; do
						read -p "Do you want to use them for database backups?[yes/no] " option
						case $option in
							[Yy]* ) MYCNF=1; break;;
							[Nn]* ) echo "Please provide a mysql username and password with access to the databases you want to back up: "
							read -p "username: " USER
							read -p "password: " PASS
							break;;
						* ) echo -e "\nPlease answer yes[Y] or no[N]";;
						esac
					done
				else
					echo "Please provide a mysql username and password with access to the databases you want to back up: "
					read -p "username: " USER
					read -p "password: " PASS
				fi
			elif [ "$1" -eq "2" ]; then
				echo "Please provide the following connection details for the remote database you want to back up: "
				read -p "hostname: " HOST
				read -p "username: " USER
				read -p "password: " PASS	
			fi
			
		db_con_test $HOST $USER $PASS
		if [ $con_ok == 1 ]; then
			if [[ $MYCNF == "1" ]]; then
				echo -e "Using the /etc/.my.cnf connection details/parameters\n"
			else
				echo -e "Updating connection details to /etc/holland/backupsets/$name.conf\n"
				sed -i 's|'#\ host\ =\ \"\"\ #\ no\ default'|'host\ =\ \"$HOST\"'|g' /etc/holland/backupsets/$name.conf
				sed -i 's|'#\ user\ =\ \"\"\ #\ no\ default'|'user\ =\ \"$USER\"'|g' /etc/holland/backupsets/$name.conf
				sed -i 's|'#\ password\ =\ \"\"\ #\ no\ default'|'password\ =\ \"$PASS\"'|g' /etc/holland/backupsets/$name.conf	
			fi
		
			while true; do
				read -p "How many backups do you want to keep?[eg. 30] " NUM
				if [[ $NUM -gt 0 ]]; then
					sed -i 's|'backups-to-keep\ =\ 1'|'backups-to-keep\ =\ $NUM'|g' /etc/holland/backupsets/$name.conf
					break
				fi
			done
		fi

		while true; do
		echo
		read -p "How often should the backup be performed? This will create a cron job in the apropriate configuration cron file:
	1) Hourly
	2) Daily
	3) Weekly
	4) Monthly
Option number: " CRON
		case $CRON in
			1 ) create_cron hourly; break;;
			2 ) create_cron daily; break;;
			3 ) create_cron weekly; break;;
			4 ) create_cron monthly; break;;			
			* ) echo -e "\nPlease select one of options";;
		esac
		done
		
		echo -e "\nAll done!"
		while true; do
		read -p "Do you want to force an initial backup right now? [Y/n] " yn
		case $yn in
			[Yy]* ) `which holland` bk $name; break;;
			[Nn]* ) echo "Aborted!"; exit;;
			* ) echo -e "\nPlease answer yes[Y] or no[N]";;
		esac
		done
		
		if [ $? == 0 ]; then
			echo -e "\nThe inital backup completed successfully. The next backup will run as scheduled!"
		else
			echo -e "\nThere was an issue while performing the backup. Please go over the holland log /var/log/holland/holland.log and troubleshoot manually"
		fi
		
		exit
			
		}
	
	while true; do
		read -p "What type of database do you want to backup?
		1) local
		2) remote (including cloud databases)
	Answer: " option
		case $option in
			1 ) create_backupset $option; break;;
			2 ) create_backupset $option; break;;
			* ) echo -e "\nPlease answer with 1 or 2";;
		esac
		done	
		
	}

## backup method selection
while true; do
	read -p "Select cloud database prefered backup method:
	1) Holland agent method
	2) API call method
Answer: " option
    case $option in
        1 ) holland_selected; exit;;
        2 ) api_selected; exit;;
        * ) echo -e "\nPlease answer with 1 or 2";;
    esac
	done 
