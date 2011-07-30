This repository contains utility scripts and system configuration files for the FSP IT infrastructure.

Producton scripts in prod.app-server/usr/local/bin:

- dbbak: Database backup cron script
- wsrelease: Script to do a website release; Should be put in /usr/local/bin,
    and run as root.
- chsite-fsp: Change references to FSP site to a new site in a db dump
- chsite-pf: Change references to Porcfest site to a new site in a db dump

Configuration files:

- Production nginx configuration in prod.app-server/etc/nginx
