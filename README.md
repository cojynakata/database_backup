# Database Backup Scheduler

This is a simple bash script designed to help setting up scheduled local/remote mysql database backups.

Method 1) Holland agent (http://hollandbackup.org)
  NOTE: this method requires mysqldump and mysqlshow packages to be installed on the system and that a mysql connection to be available to the database
  PROCESS WALKTHROUGH:
  - it will install the holland packages and holland-mysqldump plugin (and if needed also the holland repository); the supported distributions are Centos/RHEL 5/6/7, Debian7 and Ubuntu 12.xx, 14.xx
  - it will query and set the default holland backup location
  - it will create a new holland backupset
  - it will query for the database connection details, test the connection and save them to /etc/holland/backupsets/<BACKUP_NAME>.conf
  - it will ask the for the backup retention period and update the "backups-to-keep" parameter in the holland backupset
  - it will ask the frequency of the backups and create a cronfile named "holland" under the corresponding /etc/cron.<FREQUENCY>/ directory

