#!/bin/bash
exe="/home/morb/shodan/bin/shodan"
query=''

cd /home/morb/shodan_safari


_update() {
$exe download --limit 100 shodan-latest "$query"
$exe convert shodan-latest.json.gz images
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

main
