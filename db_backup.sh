#!/bin/bash

################################################################################
# This script has been developed to help setting up scheduled database backups #
# More guidelines comming up
################################################################################


# function to check if the current OS is supported
function check_OS {
if [ ! -f /etc/redhat-release ]; then
	##non-rhel dist
	DIST=$(cat /etc/issue | head -1 | cut -d' ' -f1)
	if [ "$DIST" == "Ubuntu" ] || [ "$DIST" == "Debian" ]; then
		VERSION=$(cat /etc/issue | head -1 | cut -d' ' -f2 | cut -d'.' -f1,2)
		if [ $VERSION > 14 ] || [ $VERSION < 12 ]; then
			echo "Detected OS: $DIST version $VERSION"
			echo -e "\nYour OS version is not officially supported! You can try to manually install the bellow packages and re-run this script:\nholland\nholland-common\nholland-mysqldump\n"
			exit
		fi
	else
		echo "Unsuported OS. Aborted"
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
	fi

	if holland_repo $DIST $VERSION; then
		return 0
	else 
		echo "The repository install failed! Please add the holland repository manually from: http://download.opensuse.org/repositories/home:/holland-backup/"
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
			echo "Holland successfully installed!"
		else
			echo "There was an issue installing Holland. Please manually install the following packages and re-run this script: holland holland-common and holland-mysqldump"
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
	echo "The current directory for backups is: $CDIR"
	! true #forcing the exit status to non 0 for the next while loop
	while [ $? -ne 0 ]; do 
		read -p "Please enter a new location or press enter to leave unchanged (if the desired directory doesn't exists, it will be created)[`cat /etc/holland/holland.conf | grep "backup_directory" | cut -d'=' -f2` ]: " DIR
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
	echo "Backup destination location: $DIR"	
	}

# function for API backup method
function api_selected() {
	echo -e "API selected"
	exit
	}

# function for holland agent backup method
function holland_selected() {
	echo -e "Holland selected"
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
		while [ -z $name ]; do
			read -p "Enter a name for the new holland backupset: [eg: daily_backup] " name
		done
		/usr/sbin/holland mk-config mysqldump > /etc/holland/backupsets/$name.conf
		echo "New backupset /etc/holland/backupsets/$name.conf created.."
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
		
		read -p "How many backups you want to keep?(default is 1!)[eg. 30] " NUM
		sed -i 's|'backups-to-keep\ =\ 1'|'backups-to-keep\ =\ $NUM'|g' /etc/holland/backupsets/$name.conf
		fi
	
		while true; do
		read -p "How often should the backup be performed? This will create a cron job in the apropriate configuration file:
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
		
		while true; do
		read -p "All done! Do you want to force an initial backup right now? [Y/n] " yn
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
			echo "All the backups are stored under the location set in "	
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
	
	# setting the backup location
	while true; do
		read -p "Select the cloud backup destination:
		1) local
		2) cloud files
	Answer: " option
		case $option in
			1 ) backup_local_destination; exit;;
			2 ) backup_cloud_destination; exit;;
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
