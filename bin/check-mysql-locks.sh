#!/bin/bash

MYSQL_ROOT_PASSWORD=%MYSQL_ROOT_PASSWORD%

MAX_LOCKED_QUERIES=500
WAIT_STOP=40

LOCKED_QUERIES=`/usr/bin/mysql -e 'select count(*) from information_schema.processlist where command <> "Sleep" and host <> "localhost"' -ssB -u root -p${MYSQL_ROOT_PASSWORD} 2>/dev/null`
MYSQL_PID=`/usr/bin/pgrep -f /usr/sbin/mysqld`

function force_stop {
  sleep ${WAIT_STOP}
  MYSQL_PID_NEW=`/usr/bin/pgrep -f /usr/sbin/mysqld`
  if [ a"${MYSQL_PID}" == a"${MYSQL_PID_NEW}" ]; then
    echo "Mysql didn't stop, forcing restart ..."
    /usr/bin/pkill -9 -f /usr/sbin/mysqld
  fi
}

if [ a"${LOCKED_QUERIES}" == "a" ]; then
  echo "ERROR: Could not get locked queries, restarting ..."
  /usr/bin/pkill -f /usr/sbin/mysqld
  force_stop
fi

if [ ${LOCKED_QUERIES} -gt ${MAX_LOCKED_QUERIES} ]; then
  echo "Got $LOCKED_QUERIES locked queries, which is greater than maximum ${MAX_LOCKED_QUERIES} - Restarting server ..."
  /usr/bin/pkill -f /usr/sbin/mysqld
  force_stop
fi
