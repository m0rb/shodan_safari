#!/bin/bash
exe="/home/morb/shodan/bin/shodan"
query=''

_update() {
$exe download --limit 100 shodan-latest "$query"
$exe convert shodan-latest.json.gz images
$exe parse shodan-latest.json.gz\
 --fields 'ip_str,port,hostnames,location.city,location.country_code,asn,\
isp,timestamp,_shodan.id' --separator '_-_-' --no-color > shodan-latest.csv
}

_clean() { 
rm -rf shodan-latest-images
rm -f hosts.track
rm -f shodan-latest.json.gz
}

_backup() {
CURRENT=`date +%d-%m-%y`
mkdir -p backup/${CURRENT}
mv shodan-latest.json.gz backup/${CURRENT}/shodan-${CURRENT}.json.gz
mv hosts.track backup/${CURRENT}/
}

main() {
_backup;_clean;_update
}

cd /home/morb/shodan_safari
main
