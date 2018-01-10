#!/usr/bin/env bash
mount_num=6
rpm -ivh https://raw.githubusercontent.com/xiaomatech/graphite/master/carbon-c-relay-3.2-2.el7.centos.x86_64.rpm

mkdir -p /var/log/carbon-relay /var/run/carbon-relay
chown -R carbon-c-relay:carbon-c-relay /var/log/carbon-relay /var/run/carbon-relay


SERVER_IP=`/sbin/ifconfig  | grep 'inet'| grep -v '127.0.0.1' |head -n1 |tr -s ' '|cut -d ' ' -f3 | cut -d: -f2`

echo -ne 'ARGS="-p 2003 -B 4096 -l /var/log/carbon-relay/carbon-relay.log -P /var/run/carbon-relay/carbon-relay.pid"'>/etc/sysconfig/carbon-c-relay

header='''
cluster '''$SERVER_IP'''
\n  fnv1a_ch
'''

footer='''
\n  ;
\nmatch \x2A
\n  send to '''$SERVER_IP'''
\n  ;
'''

number_instance=$[`nproc`*$mount_num -1]
cluster_address=''
for instance in $(seq 0 $number_instance)
do
    instance_index=$(($instance % $mount_num))
    cluster_address=$cluster_address'\n\x20\x20\x20\x20'$SERVER_IP':'$((2000+$instance))
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
