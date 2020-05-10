#!/bin/bash
set -euxo pipefail

/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec --user www-data app php occ maintenance:mode --on

mkdir -p /var/backups && chmod 750 /var/backups

DATE=$(date +"%Y%m%d")
BACKUP_FOLDER=/var/backups/nextcloud-backup_${DATE}

cd /var/disk1/
rsync -Aavx nextcloud_var_www_html/ ${BACKUP_FOLDER}
tar cfz ${BACKUP_FOLDER}-html.tgz ${BACKUP_FOLDER}
rm -rf ${BACKUP_FOLDER}

/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec --user postgres db pg_dump -U nextcloud nextcloud | gzip -c > ${BACKUP_FOLDER}-postgres.gz

/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec --user www-data app php occ maintenance:mode --off

files_to_remove=$(ls -t /var/backups/nextcloud-backup_* | tail -n +{{ number_of_backups_to_keep_on_disk*2 }})

# remove old backups
[[ ! -z "$files_to_remove" ]] && rm $files_to_remove

{% if enable_swift_backups %}

export OS_AUTH_URL={{ OS_AUTH_URL }}
export OS_PROJECT_ID={{ OS_PROJECT_ID }}
export OS_PROJECT_NAME={{ OS_PROJECT_NAME }}
export OS_USER_DOMAIN_NAME={{ OS_USER_DOMAIN_NAME }}
export OS_PROJECT_DOMAIN_ID={{ OS_PROJECT_DOMAIN_ID }}
export OS_USERNAME={{ OS_USERNAME }}
export OS_PASSWORD={{ OS_PASSWORD }}
export OS_REGION_NAME={{ OS_REGION_NAME }}
export OS_INTERFACE={{ OS_INTERFACE }}
export OS_IDENTITY_API_VERSION={{ OS_IDENTITY_API_VERSION }}

swift upload {{ swift_bucket_name }} ${BACKUP_FOLDER}-postgres.gz
swift upload {{ swift_bucket_name }} -S 1073741824 ${BACKUP_FOLDER}.tgz

# cleanup old files
for file in $(swift list -l {{ swift_bucket_name }}); do
    file_date=$(echo $file | grep -oP "nextcloud\-backup_\K\d{8}")
    DATE_DIFF=$((($(date +%s)-$(date --date="${file_date}" +%s))/(60*60*24)))
    if [ "${DATE_DIFF}" -gt "{{ number_of_backups_to_keep_on_swift }}" ]; then
        swift delete {{ swift_bucket_name }} $file
    fi
done

{% endif %}
