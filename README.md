# nextcloud-automation

The goal of this project is to automate the deployment of a stable nextcloud instance. This includes installation of:

- the nextcloud instance
- an HTTP proxy (nginx, ssl with letsencrypt)
- PostgreSQL
- Redis
- Backup of the DB (postgresql)
- Backup of nextcloud data

## Prerequisites

- Having a server
- Having a little experience with linux management (eg: how to create ssh key files, managing sshd access, sudoers)
- Knowing a bit on `ansible` and `docker` are a big plus

## How to launch the deployment?

First you need a server. Then get its IP address and change the `ansible/inventory/hosts.ini` by setting this IP addres, eg:

```ini
[my-nextcloud]
192.0.2.7 # change this line
```

Then you need to change the file `ansible/nextcloud/secrets.yml` to set you own secrets. You can choose to use `ansible-vault` (https://docs.ansible.com/ansible/latest/user_guide/vault.html) but it's not mandatory, you can also just put unencrypted variables in `secrets.yml`

```yml
# Here will go an example of the secret.yml file
```

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

## How to setup backups?

TODO

## How to restore from backups?

TODO

## Thanks to

- Nextcloud
    - docker image https://hub.docker.com/_/nextcloud/
    - docs https://docs.nextcloud.com/server/18/admin_manual/installation/index.html
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
pip install -r requirements.txt
```
