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

###install some general packages
apt-get update
#apt-get -y install open-vm-tools
#apt-get -y install net-tools
#apt-get -y install mc htop pg_activity
apt-get -y install sudo wget curl lsb-release gnupg

###sync time
apt-get -y install ntp
ntpd -q -g

###create 'ctsms' user
useradd ctsms
# -p '*' --groups sudo

###prepare /ctsms directory with default-config and master-data
mkdir /ctsms
rm /ctsms/bulk_processor/ -rf
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/dbtool.sh -O /ctsms/dbtool.sh
chown ctsms:ctsms /ctsms/dbtool.sh
chmod 755 /ctsms/dbtool.sh
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/clearcache.sh -O /ctsms/clearcache.sh
chown ctsms:ctsms /ctsms/clearcache.sh
chmod 755 /ctsms/clearcache.sh
if [ -z "$CONFIG_REPO" ] || [ -z "$TOKEN" ]; then
  wget --no-check-certificate --content-disposition https://github.com/phoenixctms/config-default/archive/$TAG.tar.gz -O /ctsms/config.tar.gz
else
  wget --no-check-certificate --header "Authorization: token $TOKEN" --content-disposition https://github.com/$CONFIG_REPO/archive/$TAG.tar.gz -O /ctsms/config.tar.gz
fi
tar -zxvf /ctsms/config.tar.gz -C /ctsms --strip-components 1
rm /ctsms/config.tar.gz -f
if [ -f /ctsms/install/environment ]; then
  source /ctsms/install/environment
fi
wget https://api.github.com/repos/phoenixctms/master-data/tarball/$TAG -O /ctsms/master-data.tar.gz
rm /ctsms/master_data -rf
mkdir /ctsms/master_data
tar -zxvf /ctsms/master-data.tar.gz -C /ctsms/master_data --strip-components 1
rm /ctsms/master-data.tar.gz -f
chown ctsms:ctsms /ctsms -R
chmod 775 /ctsms/external_files -R
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/update.sh -O /ctsms/update.sh
chmod 755 /ctsms/update.sh

###install OpenJDK 11
apt-get -y install default-jdk

