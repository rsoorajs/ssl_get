# Local distribution of centrally managed SSL Certs

A script that helps distribute/update local SSL certs from a centrally
managed remote location via SCP or FTP. This allows reducing exposure
to external services by retrieving SSL (wildcard) certificates from a single
(centrally managed) ACME instance (e.g.) or a pfsense/opnsense box. Useful
for local network Split-Brain-DNS Setups or for Demilitarized Zones (DMZ).

## Requirements

```
apt-get install ftp openssl sshpass
```

Note:  
- `ftp` is only needed if not using `scp`.
- `sshpass` is only needed when using `scp` with a (password protected) keyfile

## Setup


- Console

```sh
cd /etc/nginx/
# or /etc/apache2/
mkdir ssl
apt-get install ftp # if using ftp
git clone git@github.com:Sieboldianus/ssl_get.git
cd ssl_get
cp .env.example .env
nano .env
```

Change the parameters in `.env` to your needs.

It is possible to define any after-script-hook 
in `.env` such as reload service nginx, apache, 
or docker restart. The command must be defined as 
a variable `RESTART_CMD` that will be executed via 
via `/bin/bash` in `check_cert.sh`. 

Test script:
```sh
sh check_cert.sh
```

## Cron Setup

Either place a hook in `/etc/cron.d/`:

```sh
sudo tee /etc/cron.d/ssl_cert_sync > /dev/null << 'EOF'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Variable minute per VM (e.g. 15 8 * * 0)
15 8 * * 0 root /etc/nginx/ssl_get/check_cert.sh > /dev/null
EOF

sudo chmod 0644 /etc/cron.d/ssl_cert_sync
```

or, use crontab:
```sh
sudo crontab -e
```

Add lines:
```sh
15 8 * * 0 /etc/nginx/ssl_get/check_cert.sh
```

This will verify expiration of local SSL certs once a week at 08:15
and pull new certificates from the remote location, if expiring 
within the next 14 days. Adjust this default time buffer in [check_cert.sh](check_cert.sh).

Use (e.g.) [crontab.guru](https://crontab.guru/#15_8_*_*_*) to change
frequency/ timespan. If you have multiple servers pulling certificates
and if you are using FTP, provide some variance to avoid FTP Error 421 
(Too many simultaneous connections).

## pfsense/opnsense integration

This is not related to this script in particular.

To store your wildcard certificates from the ACME script on pfsense or 
opnsense in a remote folder, go to Services > Acme Certificates and click 
on Edit SSL Certificate.

1. Scroll to the `Action List` at the bottom.
2. Add a new action:
   - Command / Action: `Shell Command`
   - Method: Run after certificate renewal (e.g., after or instead of `/etc/rc.restart_webgui`).
   - Target: `sh /conf/acme/ftp.sh`
3. SSH into pfSense and create `/conf/acme/ftp.sh`:

```sh
#!/bin/sh

# Configuration
FTP_HOST="192.168.1.1"
FTP_USER="ftpuser"
FTP_PASSWD="yourpassword"
REMOTE_DIR="certs"

# pfSense stores acme certs in /conf/acme/ (named after certificate or domain)
CERT_DIR="/conf/acme"
DOMAIN="wildcard.example.com"

cd "$CERT_DIR" || exit 1

ftp -n "$FTP_HOST" <<END_SCRIPT
quote USER $FTP_USER
quote PASS $FTP_PASSWD
binary
cd $REMOTE_DIR
prompt
mput ${DOMAIN}.fullchain ${DOMAIN}.key
quit
END_SCRIPT

exit 0
```

Add executable bit:
```bash
chmod +x /conf/acme/ftp.sh
```

<details><summary>Screenshot</summary>

![resources/pfsense.png](resources/pfsense.png)

</details>


## Debug

Inspect crontab logs:
```sh
# systemd journal (Debian 12+, Ubuntu 22.04+)
sudo journalctl -u cron -g "check_cert.sh"

# or syslog
sudo grep "check_cert.sh" /var/log/syslog
sudo find /var/log/. -name \syslog.*.gz -print0 | xargs -0 zgrep "check_cert.sh"
```

Also, check mail:
```
mail
```

<details><summary>Example</summary>

```output
Message 1:
From root@service  Sun Aug 29 08:05:02 2021
X-Original-To: root
From: root@service (Cron Daemon)
To: root@service
Subject: Cron <root@service> /etc/apache2/ssl_get/check_cert.sh
MIME-Version: 1.0
Content-Type: text/plain; charset=US-ASCII
Content-Transfer-Encoding: 8bit
X-Cron-Env: <SHELL=/bin/sh>
X-Cron-Env: <HOME=/root>
X-Cron-Env: <PATH=/usr/bin:/bin>
X-Cron-Env: <LOGNAME=root>
Date: Sun, 29 Aug 2021 08:05:02 +0200 (CEST)

Checking SSL expiration date of wildcard.local.mytld.com.fullchain..
/etc/apache2/ssl/wildcard.local.mytld.com.fullchain
Expiration date not yet reached (notAfter=Sep  9 00:16:51 2021 GMT)
```

</details>

Test all crontab entries:
```sh
crontab -l | grep -v '^#' | cut -f 6- -d ' ' | while read CMD; do eval $CMD; done
```

Check expiration of web address manually:
```sh
openssl s_client \
    -servername service.local.mytld.com \
    -connect service.local.mytld.com:443 </dev/null | openssl x509 -noout -dates
```

Check SSL cert:
```sh
openssl s_client \
    -showcerts -connect service.local.mytld.com:443 </dev/null
```

Check local SSL cert from disk:
```sh
openssl x509 -noout -text -in wildcard.local.mytld.com.fullchain
```