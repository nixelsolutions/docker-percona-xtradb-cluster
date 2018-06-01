#!/bin/bash

set -e
set +H

[ "$DEBUG" == "1" ] && set -x && set +e

# Initialize the node
echo "=> Initializing MySQL installation ..."
mysqld --initialize
echo "CREATE USER '${MYSQL_ROOT_USER}'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" > /tmp/init.sql
echo "CREATE USER '${MYSQL_ROOT_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';" >>/tmp/init.sql
echo "GRANT ALL ON *.* TO '${MYSQL_ROOT_USER}'@'%' WITH GRANT OPTION;" >> /tmp/init.sql
echo "UPDATE mysql.user set Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') where user='${MYSQL_ROOT_USER}';" >> /tmp/init.sql
echo "DELETE FROM mysql.user WHERE User='';" >> /tmp/init.sql
echo "DROP DATABASE test;" >> /tmp/init.sql
echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" >> /tmp/init.sql
echo "FLUSH PRIVILEGES;" >> /tmp/init.sql
if [ a"${MYSQL_INITIALIZE_DB_FLAG}" != a"mysql" ]; then
  echo "CREATE DATABASE `basename ${MYSQL_INITIALIZE_DB_FLAG}`;" >> /tmp/init.sql
fi

if [ "${MYSQL_ENABLE_REPLICATION}" == "YES" -o "${MYSQL_ENABLE_REPLICATION}" == "yes" ]; then
  echo "CREATE USER '${MYSQL_REPL_USER}'@'%' IDENTIFIED BY '${MYSQL_REPL_PASSWORD}';" >> /tmp/init.sql
  echo "GRANT RELOAD, LOCK TABLES, REPLICATION CLIENT ON *.* TO '${MYSQL_REPL_USER}'@'%';" >> /tmp/init.sql
echo "GRANT PROCESS ON *.* TO '${MYSQL_CHECK_USER}'@'localhost' IDENTIFIED BY '${MYSQL_CHECK_PASSWORD}';" >> /tmp/init.sql
  echo "FLUSH PRIVILEGES;" >> /tmp/init.sql
fi

# Import an init SQL
if [ "${INIT_SQL}" != "**ChangeMe**" -a ! -z "${INIT_SQL}" ]; then
   # Save the SQL temporary
   wget -O /tmp/init_exteranl.sql "${INIT_SQL}" 
   if [ $? -eq 0 ]; then
      echo "=> I'm importing this SQL file when initializing: ${INIT_SQL}"
      cat /tmp/init_exteranl.sql >> /tmp/init.sql
   fi
fi   

export MYSQL_OPTS="${MYSQL_OPTS} --init-file=/tmp/init.sql"
