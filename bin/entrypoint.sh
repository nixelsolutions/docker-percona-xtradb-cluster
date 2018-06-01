#!/bin/bash 

set -e

[ "$DEBUG" == "1" ] && set -x && set +e

if [ "${MYSQL_ENABLE_REPLICATION}" == "YES" -o "${MYSQL_ENABLE_REPLICATION}" == "yes" ]; then
  if [ "${MYSQL_SERVER_ID}" == "**ChangeMe**" -o -z "${MYSQL_SERVER_ID}" ]; then
    echo "*** ERROR: you need to define MYSQL_SERVER_ID environment variable - Exiting ..."
    exit 1
  fi

  if [ "${MYSQL_MASTER_HOST}" == "**ChangeMe**" -o -z "${MYSQL_MASTER_HOST}" ]; then
    echo "*** ERROR: you need to define MYSQL_MASTER_HOST environment variable - Exiting ..."
    exit 1
  fi

  if [ "${MYSQL_MASTER_PORT}" == "**ChangeMe**" -o -z "${MYSQL_MASTER_PORT}" ]; then
    echo "*** ERROR: you need to define MYSQL_MASTER_PORT environment variable - Exiting ..."
    exit 1
  fi

  if [ "${MYSQL_REPL_PASSWORD}" == "**ChangeMe**" -o -z "${MYSQL_REPL_PASSWORD}" ]; then
    echo "*** ERROR: you need to define MYSQL_REPL_PASSWORD environment variable - Exiting ..."
    exit 1
  fi
fi

if [ "${MYSQL_ROOT_PASSWORD}" == "**ChangeMe**" -o -z "${MYSQL_ROOT_PASSWORD}" ]; then
   echo "*** ERROR: you need to define MYSQL_ROOT_PASSWORD environment variable - Exiting ..."
   exit 1
fi

HOSTNAME=`hostname -s`

# Delete unix socket
if [ -e ${MYSQL_DATADIR}/mysql.sock -o -e ${MYSQL_DATADIR}/mysql.sock.lock ]; then
  rm -f ${MYSQL_DATADIR}/mysql.sock*
fi

# Backups
mkdir -p ${BACKUPS_PATH}
chown -R mysql:mysql ${BACKUPS_PATH}

# Tmp
mkdir -p ${TMP_PATH}
chown -R mysql:mysql ${TMP_PATH}

# Logs
MYSQL_LOGS_PATH=${LOGS_PATH}/${HOSTNAME}
if [ ! -d ${MYSQL_LOGS_PATH} ]; then
  mkdir -p ${MYSQL_LOGS_PATH}
fi
chown mysql:mysql ${LOGS_PATH}
chmod 770 ${LOGS_PATH}
chown mysql:mysql ${MYSQL_LOGS_PATH}
chmod 770 ${MYSQL_LOGS_PATH}

SUPERVISOR_LOGS_PATH=${LOGS_PATH}/supervisor/${HOSTNAME}
if [ ! -d ${SUPERVISOR_LOGS_PATH} ]; then
  mkdir -p ${SUPERVISOR_LOGS_PATH}
  chown root:syslog ${SUPERVISOR_LOGS_PATH}
  chmod 770 ${SUPERVISOR_LOGS_PATH}
fi
SUPERVISOR_LOGS_PATH_SCAPED=`echo ${SUPERVISOR_LOGS_PATH}/supervisord.log | sed "s/\//\\\\\\\\\//g"`
perl -p -i -e "s/^logfile ?= ?.*/logfile=${SUPERVISOR_LOGS_PATH_SCAPED}/g" /etc/supervisor/conf.d/supervisord.conf

# Configure MySQL
mkdir -p `dirname ${MYSQL_CFG_FILE}`
echo "[mysqld]" > ${MYSQL_CFG_FILE}
echo "port = ${MYSQL_BIND_PORT}" >> ${MYSQL_CFG_FILE}
echo "default_storage_engine = ${MYSQL_STORAGE_ENGINE}" >> ${MYSQL_CFG_FILE}
echo "server_id = ${MYSQL_SERVER_ID}" >> ${MYSQL_CFG_FILE}
echo "#replicate_same_server_id = 0" >> ${MYSQL_CFG_FILE}
echo "auto_increment_increment = ${AUTO_INCREMENT_INCREMENT}" >> ${MYSQL_CFG_FILE}
echo "auto_increment_offset  = ${AUTO_INCREMENT_OFFSET}" >> ${MYSQL_CFG_FILE}
echo "log_bin = binlog" >> ${MYSQL_CFG_FILE}
echo "binlog_format = ROW" >> ${MYSQL_CFG_FILE}
echo "expire_logs_days = ${EXPIRE_LOGS_DAYS}" >> ${MYSQL_CFG_FILE}
echo "max_binlog_size = ${MAX_BINLOG_SIZE}" >> ${MYSQL_CFG_FILE}
echo "gtid_mode = ON" >> ${MYSQL_CFG_FILE}
echo "log_slave_updates = 1" >> ${MYSQL_CFG_FILE}
echo "enforce_gtid_consistency = 1" >> ${MYSQL_CFG_FILE}
echo "innodb_flush_log_at_trx_commit = ${INNODB_FLUSH_LOG_AT_TRX_COMMIT}" >> ${MYSQL_CFG_FILE}
echo "innodb_buffer_pool_instances = ${INNODB_BUFFER_POOL_INSTANCES}" >> ${MYSQL_CFG_FILE}
echo "innodb_io_capacity = ${INNODB_IO_CAPACITY}" >> ${MYSQL_CFG_FILE}
echo "innodb_io_capacity_max = ${INNODB_IO_CAPACITY_MAX}" >> ${MYSQL_CFG_FILE}
echo "slave_parallel_workers = ${SLAVE_PARALLEL_WORKERS}" >> ${MYSQL_CFG_FILE}
echo "slave_parallel_type = ${SLAVE_PARALLEL_TYPE}" >> ${MYSQL_CFG_FILE}

