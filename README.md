# nextcloud-automation

The goal of this project is to automate the deployment of a stable nextcloud instance. This includes installation of:

- the nextcloud instance
- an HTTP proxy (nginx, ssl with letsencrypt)
- PostgreSQL
- Redis
- Collabora online to edit files online (a LibreOffice editor interface)
- Backup of the DB (postgresql)
- Backup of nextcloud data

## Prerequisites

- Having a debian-based server (you need an apt package manager)
- 2 DNS entries pointing to your server: one for NextCloud and another for Collabora (ex: nextcloud.yourdomain.tld & collabora.yourdomain.tld)
- Having a little experience with linux management (eg: how to create ssh key files, managing sshd access, sudoers)
- Knowing a bit on `ansible` and `docker` are a big plus

## Collabora

You can enable Collabora online to edit ODT documents collaboratively. For this, make sure the variable `enable_collabora` is set to `true` in `ansible/playbooks/nextcloud/vars.yml`. You'll also need to setup the variables right bellow it (`collabora_nextcloud_domain`, `collabora_admin_username`, `collabora_domain` + `collabora_admin_password` in `secrets.yml`)

Also you'll need to activate the **Collabora online** app in the Nextcloud's admin. Then you'll have to provide a URL to the collabora Online

## Where will my data be stored?

All the application and backup data will be stored in `/var/disk1/` if you wish to setup a disk

## How to setup backups?

A cron job is creating backups in `/var/disk1/backups`, you can mount a dedicated disk on this directory if you wish.

This cron job is also uploading the backup to swift. If you don't want to use swift, please make sure the variable `enable_swift_backups` is set to `false` in `ansible/playbooks/nextcloud/vars.yml`

## How to restore from backups?

A script named `/usr/local/bin/restore-backup-nextcloud.sh` is present ont the machine. It works as this:

```bash
restore-backup-nextcloud.sh nextcloud-backup_YYYYMMDD # replace YYYYMMDD my the actual date of the backup
```

If the backup provided is not present on the disk (in `/var/disk1/backups`) it will try to fetch it from swift (if enabled).

## How to launch the deployment?

First you need a server. Then get its IP address and change the `ansible/inventory/hosts.ini` by setting this IP addres, eg:

```ini
[my-nextcloud]
192.0.2.7 # change this line
```

Adapt the `ansible/nextcloud/vars.yml` to your needs. **IMPORTANT:** change the domain names!

Then you need to change the file `ansible/nextcloud/secrets.yml` to set you own secrets. You can choose to use `ansible-vault` (https://docs.ansible.com/ansible/latest/user_guide/vault.html) but it's not mandatory, you can also just put unencrypted variables in `secrets.yml`

You can see in `ansible/playbooks/nextcloud/play.yml` that we're using an `ansible` user with root access through `sudo`. You can adapt this file if you choose another setup. If you choose to stay with this, then you need to create an `ansible` user on you server with sudo access like this (`/etc/sudoers`):

```
%sudo  ALL=(ALL) NOPASSWD:ALL
```

Add `ansible` to the `sudo` group :

```bash
usermod -a -G sudo ansible
```

Then you'll need to be able to connect to this server as ansible. If you look in the file `ansible/ansible.cfg` you'll see this line:

```
private_key_file = /home/ansible/.ssh/id_ed25519_ansible
```

Please adapt this so the local user launching `ansible` can connect to your server using SSH. For example, if you're launching `ansible` with the user `foo` change this line like this:

```
private_key_file = /home/foo/.ssh/id_ed25519_ansible
```

Create a new ssh key:

```bash
ssh-keygen -f /home/foo/.ssh/id_ed25519_ansible -t ed25519
```

Then copy the content of `/home/foo/.ssh/id_ed25519_ansible.pub` and paste it on your server in `/home/ansible/.ssh/authorized_keys`

With this your setup should be done! You can launch the deployment using:

```bash
cd ansible && ansible-playbook -vvv ./playbooks/nexcloud/play.yml
```

Once it is done, you'll need to launch the service manually. We could do it in ansible also, but we chose to do it manually for now.

```bash
ssh my_server
cd /srv/nextcloud
docker-compose up -d
```

Wait a bit, the installation is going on, then go to your main domain name (`ansible/playbooks/nextcloud/vars.yml::NEXTCLOUD_TRUSTED_DOMAINS`)

To follow the installation process you can launch:

```shell
/srv/nextcloud # docker-compose logs -f
```

And wait for these lines:

```
app_1                    | Nextcloud was successfully installed
app_1                    | setting trusted domains…
app_1                    | System config value trusted_domains => 1 set to string xxx.your-domain.tld
app_1                    | [...] NOTICE: fpm is running, pid 1
app_1                    | [...] NOTICE: ready to handle connections
```

## Thanks to

- Nextcloud
    - docker image https://hub.docker.com/_/nextcloud/
    - docs https://docs.nextcloud.com/server/18/admin_manual/installation/index.html
- Collabora online https://hub.docker.com/r/collabora/code
- nginx:
    - Nginx Proxy https://github.com/nginx-proxy/nginx-proxy
    - Letsencrypt Nginx proxy companion https://github.com/nginx-proxy/docker-letsencrypt-nginx-proxy-companion
- Redis https://hub.docker.com/_/redis/
- Postgresql https://hub.docker.com/_/postgres
- ansible https://docs.ansible.com/ansible/latest/


## Dev setup

```bash
python -m venv venv
. venv/bin/activate
pip install -r requirements.txt # mainly ansible

git submodule init
git submodule update
```

## TODO

- enable SMTP from env vars
- issues with caldav?
- run these the first time:
    - `/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user www-data app php occ maintenance:mode --on`
    - `/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user www-data app php occ db:add-missing-indices`
    - `/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user www-data app php occ db:convert-filecache-bigint`
    - `/usr/local/bin/docker-compose -f /srv/nextcloud/docker-compose.yml exec -T --user www-data app php occ maintenance:mode --off`