###install tomcat9
apt-get -y install libservlet3.1-java tomcat9
systemctl stop tomcat9
#allow tomcat writing to /ctsms/external_files:
usermod --append --groups ctsms tomcat
#allow ctsms user to load jars from exploded .war:
usermod --append --groups tomcat,adm ctsms
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/tomcat/workers.properties -O /etc/tomcat9/workers.properties
chown root:tomcat /etc/tomcat9/workers.properties
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/tomcat/server.xml -O /etc/tomcat9/server.xml
chown root:tomcat /etc/tomcat9/server.xml
chmod 640 /etc/tomcat9/workers.properties
chmod 770 /var/log/tomcat9
chmod g+w /var/log/tomcat9/*
chmod 775 /var/lib/tomcat9/webapps
sed -r -i "s/^JAVA_OPTS.+/JAVA_OPTS=\"-server -Djava.awt.headless=true -Xms$XMS -Xmx$XMX -Xss$XSS -XX:+UseParallelGC -XX:MaxGCPauseMillis=1500 -XX:GCTimeRatio=9 -XX:+CMSClassUnloadingEnabled -XX:ReservedCodeCacheSize=$PERM\"/" /etc/default/tomcat9
echo 'CTSMS_PROPERTIES=/ctsms/properties' >>/etc/default/tomcat9
echo 'CTSMS_JAVA=/ctsms/java' >>/etc/default/tomcat9
sed -r -i "s|# Lifecycle|EnvironmentFile=/etc/default/tomcat9\\n\\n# Lifecycle|" /usr/lib/systemd/system/tomcat9.service
sed -r -i "s|# Security|# Security\\nReadWritePaths=/ctsms/external_files/|" /usr/lib/systemd/system/tomcat9.service
systemctl daemon-reload
systemctl start tomcat9

###build phoenix
apt-get -y install git maven
rm /ctsms/build/ -rf
mkdir /ctsms/build
cd /ctsms/build
git clone https://github.com/phoenixctms/ctsms
cd /ctsms/build/ctsms
if [ "$TAG" != "master" ]; then
  git checkout tags/$TAG -b $TAG
fi
VERSION=$(grep -oP '<application.version>\K[^<]+' /ctsms/build/ctsms/pom.xml)
mvn install -DskipTests
if [ ! -f /ctsms/build/ctsms/web/target/ctsms-$VERSION.war ]; then
  # maybe we have more luck with dependency download on a 2nd try:
  mvn install -DskipTests
fi
mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=create
mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=drop

###install postgres 13
apt-get -y install postgresql
sudo -u postgres psql postgres -c "CREATE USER ctsms WITH PASSWORD 'ctsms';"
sudo -u postgres psql postgres -c "CREATE DATABASE ctsms;"
sudo -u postgres psql postgres -c "GRANT ALL PRIVILEGES ON DATABASE ctsms to ctsms;"
sudo -u postgres psql postgres -c "ALTER DATABASE ctsms OWNER TO ctsms;"
sudo -u ctsms psql -U ctsms ctsms < /ctsms/build/ctsms/core/db/schema-create.sql
sudo -u ctsms psql -U ctsms ctsms < /ctsms/build/ctsms/core/db/index-create.sql
sudo -u ctsms psql -U ctsms ctsms < /ctsms/build/ctsms/core/db/schema-set-version.sql
sed -r -i "s|#*join_collapse_limit.*|join_collapse_limit = 1|" /etc/postgresql/13/main/postgresql.conf
systemctl restart postgresql

###enable ssh and database remote access
#apt-get -y install ssh
#sed -r -i "s|#*listen_addresses.*|listen_addresses = '*'|" /etc/postgresql/13/main/postgresql.conf
#echo -e "host\tall\tall\t0.0.0.0/0\tmd5\nhost\tall\tall\t::/0\tmd5" >> /etc/postgresql/13/main/pg_hba.conf
#systemctl restart postgresql

###deploy .war
chmod 755 /ctsms/build/ctsms/web/target/ctsms-$VERSION.war
rm /var/lib/tomcat9/webapps/ROOT/ -rf
cp /ctsms/build/ctsms/web/target/ctsms-$VERSION.war /var/lib/tomcat9/webapps/ROOT.war

###install memcached
apt-get -y install memcached
chmod 777 /var/run/memcached
sed -r -i 's/-p 11211/#-p 11211/' /etc/memcached.conf
sed -r -i 's/-l 127\.0\.0\.1/-s \/var\/run\/memcached\/memcached.sock -a 0666/' /etc/memcached.conf
systemctl restart memcached

###install bulk-processor
apt-get -y install \
libarchive-zip-perl \
libconfig-any-perl \
libdata-dump-perl \
libdata-dumper-concise-perl \
libdata-uuid-perl \
libdata-validate-ip-perl \
libdate-calc-perl \
libdate-manip-perl \
libdatetime-format-iso8601-perl \
libdatetime-format-strptime-perl \
libdatetime-perl \
libdatetime-timezone-perl \
libdbd-csv-perl \
libdbd-mysql-perl \
libdbd-sqlite3-perl \
tdsodbc \
libdbd-odbc-perl \
libdigest-md5-perl \
libemail-mime-attachment-stripper-perl \
libemail-mime-perl \
libgearman-client-perl \
libhtml-parser-perl \
libintl-perl \
libio-compress-perl \
libio-socket-ssl-perl \
libjson-xs-perl \
liblog-log4perl-perl \
libmail-imapclient-perl \
libmarpa-r2-perl \
libmime-base64-perl \
libmime-lite-perl \
libmime-tools-perl \
libnet-address-ip-local-perl \
libnet-smtp-ssl-perl \
libole-storage-lite-perl \
libphp-serialization-perl \
libexcel-writer-xlsx-perl \
libspreadsheet-parseexcel-perl \
libstring-mkpasswd-perl \
libtext-csv-xs-perl \
libtie-ixhash-perl \
libtime-warp-perl \
liburi-find-perl \
libuuid-perl \
libwww-perl \
libxml-dumper-perl \
libxml-libxml-perl \
libyaml-libyaml-perl \
libyaml-tiny-perl \
libtemplate-perl \
libdancer-perl \
libdbd-pg-perl \
libredis-perl \
libjson-perl \
libplack-perl \
libcache-memcached-perl \
libdancer-session-memcached-perl \
libgraphviz-perl \
gnuplot \
imagemagick \
ghostscript \
build-essential \
libtest-utf8-perl \
libmoosex-hasdefaults-perl \
cpanminus
sed -r -i 's/^\s*(<policy domain="coder" rights="none" pattern="PS" \/>)\s*$/<!--\1-->/' /etc/ImageMagick-6/policy.xml
if [ "$(lsb_release -d | grep -Ei 'debian')" ]; then
  apt-get -y install libsys-cpuaffinity-perl
else
  cpanm Sys::CpuAffinity
  cpanm threads::shared
fi
cpanm --notest Dancer::Plugin::I18N
cpanm --notest DateTime::Format::Excel
cpanm --notest Spreadsheet::Reader::Format
cpanm --notest Spreadsheet::Reader::ExcelXML
wget --no-check-certificate --content-disposition https://github.com/phoenixctms/bulk-processor/archive/$TAG.tar.gz -O /ctsms/bulk-processor.tar.gz
tar -zxvf /ctsms/bulk-processor.tar.gz -C /ctsms/bulk_processor --strip-components 1
perl /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/minify.pl --folder=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup
mkdir /ctsms/bulk_processor/output
chown ctsms:ctsms /ctsms/bulk_processor -R
chmod 755 /ctsms/bulk_processor -R
chmod 777 /ctsms/bulk_processor/output -R
rm /ctsms/bulk-processor.tar.gz -f
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/ecrfdataexport.sh -O /ctsms/ecrfdataexport.sh
chown ctsms:ctsms /ctsms/ecrfdataexport.sh
chmod 755 /ctsms/ecrfdataexport.sh
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/ecrfdataimport.sh -O /ctsms/ecrfdataimport.sh
chown ctsms:ctsms /ctsms/ecrfdataimport.sh
chmod 755 /ctsms/ecrfdataimport.sh
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/inquirydataexport.sh -O /ctsms/inquirydataexport.sh
chown ctsms:ctsms /ctsms/inquirydataexport.sh
chmod 755 /ctsms/inquirydataexport.sh

###setup apache2
chmod +rwx /ctsms/install/install_apache.sh
export TAG
/ctsms/install/install_apache.sh

###initialize database
#sudo -u ctsms /ctsms/dbtool.sh -sn
chmod +rwx /ctsms/install/init_database.sh
/ctsms/install/init_database.sh

###setup cron
chmod +rwx /ctsms/install/install_cron.sh
/ctsms/install/install_cron.sh

###setup logrotate
wget https://raw.githubusercontent.com/phoenixctms/install-debian/$TAG/logrotate/ctsms -O /etc/logrotate.d/ctsms
chown root:root /etc/logrotate.d/ctsms
chmod 644 /etc/logrotate.d/ctsms

###render workflow state diagram images from db and include them for tooltips
cd /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/Render
./render.sh
cd /ctsms/build/ctsms
mvn -f web/pom.xml -Dmaven.test.skip=true
chmod 755 /ctsms/build/ctsms/web/target/ctsms-$VERSION.war
systemctl stop tomcat9
rm /var/lib/tomcat9/webapps/ROOT/ -rf
cp /ctsms/build/ctsms/web/target/ctsms-$VERSION.war /var/lib/tomcat9/webapps/ROOT.war

###ready
systemctl start tomcat9
echo "Phoenix CTMS $VERSION installation finished."
grep 'Log in' /home/phoenix/install.log
