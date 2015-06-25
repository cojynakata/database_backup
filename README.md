# Database Backup Scheduler

This is a simple bash script designed to help setting up scheduled local/remote mysql database backups. Depending on the type of the database, this can be done using one of the methods described bellow. The automatic backup will be done via a cronjob.

# How to run:
bash <(curl -s https://raw.githubusercontent.com/cojynakata/database_backup/master/db_backup.sh)

# About the script:
Method 1) Holland agent (http://hollandbackup.org)
- NOTE: this method requires mysqldump and mysqlshow packages to be installed on the system and that a mysql connection to be available to the database
  PROCESS WALKTHROUGH:
  - it will install the holland packages and holland-mysqldump plugin (and if needed also the holland repository); the supported distributions are Centos/RHEL 5/6/7, Debian7 and Ubuntu 12.xx, 14.xx
  - it will query and set the default holland backup location
  - it will create a new holland backupset using the command: holland mk-config mysqldump <NAME>
  - it will query for the database connection details, test the connection and update the backupset /etc/holland/backupsets/<BACKUP_NAME>.conf
  - it will ask the for the backup retention period and update the "backups-to-keep" parameter in the holland backupset
  - it will ask the frequency of the backups and create a cronfile named "holland" under the corresponding /etc/cron.<FREQUENCY>/ directory
  - the cronjob will be in the following format which is allowing the backup jobs to run independently : `which holland` bk BACKUPSET_NAME and the backups will be saved in the selected directory

Method 2) API call method
  NOTE: this method will only work with Rackspace cloud databases and requires "jq" to be installed in /usr/bin/jq which will be automatically downloaded if needed
  PROCESS WALKTHROUGH:
  - it will ask for the Rackspace username and API key based on which it will generate the TOKEN; these info will be saved to /etc/dbcloud_backup/dbcloud_backup.conf and later used when needed (eg. setting a new backup or running an existing one)
  - the token validity will be checked before use and a new token will be requested and saved if expired
  - it will ask for the cloud database location and list some information on all the databases in the cloud account for that region (name, hostname, UUID)
  - the selection of the cloud database to be backed up will be made by the UUID
  - it will ask for the number of backups that will be kept;
    NOTES:  - a script will be saved to /etc/dbcloud_backup/dbcloud_backup.sh which will be used for the actual backup process
            - in order "save" the API calls, all the cloud database instances which will be backed up using this script will have a dedicated backup log in /etc/dbcloud_backup/ which will store the backup name and ID for of the successful backups or an error message and date of the failed ones;
            - based on this file, the script will keep track of the number of successfull backups and remove the oldest one when that limit has been reached;
            - if any automatic created backups will be manually removed (eg. using the cloud control panel) its best to also remove its ID from the backup log file
    - it will ask the frequency of the backups and create a cronfile named "clouddb" under the corresponding /etc/cron.<FREQUENCY>/ directory
    - the cronjob will be in the following format which is allowing the backup jobs to run independently : `which bash` /etc/dbcloud_backup/dbcloud_backup.sh LOCATION UUID SCHEDULE_PERIOD BACKUP and the backups will be saved the cloud control panel (Backups -> MySQL Backups or in the Backups section on the cloud database instance details page)

For any feedbacks or suggestions, feel free to contact me at: alexandru.cojan@rakspace.co.uk
