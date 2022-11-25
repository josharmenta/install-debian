#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

TAG=master
CONFIG_REPO=
TOKEN=

###read args
if [[ "$1" != "" ]]; then
    TAG="$1"
fi
if [[ "$2" != "" ]]; then
    CONFIG_REPO="$2"
fi
if [[ "$3" != "" ]]; then
    TOKEN="$3"
fi

XMS=2048m
XMX=4096m
XSS=512k
PERM=256m

###stop services
systemctl stop cron
systemctl stop apache2
systemctl stop tomcat9

###re-create /ctsms directory with default-config and master-data
mv /ctsms/external_files /tmp/external_files/
rm /ctsms/ -rf
mkdir /ctsms
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/dbtool.sh -O /ctsms/dbtool.sh
chown ctsms:ctsms /ctsms/dbtool.sh
chmod 755 /ctsms/dbtool.sh
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/clearcache.sh -O /ctsms/clearcache.sh
chown ctsms:ctsms /ctsms/clearcache.sh
chmod 755 /ctsms/clearcache.sh
if [ -z "$CONFIG_REPO" ] || [ -z "$TOKEN" ]; then
  wget --no-verbose --no-check-certificate --content-disposition https://github.com/phoenixctms/config-default/archive/$TAG.tar.gz -O /ctsms/config.tar.gz
else
  wget --no-verbose --no-check-certificate --header "Authorization: token $TOKEN" --content-disposition https://github.com/$CONFIG_REPO/archive/$TAG.tar.gz -O /ctsms/config.tar.gz
fi
tar -zxvf /ctsms/config.tar.gz -C /ctsms --strip-components 1
rm /ctsms/config.tar.gz -f
if [ -f /ctsms/install/environment ]; then
  source /ctsms/install/environment
fi
sed -r -i "s/-Xms[^ ]+/-Xms$XMS/" /ctsms/dbtool.sh
sed -r -i "s/-Xmx[^ ]+/-Xmx$XMX/" /ctsms/dbtool.sh
sed -r -i "s/-Xss[^ ]+/-Xss$XSS/" /ctsms/dbtool.sh
sed -r -i "s/-XX:ReservedCodeCacheSize=[^ ]+/-XX:ReservedCodeCacheSize=$PERM/" /ctsms/dbtool.sh
sed -r -i "s/^JAVA_OPTS.+/JAVA_OPTS=\"-server -Djava.awt.headless=true -Xms$XMS -Xmx$XMX -Xss$XSS -XX:+UseParallelGC -XX:MaxGCPauseMillis=1500 -XX:GCTimeRatio=9 -XX:+CMSClassUnloadingEnabled -XX:ReservedCodeCacheSize=$PERM\"/" /etc/default/tomcat9
wget --no-verbose https://api.github.com/repos/phoenixctms/master-data/tarball/$TAG -O /ctsms/master-data.tar.gz
mkdir /ctsms/master_data
tar -zxvf /ctsms/master-data.tar.gz -C /ctsms/master_data --strip-components 1
rm /ctsms/master-data.tar.gz -f
chown ctsms:ctsms /ctsms -R
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/update -O /ctsms/update
chmod 755 /ctsms/update
rm /ctsms/external_files/ -rf
mv /tmp/external_files /ctsms/

###build phoenix
mkdir /ctsms/build
cd /ctsms/build
git clone https://github.com/phoenixctms/ctsms
cd /ctsms/build/ctsms
if [ "$TAG" != "master" ]; then
  git checkout tags/$TAG -b $TAG
fi
VERSION=$(grep -oP '<application.version>\K[^<]+' /ctsms/build/ctsms/pom.xml)
COMMIT=$(git rev-parse --short HEAD)
sed -r -i "s/<application.version>([^<]+)<\/application.version>/<application.version>\1 [$COMMIT]<\/application.version>/" /ctsms/build/ctsms/pom.xml
UUID=$(sed -n "s/^\s*<application\.uuid>\([^<]\+\)<\/application\.uuid>\s*$/\1/p" /ctsms/build/ctsms/pom.xml)
if [ -z "$UUID" ] then
  UUID=$(cat /proc/sys/kernel/random/uuid)
fi
sed -r -i "s/<application\.uuid><\/application\.uuid>/<application.uuid>$UUID<\/application.uuid>/" /ctsms/build/ctsms/pom.xml
mvn install -DskipTests
if [ ! -f /ctsms/build/ctsms/web/target/ctsms-$VERSION.war ]; then
  # maybe we have more luck with dependency download on a 2nd try:
  mvn install -DskipTests
fi
mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=create
mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=drop

###install or remove packages
apt-get -q -y -o=Dpkg::Use-Pty=0 install postgresql-plperl
sudo -u postgres psql ctsms < /ctsms/build/ctsms/core/db/dbtool.sql

###apply database changes
sudo -u ctsms psql -U ctsms ctsms < /ctsms/build/ctsms/core/db/schema-up-$TAG.sql

###deploy .war
chmod 755 /ctsms/build/ctsms/web/target/ctsms-$VERSION.war
rm /var/lib/tomcat9/webapps/ROOT/ -rf
cp /ctsms/build/ctsms/web/target/ctsms-$VERSION.war /var/lib/tomcat9/webapps/ROOT.war
systemctl start tomcat9

###update bulk-processor
wget --no-verbose --no-check-certificate --content-disposition https://github.com/phoenixctms/bulk-processor/archive/$TAG.tar.gz -O /ctsms/bulk-processor.tar.gz
tar -zxvf /ctsms/bulk-processor.tar.gz -C /ctsms/bulk_processor --strip-components 1
perl /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/minify.pl --folder=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup
mkdir /ctsms/bulk_processor/output
chown ctsms:ctsms /ctsms/bulk_processor -R
chmod 755 /ctsms/bulk_processor -R
chmod 777 /ctsms/bulk_processor/output -R
rm /ctsms/bulk-processor.tar.gz -f
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/ecrfdataexport.sh -O /ctsms/ecrfdataexport.sh
chown ctsms:ctsms /ctsms/ecrfdataexport.sh
chmod 755 /ctsms/ecrfdataexport.sh
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/ecrfdataimport.sh -O /ctsms/ecrfdataimport.sh
chown ctsms:ctsms /ctsms/ecrfdataimport.sh
chmod 755 /ctsms/ecrfdataimport.sh
wget --no-verbose https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/inquirydataexport.sh -O /ctsms/inquirydataexport.sh
chown ctsms:ctsms /ctsms/inquirydataexport.sh
chmod 755 /ctsms/inquirydataexport.sh

###update permissions and criterions
sudo -u ctsms /ctsms/dbtool.sh -icp /ctsms/master_data/criterion_property_definitions.csv
sudo -u ctsms /ctsms/dbtool.sh -ipd /ctsms/master_data/permission_definitions.csv
/ctsms/clearcache.sh

###render workflow state diagram images from db and include them for tooltips
cd /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/Render
./render.sh
cd /ctsms/build/ctsms
mvn -f web/pom.xml -Dmaven.test.skip=true
chmod 755 /ctsms/build/ctsms/web/target/ctsms-$VERSION.war
systemctl stop tomcat9
rm /var/lib/tomcat9/webapps/ROOT/ -rf
cp /ctsms/build/ctsms/web/target/ctsms-$VERSION.war /var/lib/tomcat9/webapps/ROOT.war

###setup cron
chmod +rwx /ctsms/install/install_cron.sh
/ctsms/install/install_cron.sh

###ready
systemctl start tomcat9
systemctl start apache2
#systemctl start cron
echo "Phoenix CTMS $VERSION [$COMMIT] update finished."