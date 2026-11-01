#!/bin/ash
set -e
if [ -z "$(ls -A /usr/share/site)" ]; then
    cp -r /usr/share/site-default/. /usr/share/site/
fi
chown -R 82:82 /usr/share/site
exec nginx -g "daemon off;"