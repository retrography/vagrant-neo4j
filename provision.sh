#!/bin/bash


if `tty -s`; then
   mesg n
fi

sed -i 's/^mesg n$/tty -s \&\& mesg n/g' /root/.profile


echo
echo "Updating repositories..."

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886
echo 'deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' > /etc/apt/sources.list.d/java.list 
echo 'deb-src http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' >> /etc/apt/sources.list.d/java.list 

wget -O - http://debian.neo4j.org/neotechnology.gpg.key | apt-key add -
echo 'deb http://debian.neo4j.org/repo stable/' > /etc/apt/sources.list.d/neo4j.list

apt-get -qq update

# Java 8
echo 
echo "Installing Java..."

echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo apt-get install -qq oracle-java8-installer
sudo apt-get install -qq oracle-java8-set-default

echo
echo "Installing Neo4j Enterprise..."
apt-get install -qq neo4j-enterprise


echo
echo "Tuning Linux..."
service neo4j-service stop
mkdir -p /data/neo/graph.db

### Fix Ulimit

echo "session required pam_limits.so" | sudo tee -a "/etc/pam.d/su"
echo "session required pam_limits.so" | sudo tee -a "/etc/pam.d/common-session"
echo "neo4j soft  nofile 100000" | tee -a '/etc/security/limits.conf'
echo "neo4j hard  nofile 150000"  | tee -a '/etc/security/limits.conf'

### Fix Hugepage
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
sed -i '/^exit/ d' /etc/rc.local
cat <<'EOFFOE' | tee -a /etc/rc.local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
   echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
   echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi

exit 0
EOFFOE
 

echo
echo "Updating Neo4j Config..."
sed -i "s/\(^org\.neo4j\.server\.database\.location=\).*/\1\/data\/neo\/graph\.db/" /etc/neo4j/neo4j-server.properties
sed -i "s/\(^dbms\.security\.auth_enabled=\).*/\1false/" /etc/neo4j/neo4j-server.properties
sed -i "s/^\(#\)\(org\.neo4j\.server\.webserver\.address=\).*/\20\.0\.0\.0/" /etc/neo4j/neo4j-server.properties
sed -i "s/^#\?\(keep_logical_logs=\).*/\11G size/" /etc/neo4j/neo4j.properties
sed -i "s/^\(#\)\(remote_shell_host=\).*/\20\.0\.0\.0/" /etc/neo4j/neo4j.properties
sed -i "s/^\(#\)\(remote_shell_enabled=\).*/\2true/" /etc/neo4j/neo4j.properties
sed -i "s/^\(#\)\(allow_store_upgrade=\).*/\2true/" /etc/neo4j/neo4j.properties
#echo "execution_guard_enabled=true" >> /opt/neo4j/conf/neo4j.properties
#echo "org.neo4j.server.webserver.limit.executiontime=30000" >> /opt/neo4j/conf/neo4j-server.properties

echo
echo "Starting Neo4j..."
service neo4j-service start
