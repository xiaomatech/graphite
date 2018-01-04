#!/usr/bin/env bash
yum install -y python-pip

pip install --no-binary=:all: https://github.com/graphite-project/whisper/tarball/master
pip install --no-binary=:all: https://github.com/graphite-project/carbon/tarball/master
pip install --no-binary=:all: https://github.com/graphite-project/graphite-web/tarball/master


GRAPHITE_PATH=/opt/graphite

sudo cp ${GRAPHITE_PATH}/examples/init.d/carbon-* /etc/init.d/
INIT_SCRIPTS="carbon-cache carbon-relay carbon-aggregator";
for s in $INIT_SCRIPTS; do
    /bin/chmod +x /etc/init.d/${s};

    if [ -x /sbin/chkconfig ]; then
        /sbin/chkconfig --add ${s};
    fi;
done;

CONFFILES="carbon.conf relay-rules.conf storage-schemas.conf storage-aggregation.conf graphTemplates.conf graphite.wsgi rewrite-rules.conf aggregation-rules.conf whitelist.conf"
for i in $CONFFILES; do
    if [ ! -e ${GRAPHITE_PATH}/conf/$i ]; then
        /bin/echo "No pre-existing $i - creating from example."
        /bin/cp ${GRAPHITE_PATH}/conf/$i.example ${GRAPHITE_PATH}/conf/$i;
    fi;
done;

sudo cp ${GRAPHITE_PATH}/webapp/graphite/local_settings.py.example ${GRAPHITE_PATH}/webapp/graphite/local_settings.py
sudo cp ${GRAPHITE_PATH}/conf/graphite.wsgi.example ${GRAPHITE_PATH}/conf/graphite.wsgi
sudo cp ${GRAPHITE_PATH}/examples/example-graphite-vhost.conf /etc/httpd/conf.d/graphite.conf

#set permission
sudo chown -R apache:apache ${GRAPHITE_PATH}/storage/
sudo chown -R apache:apache ${GRAPHITE_PATH}/static/
sudo chown -R apache:apache ${GRAPHITE_PATH}/webapp/


sudo service carbon-cache start
#sudo service carbon-relay start
#sudo service carbon-aggregator start

#syncdb

/opt/graphite/bin/run-graphite-devel-server.py /opt/graphite/