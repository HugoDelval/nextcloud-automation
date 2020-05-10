#!/bin/bash
if (( $# != 1 )); then
    echo "Usage:"
    echo "    restore-backup-nextcloud.sh name_of_backup"
    echo
    echo "    eg: if you want to restore the backup of the 31st of December, 2020:"
    echo "        restore-backup-nextcloud.sh nextcloud-backup_20201231"
    exit 1
fi

set -euxo pipefail

BACKUP_TO_RESTORE="$1"

/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml stop app

cleanup() {
    rv=$?
    /usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml start app
    rm -rf /var/disk1/backups/nextcloud-files
    exit $rv
}

trap "cleanup" INT TERM EXIT

db_file="${BACKUP_TO_RESTORE}-postgres.gz"
files="${BACKUP_TO_RESTORE}-html.tgz"

cd /var/disk1/backups

{% if enable_swift_backups %}

if [[ ! -f "$db_file" && ! -f "$files" ]]; then
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

    /usr/local/bin/swift download {{ swift_bucket_name }} $db_file
    /usr/local/bin/swift download {{ swift_bucket_name }} $files
fi

{% endif %}

[[ ! -f "$db_file" || ! -f "$files" ]] && echo "File '$db_file' or '$files' is absent on disk, aborting." && exit 1

mkdir nextcloud-files
tar xvzf "$files" -C ./nextcloud-files # --strip-components=1

find /var/disk1/nextcloud_var_www_html/ -depth -type d -empty -delete
rsync --delete-after -Aax ./nextcloud-files /var/disk1/nextcloud_var_www_html/

/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user postgres db dropdb -U {{ POSTGRES_USER }} {{ POSTGRES_DB }}
/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user postgres db createdb -U {{ POSTGRES_USER }} -O {{ POSTGRES_USER }} {{ POSTGRES_DB }}
gunzip -c "$db_file" | /usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user postgres db psql -U {{ POSTGRES_USER }} {{ POSTGRES_DB }}
