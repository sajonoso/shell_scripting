#!/bin/sh

get_postgresql_env() {
  # read environment variables
  . ./.env

  # separate fields in format DATABASE_URL=postgres://localuser:Localpass1234@localhost:5432/localdb
  IFS='/' read -r x x TMP_USER_PASS_HOST_PORT DB_NAME <<_EOF_
$DATABASE_URL
_EOF_
  IFS='@' read -r TMP_USER_PASS TMP_HOST_PORT <<_EOF_
$TMP_USER_PASS_HOST_PORT
_EOF_
  IFS=':' read -r DB_USER DB_PASS <<_EOF_
$TMP_USER_PASS
_EOF_
  IFS=':' read -r DB_HOST DB_PORT <<_EOF_
$TMP_HOST_PORT
_EOF_
  # clean up temporary variables
  unset TMP_USER_PASS_HOST_PORT; unset TMP_USER_PASS; unset TMP_HOST_PORT
}

get_mysql_env() {
  # read environment variables
  . ./.env

  # separate fields in format MYSQL_URL=mysql:host=localhost;port=3306;dbname=my_db;user=root;password=mypass123
  TMP_URL=${MYSQL_URL#*:}
  IFS=';' read -r TMP_HOST TMP_PORT TMP_DBNAME TMP_USER TMP_PASS <<_EOF_
$TMP_URL
_EOF_
  DB_HOST=${TMP_HOST#*=}
  DB_PORT=${TMP_PORT#*=}
  DB_NAME=${TMP_DBNAME#*=}
  DB_USER=${TMP_USER#*=}
  DB_PASS=${TMP_PASS#*=}

  # clean up temporary variables
  unset TMP_URL; unset TMP_HOST; unset TMP_PORT; unset TMP_DBNAME; unset TMP_USER; unset TMP_PASS
}

app_test() {
  get_postgresql_env
  # get_mysql_env
  echo "DB_HOST: $DB_HOST"
  echo "DB_PORT: $DB_PORT"
  echo "DB_USER: $DB_USER"
  echo "DB_PASS: $DB_PASS"
  echo "DB_NAME: $DB_NAME"
}

if [ "$1" = "test" ]; then app_test; exit; fi
