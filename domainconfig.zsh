#!/bin/zsh
include -r functions
include -r file
include -r network
include -r dns
include -r certificate

[[ -n $1 ]] && domain=$1

while ((ret != 0)); do
	if input -p 'Enter domain' -v domain; then
		if nslookup -v ip $domain; then
			if [[ $ip == 45.63.106.243 ]]; then
				techo 'DNS is set'
			else
				techo -c warn "Dns for $domain not found. Please setup dns."
				# setup dns
			fi
		else
			techo 
		fi
	fi
	ret=$?
done

if certconfig -v certdata -o name,domains,expiration find $domain; then
	if (($#certdata)); then
		chooser -H "Certificates found for domain $C[warn]$domain$C_" -f1  -v certname $certdata 'Create new certificate' || certname=
	fi
else
	techo "No certificates found for domain $C[warn]$domain$C_"
	confirm 'Create new certificate' && certname='Create'
fi

if [[ $certname == 'Create' ]]; then
	if input -v domains -p "Create certificate. Additional domains and subdomains can be entered separated by space."; then
		certconfig -v certname create $domains || {
			confirm 'Errors were found. Continue or cancel' || cancel
		}
	fi
fi
[[ -z $certname ]] && confirm 'Continue without a certificate' || cancel

choose --multi -v mxdomains --head 'Setup e-mail server. Select domains:' $domains

dovecot_ssl_cfg='/etc/dovecot/conf.d/10-ssl.conf'
for mxdomain in $mxdomains; do
	heredoc cfg <<-EOF
	local_name $domain {
	  ssl_cert = </etc/letsencrypt/live/$certname/fullchain.pem
	  ssl_key = </etc/letsencrypt/live/$certname/privkey.pem
	}
	EOF
	if tmp=$(grep "local_name $domain" -A 2); then
		if [[ $tmp =~ "/$certname/" ]]; then
			print -r "Dovecot certificate $C[warn]$certname$C_ is already set for $C[warn]$domain$C_ $OK"
			print -rn $tmp
		else
			techo 'Current used certificate is different'
			confirm 'Change'
		fi
	fi
	print -nr $cfg >> $dovecot_ssl_cfg
done

