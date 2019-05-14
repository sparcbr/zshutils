#!/bin/bash

APIKEY='EWXTOTYQXVHXP3AOS2RCJQFT5KYHZ6NCJCDQ'
#DOMAIN=$(expr match "$CERTBOT_DOMAIN" '.*\.\(.*\..*\)')

if [ -f /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID ]; then
	RECORD_ID=$(cat /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID | cut -f5 -d' ')
	rm -f /tmp/CERTBOT_$CERTBOT_DOMAIN/RECORD_ID
fi
# Remove the challenge TXT record from the zone
while read -r id; do
	if [ -n "$id" ]; then
		curl -s -X POST "https://api.vultr.com/v1/dns/delete_record" -H "API-Key: $APIKEY" --data "domain=$CERTBOT_DOMAIN" --data "RECORDID=$id"
	fi
done <<< "$RECORD_ID"
