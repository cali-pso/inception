#!/bin/ash
set -e

FTP_PASS="$(cat /run/secrets/ftp_password)"

id "$FTP_USER" >/dev/null 2>&1 || \
    adduser -D -u 82 -G www-data -h /srv/ftp -s /sbin/nologin "$FTP_USER"
echo "$FTP_USER:$FTP_PASS" | chpasswd

sed -i '/^pasv_address=/d' /etc/vsftpd/vsftpd.conf
printf '\npasv_address=%s\n' "$FTP_PASV_ADDRESS" >> /etc/vsftpd/vsftpd.conf

exec vsftpd /etc/vsftpd/vsftpd.conf