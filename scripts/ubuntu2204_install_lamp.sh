#!/usr/bin/env bash

# ubuntu2204_install_lamp.sh
# LAMP installer setting up Apache, PHP, MySQL, Holland and attempts to
# set some sane defaults.
#
# Copyright (c) 2020, Stephen Lang
# All rights reserved.
#
# Git repository available at:
# https://github.com/stephenlang/bash-lamp-installer
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

PHP_VERSION=7.4
INSTALL_PHPMYADMIN="False"

# prevent all the restart services prompt
export DEBIAN_FRONTEND=noninteractive

#################################################
# Base Package Installation Tasks
#################################################

# Update system
apt -y update
apt -y upgrade

# Install base packages
apt -y install \
    cron \
    openssh-server \
    vim \
    sysstat \
    man-db \
    wget \
    rsync \
    screen

# make sure SSL CA certs are up-to-date
apt -y install \
    ca-certificates \
    update-ca-certificates
cd /etc/ssl/certs
ln -s ca-certificates.crt ca-bundle.crt

#################################################
# Web Server Package Installation Tasks
#################################################

# Apache variables
timeout=30
keep_alive=On
keep_alive_requests=120
keep_alive_timeout=5
prefork_start_servers=4
prefork_min_spare_servers=4
prefork_max_spare_servers=9
prefork_server_limit=$(free -m | grep "Mem:" | awk '{print $2/2/15}' | xargs printf "%.0f")
prefork_max_clients=$(free -m | grep "Mem:" | awk '{print $2/2/15}' | xargs printf "%.0f")
prefork_max_requests_per_child=1000
prefork_listen_backlog=$(free -m | grep "Mem:" | awk '{print $2/2/15*2}' | xargs printf "%.0f")

# PHP variables
max_execution_time=30
memory_limit=64M
error_reporting='E_ALL \& ~E_NOTICE | E_DEPRECATED'
post_max_size=8M
upload_max_filesize=2M
short_open_tag=On
expose_php=Off
session_save_path='/var/lib/php/sessions'

# Add the Ondrej PPA to get specific PHP version
LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
# LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/apache2

# Install Apache and PHP packages
apt-get -y --ignore-missing install \
    apache2 \
    apache2-utils \
    libapache2-mod-php"${PHP_VERSION}"

apt-get -y --ignore-missing install \
    php"${PHP_VERSION}"-cli \
    php"${PHP_VERSION}"-pear \
    php"${PHP_VERSION}"-mysql \
    php"${PHP_VERSION}"-gd \
    php"${PHP_VERSION}"-phpdbg \
    php"${PHP_VERSION}"-curl \
    php"${PHP_VERSION}"-bcmath \
    php"${PHP_VERSION}"-opcache

/usr/sbin/a2dismod mpm_event

/usr/sbin/a2enmod \
    access_compat \
    alias \
    auth_basic \
    authn_core \
    authn_file \
    authz_core \
    authz_groupfile \
    authz_host \
    authz_user \
    autoindex \
    deflate \
    dir \
    env \
    filter \
    mime \
    mpm_prefork \
    negotiation \
    rewrite \
    setenvif \
    socache_shmcb \
    ssl \
    status

/usr/sbin/a2enmod vhost_alias # needed to support VirtualDocumentRoot in conf
/usr/sbin/a2enmod php"${PHP_VERSION}"

/usr/sbin/phpenmod opcache

# Copy over templates
mkdir /var/www/vhosts
mkdir -p /var/lib/php/sessions
chown root:www-data /var/lib/php/sessions
chmod 770 /var/lib/php/sessions
cp ../templates/ubuntu2204/apache/default /etc/apache2/sites-available/
cp ../templates/ubuntu2204/apache/apache2.conf /etc/apache2/apache2.conf
cp ../templates/ubuntu2204/apache/ports.conf /etc/apache2/ports.conf
cp ../templates/ubuntu2204/apache/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf
cp ../templates/ubuntu2204/apache/ssl.conf /etc/apache2/mods-available/ssl.conf
cp ../templates/ubuntu2204/apache/status.conf /etc/apache2/mods-available/status.conf
cp ../templates/ubuntu2204/php${PHP_VERSION}/php.ini /etc/php/${PHP_VERSION}/apache2/php.ini