# Configure HAPRoxy
cp -p ${HAPROXY_CFG_FILE}.orig ${HAPROXY_CFG_FILE}
perl -p -i -e "s/HAPROXY_BIND_PORT/${HAPROXY_BIND_PORT}/g" ${HAPROXY_CFG_FILE}
perl -p -i -e "s/HAPROXY_STATS_PORT/${HAPROXY_STATS_PORT}/g" ${HAPROXY_CFG_FILE}
perl -p -i -e "s/# MYSQL NODES HERE.*//g" ${HAPROXY_CFG_FILE}

# Add SERVERID=1 as master!
if [ "${MYSQL_ENABLE_REPLICATION}" == "YES" -o "${MYSQL_ENABLE_REPLICATION}" == "yes" ]; then
  if [ ${MYSQL_SERVER_ID} -eq 1 ]; then
    # If replication is enabled, and I'm SERVERID=1, just add me as the primary master!
    echo "  server db1 127.0.0.1:${MYSQL_BIND_PORT} check port ${MYSQL_BIND_PORT} rise 2 fall 3 on-marked-up shutdown-backup-sessions" >> ${HAPROXY_CFG_FILE}
    # If replication is enabled, and I'm SERVERID=1, just add MASTER_HOST as backup master!
    echo "  server db2 ${MYSQL_MASTER_HOST}:${MYSQL_MASTER_PORT} check port ${MYSQL_MASTER_PORT} rise 2 fall 3 backup" >> ${HAPROXY_CFG_FILE}
  else
    # If replication is enabled, but I'm not SERVERID=1, then add MASTER_HOST as primary master!
    echo "  server db1 ${MYSQL_MASTER_HOST}:${MYSQL_MASTER_PORT} check port ${MYSQL_MASTER_PORT} rise 2 fall 3 on-marked-up shutdown-backup-sessions" >> ${HAPROXY_CFG_FILE}
    # And then, add me as a backup master!
    echo "  server db2 127.0.0.1:${MYSQL_BIND_PORT} check port ${MYSQL_BIND_PORT} rise 2 fall 3 backup" >> ${HAPROXY_CFG_FILE}
  fi
else
  # If replication is not enabled, I'm the only master ...
  echo "  server db1 127.0.0.1:${MYSQL_BIND_PORT} check port ${MYSQL_BIND_PORT} rise 2 fall 3 on-marked-up shutdown-backup-sessions" >> ${HAPROXY_CFG_FILE}
fi

# Start postfix
echo "=> Starting postfix ..."
service postfix start

# Customizing settings
echo "=> Customizing settings ..."
perl -p -i -e "s/%MYSQL_ROOT_PASSWORD%/${MYSQL_ROOT_PASSWORD}/g" /usr/local/bin/check-mysql-locks.sh

if [ "${MYSQL_ENABLE_REPLICATION}" == "YES" -o "${MYSQL_ENABLE_REPLICATION}" == "yes" ]; then
  echo "******** IMPORTANT **********"
  echo
  echo "=> When you start master replication, remember to change master with this statement:"
  echo
  echo "CHANGE MASTER TO MASTER_HOST='${MYSQL_MASTER_HOST}', MASTER_PORT=${MYSQL_MASTER_PORT}, MASTER_USER='${MYSQL_REPL_USER}', MASTER_PASSWORD='${MYSQL_REPL_PASSWORD}', MASTER_AUTO_POSITION=1;"
  echo
  echo "*****************************"
fi

# Initialize MySQL
if [ ! -d ${MYSQL_DATADIR}/${MYSQL_INITIALIZE_DB_FLAG} ]; then
  echo "=> Starting initialized MySQL daemon ..."
  initialize.sh || exit 1
else
  echo "=> I was already initialized, starting MySQL daemon ..."
fi
/usr/bin/supervisord

