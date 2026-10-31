#!/bin/ash
set -e

DATADIR=/var/lib/mysql
DB_PASS="$(cat /run/secrets/db_password)"
ROOT_PASS="$(cat /run/secrets/db_root_password)"

if [ ! -d "$DATADIR/mysql" ]; then
	mariadb-install-db --user=mysql \
		--datadir="$DATADIR" --skip-test-db

	mariadbd --user=mysql --bootstrap <<-EOF
		FLUSH PRIVILEGES;
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASS}';
		DROP USER IF EXISTS ''@'localhost';
		DROP USER IF EXISTS ''@'$(hostname)';
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASS}';
		GRANT ALL ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		FLUSH PRIVILEGES;
	EOF
fi

exec mariadbd --user=mysql