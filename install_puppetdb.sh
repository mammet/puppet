# assuming everything is working -- which if you used the previous two scripts,
# everything should...

# this will install puppetdb using the puppet module

# clear yum cache
yum clean all

# install the module
puppet module install puppetlabs/puppetdb

# use puppet to install puppetdb
puppet resource package puppetdb ensure=latest --server ${FQDN}

# install sun java (might have to refuckulate this URL)
cd /root/
wget http://javadl.sun.com/webapps/download/AutoDL?BundleId=81811
mv jre* jre-7u45-linux-x64.rpm
rpm -Uvh jre-7u45-linux-x64.rpm
alternatives --install /usr/bin/java java /usr/java/latest/bin/java 200000

# this should work
java -version

# config puppetdb
cat << EOF > /etc/puppet/puppetdb.conf
[main]
server = ${FQDN}
port = 8081
EOF

echo "storeconfigs = true" >> /etc/puppet/puppet.conf
echo "storeconfigs_backend = puppetdb" >> /etc/puppet/puppet.conf
echo "reports = store,puppetdb,http" >> /etc/puppet/puppet.conf
echo "reporturl = http://${FQDN}:3000/reports/upload" >> /etc/puppet/puppet.conf
echo "node_terminus = exec" >> /etc/puppet/puppet.conf
echo "external_nodes = /usr/bin/env PUPPET_DASHBOARD_URL=http://${FQDN}:3000 /opt/puppet-dashboard/bin/external_node" >> /etc/puppet/puppet.conf

cat << EOF > /etc/puppet/routes.yaml
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
EOF

# make sure puppetdb-terminus is installed
yum -y install puppetdb-terminus

# start and enable the service
puppet resource service puppetdb ensure=running enable=true

# restart
service puppetmaster restart
service puppetdb restart