# Setup Apache variables
sed -i "s/\$timeout/$timeout/g" /etc/apache2/apache2.conf
sed -i "s/\$keep_alive_setting/$keep_alive/g" /etc/apache2/apache2.conf
sed -i "s/\$keep_alive_requests/$keep_alive_requests/g" /etc/apache2/apache2.conf
sed -i "s/\$keep_alive_timeout/$keep_alive_timeout/g" /etc/apache2/apache2.conf
sed -i "s/\$prefork_start_servers/$prefork_start_servers/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_min_spare_servers/$prefork_min_spare_servers/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_max_spare_servers/$prefork_max_spare_servers/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_server_limit/$prefork_server_limit/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_max_clients/$prefork_max_clients/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_max_requests_per_child/$prefork_max_requests_per_child/g" /etc/apache2/mods-available/mpm_prefork.conf
sed -i "s/\$prefork_listen_backlog/$prefork_listen_backlog/g" /etc/apache2/mods-available/mpm_prefork.conf

# Setup PHP variables
sed -i "s/\$memory_limit/$memory_limit/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$short_open_tag/$short_open_tag/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$expose_php/$expose_php/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$max_execution_time/$max_execution_time/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$error_reporting/$error_reporting/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$post_max_size/$post_max_size/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s/\$upload_max_filesize/$upload_max_filesize/g" /etc/php/${PHP_VERSION}/apache2/php.ini
sed -i "s@\$session_save_path@$session_save_path@g" /etc/php/${PHP_VERSION}/apache2/php.ini

# Secure /server-status behind htaccess
srvstatus_htuser=serverinfo
srvstatus_htpass=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)
echo "$srvstatus_htuser $srvstatus_htpass" >/root/.serverstatus
htpasswd -b -c /etc/apache2/status-htpasswd $srvstatus_htuser $srvstatus_htpass

# Restart Apache to apply new settings
systemctl enable apache2
systemctl restart apache2

# Open up ports 80 and 443 in UFW
ufw allow 80
ufw allow 443

#################################################
# MySQL Server Package Installation Tasks
#################################################

# MySQL variables
# Using defaults for the time being
mysqlrootpassword=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)

# Install MySQL packages
export DEBIAN_FRONTEND=noninteractive
apt-get -y --ignore-missing install \
    mysql-server \
    mysql-client \
    libmysqlclient-dev
mkdir -p /etc/mysql/conf.d
mkdir -p /var/lib/mysqltmp
chown mysql:mysql /var/lib/mysqltmp

# Copy over templates
# Using defaults for the time being

# Setup MYSQL variables
# Using defaults for the time being

# Set some basic security stuff within MYSQL
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$mysqlrootpassword';"
mysql -e "DROP USER ''@'localhost'"
mysql -e "DROP USER ''@'$(hostname)'"
mysql -e "DROP DATABASE test"
mysql -e "FLUSH PRIVILEGES"

# Set MySQL root password in /root/.my.cnf
cp ../templates/ubuntu2204/mysql/.my.cnf /root/.my.cnf
sed -i "s/\$mysqlrootpassword/$mysqlrootpassword/g" /root/.my.cnf

# Restart MySQL to apply changes
rm -f /var/lib/mysql/ib_logfile0
rm -f /var/lib/mysql/ib_logfile1
systemctl enable mysql
systemctl restart mysql

#################################################
# Holland Installation Tasks
#################################################

# Setup Holland repo
. /etc/os-release
echo "deb https://download.opensuse.org/repositories/home:/holland-backup/x${NAME}_${VERSION_ID}/ ./" >>/etc/apt/sources.list
wget -qO - https://download.opensuse.org/repositories/home:/holland-backup/x${NAME}_${VERSION_ID}/Release.key | apt-key add -

