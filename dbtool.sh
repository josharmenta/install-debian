#!/bin/bash
CTSMS_PROPERTIES=${CTSMS_PROPERTIES:-/ctsms/properties}
CTSMS_JAVA=${CTSMS_JAVA:-/ctsms/java}
CATALINA_BASE=${CATALINA_BASE:-/var/lib/tomcat9}
java -DCTSMS_PROPERTIES="$CTSMS_PROPERTIES" -DCTSMS_JAVA="$CTSMS_JAVA" -Dfile.encoding=Cp1252 -Djava.awt.headless=true --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED -Xms2048m -Xmx4096m -Xss256k -XX:+UseParallelGC -XX:MaxGCPauseMillis=1500 -XX:GCTimeRatio=9 -XX:+CMSClassUnloadingEnabled -XX:ReservedCodeCacheSize=256m -classpath $CATALINA_BASE/webapps/ROOT/WEB-INF/lib/ctsms-core-1.8.1.jar:$CATALINA_BASE/webapps/ROOT/WEB-INF/lib/* org.phoenixctms.ctsms.executable.DBTool $*