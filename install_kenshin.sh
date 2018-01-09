#!/usr/bin/env bash
yum install -y gcc cairo Cython python-virtualenv python-pip numpy cffi libffi-devel python-twisted-web

pip install -U setuptools

wget https://github.com/douban/Kenshin/archive/master.zip -O /tmp/Kenshin.zip
cd /opt/ && unzip /tmp/Kenshin.zip && mv Kenshin-master kenshin && cd kenshin
virtualenv venv && source venv/bin/activate
pip install -U setuptools
pip install -r requirements.txt
pip install cffi fnv1a_relay gevent
python setup.py build_ext --inplace && python setup.py install


mkdir -p /etc/kenshin /data/kenshin/{data,link,log} /var/run/kenshin

cp conf/storage-schemas.conf.example /etc/kenshin/storage-schemas.conf

SERVER_IP=`/sbin/ifconfig  | grep 'inet'| grep -v '127.0.0.1' |head -n1 |tr -s ' '|cut -d ' ' -f3 | cut -d: -f2`

rurouni_conf_base='
\n[cache]
\n# Configure rurouni-cache directories.

\nCONF_DIR        = /etc/kenshin
\nLOCAL_DATA_DIR  = /data/kenshin/data
\nLOCAL_LINK_DIR  = /data/kenshin/link
\nLOG_DIR         = /data/kenshin/log
\nPID_DIR         = /var/run/kenshin

\nLINE_RECEIVER_INTERFACE = '$SERVER_IP'
\nPICKLE_RECEIVER_INTERFACE = '$SERVER_IP'
\nCACHE_QUERY_INTERFACE = '$SERVER_IP'

\nLOG_UPDATES = True
\nMAX_CREATES_PER_MINUTE = 1000
\nNUM_ALL_INSTANCE = '''$((`nproc`))'''

\nDEFAULT_WAIT_TIME = 1
\n\n'

rurouni_conf_ext=''
for instance in $(seq 0 $((`nproc`-1)))
do
    rurouni_conf_ext=$rurouni_conf_ext'''\n\n[cache:'''${instance}]'''
\nLINE_RECEIVER_PORT = '''$((2000+$instance))'''
\nPICKLE_RECEIVER_PORT = '''$((3000+$instance))'''
\nCACHE_QUERY_PORT = '''$((4000+$instance))
done

echo -ne $rurouni_conf_base$rurouni_conf_ext> /etc/kenshin/rurouni.conf

wget https://raw.githubusercontent.com/xiaomatech/graphite/master/rurouni-cache.init -O /etc/init.d/rurouni-cache && chmod a+x /etc/init.d/rurouni-cache
chkconfig rurouni-cache on
service rurouni-cache start


wget https://github.com/douban/graphite-kenshin/archive/master.zip -O /tmp/graphite-kenshin.zip
cd /opt/ && unzip /tmp/graphite-kenshin.zip && mv graphite-kenshin-master graphite-kenshin && cd graphite-kenshin
export GraphiteKenshinVenv=/opt/kenshin/venv
make install

graphite_header="
\nsearch_index: /data/kenshin/index
\ntime_zone: 'Asia/Shanghai'
\nfinders:
\n  - kenshin_api.KenshinFinder
\nkenshin:
"
graphite_footer='
\n\x20\x20memcached:
\n\x20\x20\x20\x20expire_time: 20
\n\x20\x20\x20\x20hosts:
\n\x20\x20\x20\x20- '$SERVER_IP':11211
\nfunctions:
\n  - graphite_api.functions.SeriesFunctions
\n  - graphite_api.functions.PieFunctions
\n  - kenshin_api.functions.SeriesFunctions
'
graphite_ext=""
graphite_ext_dir=""
for instance in $(seq 0 $((`nproc`-1)))
do
    graphite_ext_dir=$graphite_ext_dir'\n\x20\x20- /data/kenshin/link/'$instance
    graphite_ext=$graphite_ext'\n\x20\x20- '$SERVER_IP':'$((4000+$instance))':'$instance
done

echo -ne $graphite_header'\n  directories:'$graphite_ext_dir'\n  carbonlink_hosts:'$graphite_ext'\n'$graphite_footer >/etc/graphite-api.yaml

yum install -y memcached
echo -ne '''PORT="11211"
USER="memcached"
MAXCONN="65535"
CACHESIZE="2048"
OPTIONS=" -l '$SERVER_IP' -t '''`nproc`'"'>/etc/sysconfig/memcached
service memcached start

echo -ne '[Unit]
Description=graphite-api socket

[Socket]
ListenStream=/run/graphite-api.sock
ListenStream='$SERVER_IP':8888

[Install]
WantedBy=sockets.target'>/etc/systemd/system/graphite-api.socket

echo 'GraphiteKenshinVenv=/opt/kenshin/venv\nGRAPHITE_API_CONFIG=/etc/kenshin/graphite-api.yaml'>/etc/sysconfig/graphite-api

echo -ne '[Unit]
Description=Graphite-API service
Requires=graphite-api.socket

[Service]
EnvironmentFile=-/etc/sysconfig/graphite-api
ExecStart=/opt/kenshin/venv/bin/gunicorn -w '`nproc` 'graphite_api.app:app -b '$SERVER_IP':8888 -k gevent --backlog 20480 --error-logfile /var/log/graphite/error.log --access-logfile /var/log/graphite/access.log
Restart=on-failure
#User=graphite
#Group=graphite
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target'>/etc/systemd/system/graphite-api.service

mkdir -p /var/log/graphite

systemctl daemon-reload
systemctl enable graphite-api
systemctl start graphite-api