# Install Holland packages
apt-get -y --ignore-missing update
apt-get -y --ignore-missing install \
    holland \
    python3-mysqldb

# Copy over templates and configure backup directory
cp ../templates/ubuntu2204/holland/default.conf /etc/holland/backupsets/default.conf

# Setup nightly cronjob
echo "30 3 * * * root /usr/sbin/holland -q bk" >/etc/cron.d/holland

# Run holland
/usr/sbin/holland -q bk

#################################################
# PHPMyAdmin Installation Tasks
#################################################

# PHPMyAdmin variables
htuser=serverinfo
htpass=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)

# Setup PHPMyAdmin variables
echo "$htuser $htpass" >/root/.phpmyadminpass

if [ $INSTALL_PHPMYADMIN = "True" ]; then
    # Install PHPMyAdmin package
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y --ignore-missing install phpmyadmin

    # Copy over templates
    cp ../templates/ubuntu2204/phpmyadmin/phpMyAdmin.conf /etc/phpmyadmin/phpMyAdmin.conf

    # Set PHPMyAdmin before htaccess file
    htpasswd -b -c /etc/phpmyadmin/phpmyadmin-htpasswd $htuser $htpass

    # Symlink in apache config and restart apache
    ln -s /etc/phpmyadmin/phpMyAdmin.conf /etc/apache2/conf-enabled/phpMyAdmin.conf
    systemctl restart apache2
else
    echo "PhpMyAdmin isn't installed due to the choice of the user!"
fi

# read -n1 -s -r -p $'Press space to continue...\n' key
apt -y autoremove

#################################################
# Setup Report
#################################################

# Setup report variables
txtbld=$(tput bold)
lightblue=$(tput setaf 6)
nc=$(tput sgr0)
real_ip=$(curl --silent -4 icanhazip.com 2>&1)

# Generate setup report

cat <<EOF >/root/setup_report
${txtbld}---------------------------------------------------------------
                 LAMP Installation Complete
---------------------------------------------------------------${nc}

The LAMP installation has been completed!  Some important information is
posted below.  A copy of this setup report exists in /root/setup_report.

${txtbld}---------------------------------------------------------------
                 Security Credentials
---------------------------------------------------------------${nc}

${lightblue}Apache Server Status URL:${nc}   http://$real_ip/server-status
${lightblue}Apache Server Status User:${nc}  serverinfo
${lightblue}Apache Server Status Pass:${nc}  $srvstatus_htpass

${lightblue}PHPMyAdmin URL:${nc}  http://$real_ip/phpmyadmin
${lightblue}PHPMyAdmin User:${nc} serverinfo / root
${lightblue}PHPMyAdmin Pass:${nc} $htpass / $mysqlrootpassword

${lightblue}MySQL Root User:${nc}  root
${lightblue}MySQL Root Pass:${nc}  $mysqlrootpassword

** For security purposes, there is an htaccess file in front of phpmyadmin.
So when the popup window appears, use the serverinfo username and password.
Once your on the phpmyadmin landing page, use the root MySQL credentials.

If you lose this setup report, the credentails can be found in:
${lightblue}Apache Server Status:${nc}  /root/.serverstatus
${lightblue}PHPMyAdmin:${nc}            /root/.phpmyadmin
${lightblue}MySQL Credentials:${nc}     /root/.my.cnf

${txtbld}---------------------------------------------------------------
                 Nightly MySQL Backups
---------------------------------------------------------------${nc}

MySQL backups are being performed via Holland (www.hollandbackup.org) and
is set to run nightly at 3:30AM server time.

The critical information about Holland is below:

${lightblue}Backup directory:${nc}  /var/spool/holland
${lightblue}Backups run time:${nc}  Nightly at 3:30AM server time
${lightblue}Retention rate:${nc}    7 days

${lightblue}Holland log file:${nc}  /var/log/holland/holland.log
${lightblue}Holland configs:${nc}   /etc/holland/holland.conf
                   /etc/holland/backupsets/default.conf
                   /etc/cron.d/holland

${txtbld}---------------------------------------------------------------${nc}

EOF

cat /root/setup_report
