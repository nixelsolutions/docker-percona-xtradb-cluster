FROM ubuntu:14.04

MAINTAINER Manel Martinez <manel@nixelsolutions.com>

ENV DEBIAN_FRONTEND=noninteractive

RUN echo "deb http://repo.percona.com/apt trusty main" > /etc/apt/sources.list.d/percona.list
RUN echo "deb-src http://repo.percona.com/apt trusty main" >> /etc/apt/sources.list.d/percona.list

RUN apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
RUN apt-get update && \
    apt-get -y --force-yes install percona-xtradb-cluster-56 pwgen supervisor openssh-server sshpass xinetd wget

# Install postfix
RUN apt-get update -q -q &&  echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections &&  echo postfix postfix/mynetworks string "127.0.0.0/8" | debconf-set-selections &&  echo postfix postfix/mailname string thecore.io | debconf-set-selections &&  apt-get --yes --force-yes install mailutils postfix &&  postconf -e mydestination="localhost.localdomain, localhost" &&  postconf -e smtpd_banner='$myhostname ESMTP $mail_name' &&  postconf -# myhostname &&  postconf -e inet_protocols=ipv4

ENV PXC_SST_PASSWORD **ChangeMe**
ENV PXC_ROOT_PASSWORD **ChangeMe**
ENV PXC_INIT_SQL **ChangeMe**
ENV PXC_NODES **ChangeMe**
ENV MY_IP **ChangeMe**

ENV PXC_VOLUME /var/lib/mysql
ENV PXC_TMP /tmp
ENV PXC_LOGS_PATH /var/log/mysql
ENV PXC_CONF /etc/mysql/conf.d/pxc.cnf
ENV PXC_BOOTSTRAP_FLAG ${PXC_VOLUME}/pxcbootstrapped
ENV SSH_OPTS -p ${SSH_PORT} -o ConnectTimeout=20 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
ENV SSH_USER root
ENV SSH_PORT 2222
ENV MYSQL_PORT 3306
ENV MYSQLCHK_PORT 9200
ENV PXC_GROUP_PORT 4567
ENV PXC_SST_PORT 4444
ENV PXC_IST_PORT 4568

ENV DEBUG 0

RUN mkdir -p /var/log/supervisor /var/run/sshd
RUN perl -p -i -e "s/^Port .*/Port ${SSH_PORT}/g" /etc/ssh/sshd_config
RUN perl -p -i -e "s/#?PasswordAuthentication .*/PasswordAuthentication yes/g" /etc/ssh/sshd_config
RUN perl -p -i -e "s/#?PermitRootLogin .*/PermitRootLogin yes/g" /etc/ssh/sshd_config
RUN grep ClientAliveInterval /etc/ssh/sshd_config >/dev/null 2>&1 || echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config

VOLUME ["${PXC_VOLUME}", "${PXC_LOGS_PATH}"]

EXPOSE ${SSH_PORT}
EXPOSE ${MYSQL_PORT}
EXPOSE ${MYSQLCHK_PORT}
EXPOSE ${PXC_GROUP_PORT}
EXPOSE ${PXC_SST_PORT}
EXPOSE ${PXC_IST_PORT}

RUN mkdir -p /usr/local/bin
RUN echo "mysqlchk ${MYSQLCHK_PORT}/tcp #mysqlchk" >> /etc/services
ADD ./bin /usr/local/bin
RUN chmod +x /usr/local/bin/*.sh
ADD ./etc /etc

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
