[root@avea-map-2310-el9 ~]# cat check_synchro.sh 
#!/usr/bin/env bash
REFRESHED=0

get_central_map_conf() {
        CENTRAL_DATABASE_CONF=/etc/centreon-map/centreon-database.properties
        database_central_ip=$(grep  -Po 'centreon_storage.connection.url=\K.*:'  $CENTRAL_DATABASE_CONF | awk -F"//" '{print substr($2,1, length($2)-1)}')
        database_username=$(grep  -Po 'centreon_storage.connection.username=\K.*'  $CENTRAL_DATABASE_CONF)
        database_password=$(grep  -Po 'centreon_storage.connection.password=\K.*'  $CENTRAL_DATABASE_CONF)
        MAP_TYPE=""
        datas=$(mysql -h ${database_central_ip} -u ${database_username} -p${database_password} -se "SELECT options.key,options.value FROM centreon.options WHERE options.key like 'map_light%' and options.key like 'map_light_server%'")
        map_ng_is_activate=$(echo "$datas" | grep map_light_server_using_ng | awk '{ print $2 }')
        if [ $map_ng_is_activate -eq 1 ]; then 
                MAP_CONF=/etc/centreon-map/map-config.properties
                MAP_DB_CONF=/etc/centreon-map/map-database.properties
                map_url=$(echo "$datas" | grep "map_light_server_address_ng" | awk '{ print $2 }')
                map_auth_path="centreon-map/api/beta/auth/sign-in"
                map_curl_auth_header="Authorization: Bearer"
                map_curl_headers=(-H "X-Client-Version: 23.10.9" -H "Content-Type: application/json")
                map_host_check_path="centreon-map/api/beta/hosts"
                MAP_TYPE=NG
        else   
                MAP_CONF=/etc/centreon-studio/studio-config.properties
                MAP_DB_CONF=/etc/centreon-studio/studio-database.properties
                map_url=$(echo "$datas" | grep 'map_light_server_address' | grep -v "_ng" | awk '{ print $2 }')
                map_auth_path="centreon-studio/api/beta/authentication"
                map_curl_auth_header="studio-session:"
                map_curl_headers=(-H "X-Client-Version: 23.10.9" -H "Content-Type: application/json")
                map_host_check_path="centreon-studio/services/rest/v2/hosts"
                MAP_TYPE=LEGACY
        fi
        map_password=$(grep  -Po '^centreon.pwd=\K.*' $MAP_CONF)
        map_username=$(grep  -Po '^centreon.user=\K.*' $MAP_CONF)
        central_broker_ip=$(grep  -Po '^broker.address=\K.*' $MAP_CONF)
        central_broker_port=$(grep  -Po '^broker.port=\K.*' $MAP_CONF)
        database_map_ip=$(grep  -Po 'centreon_map.connection.url=*\K.*:'  $MAP_DB_CONF | awk -F"//" '{print substr($2,1, length($2)-1)}')
        map_db_username=$(grep  -Po '^centreon_map.connection.username=\K.*' $MAP_DB_CONF)
        map_db_password=$(grep  -Po '^centreon_map.connection.password=\K.*' $MAP_DB_CONF)
}
get_central_mysql_host_last_check() {
        from_central_mysql_last_check=$(mysql -h ${database_central_ip} -u ${database_username} -p${database_password} -e "SELECT last_check FROM centreon_storage.hosts WHERE host_id = $host_id" | grep -v Value | grep -E -o "[0-9]+")
}

get_resource_from_map_view_db() {
        first_result=$(mysql -h ${database_map_ip} -u ${map_db_username} -p${map_db_password} -se 'select resourceName,resourceId from centreon_map.resource where type=0 limit 1;')
        hostname=$(echo "$first_result" | awk '{ print $1 }')
        host_id=$(echo "$first_result" | awk '{ print $2 }')
}
get_map_api_last_check() {
        MAP_TOKEN=$(cat /tmp/.map_token)
        result=$(curl -w "\n%{http_code}\n"  -s "${map_url}/${map_host_check_path}/${host_id}" -H "${map_curl_auth_header} ${MAP_TOKEN}" "${map_curl_headers[@]}" --insecure)
        http_code=$(echo "$result" | tail -1)
        #[ ${http_code} -ne 200 ] && refresh_token || from_map_api_last_check=$(echo "$result" | grep lastStateCheck | head -1 | grep -E -o "[0-9]+")
        [ ${http_code} -ne 200 ] && refresh_token || from_map_api_last_check=$(echo "$result" | grep -Po 'lastStateCheck":\K[0-9]+|lastStateCheck" : \K[0-9]+' | head -1)
        from_map_api_last_check=${from_map_api_last_check:0:10}
}

refresh_token() {
        REFRESHED=1
        map_token=$(curl -s -H 'Content-Type: application/json' -d '{"login": "'${map_username}'", "password":"'${map_password}'"}' ${map_url}/${map_auth_path}  | grep  -Po '"studioSession":"\K.*|"jwtToken":"\K.*' | awk '{print substr($1,1, length($1)-2)}')
        echo $map_token > /tmp/.map_token
        get_map_api_last_check
}

get_netstat_info() {
        pid_centreon_map_java=$(systemctl status centreon-map-engine | grep /usr/bin/java | grep -Po "└─\K[0-9]*")
        netstat -tulanp | grep $central_broker_port | grep "$pid_centreon_map_java/java"
}

get_nc_info() {
        output=$(nc -z $central_broker_ip $central_broker_port 2>&1)
        echo $output
}

output() {
        current_date=`date +"[%y-%m-%d_%H:%M:%S]"`
        [[ $1 == "NOK" ]] && debug_content=$(echo "/\n netstat:`get_netstat_info`\n nc: `get_nc_info`")
        printf "${current_date} ${MAP_TYPE} CENTRAL_LAST_CHECK: ${from_central_mysql_last_check} / MAP_LAST_CHECK: ${from_map_api_last_check} / diff: $(( from_central_mysql_last_check - from_map_api_last_check )) / refresh: $REFRESHED / status: $1 $debug_content\n" 
}

compare_last_check_timestamps() {
        [[ $(( from_central_mysql_last_check - from_map_api_last_check )) -eq 0 ]] && output OK || output NOK
}
get_central_map_conf
get_resource_from_map_view_db
get_central_mysql_host_last_check && get_map_api_last_check && compare_last_check_timestamps
