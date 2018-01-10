# 用途
```
1, 存储 jvm metrics https://github.com/dropwizard/metrics
2, 存储python的metric pyformance https://github.com/omergertel/pyformance
3, 存储spark的task,driver,executor,worker,shuffe的metric信息
4, 大数据的组件metric推荐使用ambari metric存储 具体参考 https://github.com/xiaomatech/bigdata
5, 业务的metric存储除了graphite 还可以通过opentsdb存储 存储可无限但聚合功能弱
```
# 整体架构

<img src="/img/graphite-cluster.png" width="800"/>


# 参考资料
- https://github.com/douban/Kenshin/wiki/design
- https://github.com/douban/graphite-kenshin
- https://github.com/grobian/carbon-c-relay
- https://graphite-api.readthedocs.io/en/latest
- https://github.com/jjneely/buckytools
- http://graphite.readthedocs.io/en/latest


# install
 ```
    #carbon-replay
    wget https://raw.githubusercontent.com/xiaomatech/graphite/master/install_relay.sh
    bash install_relay.sh
    
    #kenshin/rurouni-cache/graphite-api
    wget https://raw.githubusercontent.com/xiaomatech/graphite/master/install_kenshin.sh
    bash install_kenshin.sh
```