FROM ubuntu:14.04

MAINTAINER Manel Martinez <manel@nixelsolutions.com>

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python-software-properties software-properties-common language-pack-en-base
RUN add-apt-repository ppa:vbernat/haproxy-1.5

RUN apt-get update && \
    apt-get -y install wget && \
    wget https://repo.percona.com/apt/percona-release_0.1-4.$(lsb_release -sc)_all.deb && \
    dpkg -i percona-release_0.1-4.$(lsb_release -sc)_all.deb

RUN apt-get update && \
    apt-get -y --force-yes install percona-server-server-5.7 percona-xtrabackup haproxy curl libaio1 supervisor

# Install postfix
RUN apt-get update -q -q &&  echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections &&  echo postfix postfix/mynetworks string "127.0.0.0/8" | debconf-set-selections &&  echo postfix postfix/mailname string thecore.io | debconf-set-selections &&  apt-get --yes --force-yes install mailutils postfix &&  postconf -e mydestination="localhost.localdomain, localhost" &&  postconf -e smtpd_banner='$myhostname ESMTP $mail_name' &&  postconf -# myhostname &&  postconf -e inet_protocols=ipv4

ENV MYSQL_CFG_FILE /etc/mysql/conf.d/extra.cnf
ENV HAPROXY_CFG_FILE /etc/haproxy/haproxy.cfg
ENV MYSQL_STORAGE_ENGINE InnoDB
ENV MYSQL_EXPIRE_LOGS_DAYS 30

ENV MYSQL_ROOT_USER root
ENV MYSQL_ROOT_PASSWORD **ChangeMe**
ENV MYSQL_INITIALIZE_DB_FLAG mysql
ENV MYSQL_INIT **ChangeMe**

ENV MYSQL_ENABLE_REPLICATION NO
ENV MYSQL_SERVER_ID **ChangeMe**
ENV AUTO_INCREMENT_INCREMENT 2
ENV AUTO_INCREMENT_OFFSET 1
ENV EXPIRE_LOGS_DAYS 5
ENV MAX_BINLOG_SIZE 100M
ENV MYSQL_MASTER_HOST **ChangeMe**
ENV MYSQL_MASTER_PORT 3307
ENV MYSQL_REPL_USER repl-user
ENV MYSQL_REPL_PASSWORD **ChangeMe**
ENV MYSQL_CHECK_USER mysqlcheckuser
ENV MYSQL_CHECK_PASSWORD mysqlch3ckp4ssw0rd

ENV INNODB_FLUSH_LOG_AT_TRX_COMMIT 1
ENV INNODB_BUFFER_POOL_INSTANCES 8
ENV INNODB_IO_CAPACITY 1000
ENV INNODB_IO_CAPACITY_MAX 2000
ENV SLAVE_PARALLEL_WORKERS 10
ENV SLAVE_PARALLEL_TYPE DATABASE

ENV MYSQL_BIND_PORT 3307
ENV HAPROXY_BIND_PORT 3306
ENV HAPROXY_STATS_PORT 1936

ENV MYSQL_DATADIR /var/lib/mysql
ENV LOGS_PATH /var/log/mysql
ENV BACKUPS_PATH /backup/mysql
ENV TMP_PATH /tmp

ENV DEBUG 0

EXPOSE ${MYSQL_BIND_PORT}
EXPOSE ${HAPROXY_BIND_PORT}
EXPOSE ${HAPROXY_STATS_PORT}

VOLUME ${MYSQL_DATADIR}
VOLUME ${LOGS_PATH}
VOLUME ${BACKUPS_PATH}

ADD ./etc /etc
RUN mkdir -p /usr/local/bin
ADD ./bin /usr/local/bin
RUN chmod +x /usr/local/bin/*.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
