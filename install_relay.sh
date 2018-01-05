#!/usr/bin/env bash

rpm -ivh https://raw.githubusercontent.com/xiaomatech/graphite/master/carbon-c-relay-3.2-2.el7.centos.x86_64.rpm

mkdir -p /var/log/carbon-relay /var/run/carbon-relay
chown -R carbon-c-relay:carbon-c-relay /var/log/carbon-relay /var/run/carbon-relay

echo -ne 'ARGS="-p 2999 -B 4096 -l /var/log/carbon-relay/carbon-relay.log -P /var/run/carbon-relay/carbon-relay.pid"'>/etc/sysconfig/carbon-c-relay

header='''
cluster local_carbon
\n  forward
'''

footer='''
\n  ;
\nmatch \x2A
\n  send to local_carbon
\n  stop
\n  ;
'''

cluster_address=''
for instance in $(seq 0 $((`nproc`-1)))
do
    cluster_address=$cluster_address'\n\x20\x20\x20\x20127.0.0.1:'$((2000+$instance))
done

echo -ne $header$cluster_address$footer>/etc/carbon-c-relay.conf

echo -ne '''
[Unit]
Description=Enhanced C implementation of Carbon relay, aggregator and rewriter
After=network.target

[Service]
User=carbon-c-relay
Group=carbon-c-relay
EnvironmentFile=-/etc/sysconfig/carbon-c-relay
ExecStart=/usr/bin/carbon-c-relay -f /etc/carbon-c-relay.conf $ARGS
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure

[Install]
WantedBy=multi-user.target
'''>/usr/lib/systemd/system/carbon-c-relay.service

systemctl daemon-reload
systemctl enable carbon-c-relay
systemctl start carbon-c-relay
