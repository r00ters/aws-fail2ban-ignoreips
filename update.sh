#!/usr/bin/env bash

#-----BEGIN CONFIGURATION-----
TMP_DIRECTORY="/tmp"
JAIL_CONF_FILE="/etc/fail2ban/jail.local"
IGNOREIPS_STATIC_ENTRIES_FILE="./ignoreips_static_entries"

AWS_REGION="eu-north-1"
AWS_SERVICE="CLOUDFRONT"

AWS_IP_RANGES_URL="https://ip-ranges.amazonaws.com/ip-ranges.json"

RELOAD_CMD="fail2ban-client reload --all"
#-----END CONFIGURATION-----

update_and_reload () {
    cp "${TMP_FILE}" "${JAIL_CONF_FILE}"
    ${RELOAD_CMD}
}

SELF="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
TMP_FILE="${TMP_DIRECTORY}/${SELF}.tmp"

if [ -f "${IGNOREIPS_STATIC_ENTRIES_FILE}" ]; then
    IGNOREIPS_STATIC_ENTRIES=$( cat "${IGNOREIPS_STATIC_ENTRIES_FILE}" | grep -v "^#" | tr "\n" " " )
else
    IGNOREIPS_STATIC_ENTRIES=""
fi

curl -s "${AWS_IP_RANGES_URL}" > "${TMP_DIRECTORY}/ip-ranges.json" && IGNOREIPS_DYNAMIC_ENTRIES=$( cat "${TMP_DIRECTORY}/ip-ranges.json" | jq -r '.prefixes[] | select( .service == "'${AWS_SERVICE}'" and ( .region == "GLOBAL" or .region == "'${AWS_REGION}'" )).ip_prefix' | tr "\n" " " )
IGNOREIPS_ALL_ENTRIES="${IGNOREIPS_STATIC_ENTRIES}${IGNOREIPS_DYNAMIC_ENTRIES}"

sed "s|^ignoreip.*|ignoreip = ${IGNOREIPS_ALL_ENTRIES}|g" "${JAIL_CONF_FILE}" > "${TMP_FILE}"

test $(md5sum "${JAIL_CONF_FILE}" "${TMP_FILE}" | awk '{print $1}' | uniq | wc -l) == 1 || update_and_reload
