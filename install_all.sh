# tested on Scientific Linux 6.4 x64

# for a clean minimal installation and configuration of SL6,
# see this gist: https://gist.github.com/boardstretcher/6655517

# this will install:
 # ruby
 # mysql
 # puppet
 # puppet dashboard
 # puppetdb
 # passenger
 # activemq
 # mcollective

echo "the steps: set these variables"

echo "hostname: ${HOSTNAME}"
echo "domain: ${DOMAIN}"

echo "then edit this script and change any instance of 'somepassword' to something else"

echo "then remove exit; from this file and run it"

exit;

# most current version (12-Apr-2013)
rpm -ivh https://yum.puppetlabs.com/el/6.4/products/x86_64/puppetlabs-release-6-7.noarch.rpm
rpm -ivh http://mirrors.mit.edu/epel/6/x86_64/epel-release-6-8.noarch.rpm

# update system, install needed programs
yum update -y
yum install -y vim ntp wget openssh-clients openssl-devel zlib-devel \
    gcc gcc-c++ make autoconf readline-devel curl-devel expat-devel \ 
    gettext-devel 

# get newest ruby/libyaml
wget http://pyyaml.org/download/libyaml/yaml-0.1.4.tar.gz
tar xzvf yaml-0.1.4.tar.gz; cd yaml-0.1.4
./configure --prefix=/usr/local
make; make install

wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-p0.tar.gz
tar xzvf ruby-1.9.3-p0.tar.gz; cd ruby-1.9.3-p0
./configure --prefix=/usr/local --enable-shared --disable-install-doc --with-opt-dir=/usr/local/lib
make; make install

ruby -v; gem --version

# fix time
ntpdate pool.ntp.org

################# reboot!
sleep 10; reboot
 
# install puppet programs
yum install -y puppet-server puppetdb-terminus puppetdb puppet-dashboard mysql mysql-server
 
# configure puppet
echo "*" > /etc/puppet/autosign.conf
 
cat << EOF > /etc/puppet/puppetdb.conf
[main]
server = ${HOSTNAME}
port = 8081
EOF
 
cat << EOF > /etc/puppet/routes.yaml
---
master:
facts:
terminus: puppetdb
cache: yaml
EOF
 
cat << EOF > /etc/puppet/puppet.conf
[master]
storeconfigs = true
storeconfigs_backend = puppetdb
EOF
 
puppet cert --generate ${HOSTNAME}
rm -f /var/lib/puppet/ssl/certs/localhost.localdomain.pem
/usr/sbin/puppetdb-ssl-setup
service puppetmaster start
service puppetdb start
chkconfig puppetdb on
chkconfig puppetmaster on
 
cat << EOF > /etc/puppet/fileserver.conf
[files]
path /etc/puppet/files
allow *.${DOMAIN}
EOF
 
service mysqld start
chkconfig mysqld on
mysql_secure_installation
mysql -u root -e "CREATE DATABASE dashboard";
mysql -u root -e "CREATE DATABASE dashboard_dev";
mysql -u root -e "GRANT ALL PRIVILEGES ON dashboard.* TO dashboard@localhost IDENTIFIED BY 'somepassword';"
mysql -u root -e "GRANT ALL PRIVILEGES ON dashboard_dev.* TO dashboard_dev@localhost IDENTIFIED BY 'somepassword';"
 
cat << EOF > /usr/share/puppet-dashboard/config/database.yml
production:
database: dashboard
username: dashboard
password: somepassword
encoding: utf8
adapter: mysql
development:
database: dashboard_dev
username: dashboard_dev
password: somepassword
encoding: utf8
adapter: mysql
EOF

cd /usr/share/puppet-dashboard
rake RAILS_ENV=development db:migrate
rake RAILS_ENV=production db:migrate

cat << EOF > /etc/puppet/puppet.conf
[agent]
report = true
[master]
reports = store, http
reporturl = http://${HOSTNAME}:3000/reports/upload"
EOF
