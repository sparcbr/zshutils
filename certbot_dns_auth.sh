#!/bin/bash
backendDir='/var/www/backend'

# Strip only the top domain to get the zone id
#DOMAIN=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')
APIKEY='EWXTOTYQXVHXP3AOS2RCJQFT5KYHZ6NCJCDQ'
# Create TXT record
NAME="_acme-challenge"
curl -s -X POST -H "API-Key: $APIKEY" https://api.vultr.com/v1/dns/create_record --data "domain=$CERTBOT_DOMAIN" --data 'type=TXT' --data "name=$NAME" --data "data=\"$CERTBOT_VALIDATION\"" --data "ttl=120" 

records=$(php $backendDir/cmdtool.php dns_find_record_by_name $CERTBOT_DOMAIN $NAME)
if [[ $? != 0 ]]; then
	echo "Error finding dns record $NAME" >> $backendDir/logs/api.txt
	return false
fi
if [ ! -d /tmp/CERTBOT_$CERTBOT_DOMAIN ];then
	mkdir -m 0700 /tmp/CERTBOT_$CERTBOT_DOMAIN
fi
rm /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID
# Save info for cleanup
while read -r line; do
	echo $line >> /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID
done <<< "$records"

# Sleep to make sure the change has time to propagate over to DNS
sleep 12

