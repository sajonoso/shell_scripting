#!/bin/sh
# Script to backup database through a docker container and maintain certain number of backups
# Relies on ls listing files by name order

APP_NAME=container_with_mysqldump
BACKUP_PATH=/home/user1/backups
COMMON_OPTIONS="--hex-blob --set-gtid-purged=OFF --column-statistics=0"
PROD_BACKUPS_TO_KEEP=90
STAGING_BACKUPS_TO_KEEP=30
PROD_DB_HOST=prod_db_host.example.com
STAGING_DB_HOST=statging_db_host.example.com

backup_database() {
  DB_HOST=$1; DB_USER="$2"; DB_PASS="$3"; DB_NAME=$4
  BACKUP_FILENAME=$BACKUP_PATH/$DB_NAME/${DB_NAME}_`date +\%Y-\%m-\%d_\%H_\%M_\%s`.sql.gz
  echo "Backing up database $DB_NAME"
  docker exec $APP_NAME mysqldump -h$DB_HOST -u"$DB_USER" -p"$DB_PASS" \
  $COMMON_OPTIONS $DB_NAME > $BACKUP_FILENAME
}

delete_old_backups() {
  DB_NAME=$1; BACKUPS_TO_KEEP=$2
  # BACKUPS_TO_KEEP should be minimum of 5 as a fail safe
  if [ $(($BACKUPS_TO_KEEP + 0)) -lt 5 ]; then
    echo "BACKUPS_TO_KEEP too low: $BACKUPS_TO_KEEP"
    return
  fi

  BACKUP_COUNT=$(ls -1 $BACKUP_PATH/$DB_NAME/*.sql.gz | wc -l)

  if [ $(($BACKUP_COUNT + 0)) -gt $(($BACKUPS_TO_KEEP + 0)) ]; then
    echo "Purging old backups $(($BACKUP_COUNT + 0))"
    FILES_TO_DELETE=$(($BACKUP_COUNT - $BACKUPS_TO_KEEP))
    ls -1 $BACKUP_PATH/$DB_NAME/*.sql.gz | head -n $FILES_TO_DELETE | xargs rm
    echo "Removed $FILES_TO_DELETE files"
  fi
}

# Backup database
backup_database $PROD_DB_HOST db_user db_password db_name
delete_old_backups db_name $PROD_BACKUPS_TO_KEEP
