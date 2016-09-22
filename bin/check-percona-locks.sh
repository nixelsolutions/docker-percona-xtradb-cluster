#!/bin/bash

PXC_ROOT_PASSWORD=%PXC_ROOT_PASSWORD%

MAX_LOCKED_QUERIES=500

LOCKED_QUERIES=`/usr/bin/mysql -e 'select count(*) from information_schema.processlist where command <> "Sleep" and host <> "localhost"' -ssB -u root -p${PXC_ROOT_PASSWORD} 2>/dev/null`

if [ ${LOCKED_QUERIES} -gt ${MAX_LOCKED_QUERIES} ]; then
  echo "Got $LOCKED_QUERIES locked queries, which is greater than maximum ${MAX_LOCKED_QUERIES} - Restarting server ..."
  /usr/bin/supervisorctl restart mysql  
fi
