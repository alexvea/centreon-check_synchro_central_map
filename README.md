# check_synchro_central_map
This bash script allows you to check if broker output to MAP server is updating the resources informations

## Prerequisites ##
- MAP extensions NG or Legacy.
- have at least one map view with a host monitored.
- netstat and nc commands installed.

## How to use it ##
````
./check_synchro.sh 
````
expected result : 

1)OK case :
````
[24-05-28_15:38:01] NG CENTRAL_LAST_CHECK: 1716910405 / MAP_LAST_CHECK: 1716910405 / diff: 0 / refresh: 0 / status: OK
````
It displays the MAP server currently used (NG or LEGACY).

CENTRAL_LAST_CHECK timestamp is retrieved via mysql client to Central DB server.

MAP_LAST_CHECK timestamp is retrived via curl to MAP API.

The diff value is in second.

The refresh value can be 0 or 1. 1 meaning that the token was not correct and has been refreshed.

2)NOK case : 
````
[24-05-28_15:41:01] NG CENTRAL_LAST_CHECK: 1716910835 / MAP_LAST_CHECK: 1716910775 / diff: 60 / refresh: 0 / status: NOK /
 netstat:tcp        0      0 10.25.15.53:33994       10.25.12.10:5758        ESTABLISHED 927756/java         
 nc: Connection to 10.25.12.10 5758 port [tcp/*] succeeded!
````
Will indicate if the centreon-map-engine PID that execute java has a established connection to the Central server.

And also test the port via nc.

## Functionnalities ##

- Retrieve the configuration from GUI page (Administration  >  Extensions  >  Options > MAP) to identify which MAP type is currently used (NG or Legacy)
- Can refresh the current authentification token (NG and Legacy).
- Check with netstat and nc in case of diff superior to 0 second.
- Will automatically search for one host that is configured in a map view, for the last_check timestamp comparaison.
- Use /etc/centreon-map/ or /etc/centreon-studio configuration folder for database/api credentials.
- Can be used with crontab to get logs every minutes in a specific logs file :
  ````
  [root@avea-map-2310-el9 ~]# cat /etc/cron.d/test_map 
  * * * * * root /root/check_synchro.sh >> /var/log/centreon-map/synchro.log 2>&1
  ````
  

## Not yet functionning ## 

See [issues](https://github.com/alexvea/check_synchro_central_map/issues)
