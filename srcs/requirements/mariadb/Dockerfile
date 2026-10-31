ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}


RUN \
	apk add --no-cache \
		mariadb \
		mariadb-client && \
	mkdir -p /run/mysqld /var/lib/mysql && \
	chown -R mysql:mysql /run/mysqld /var/lib/mysql

COPY config/ /etc/
COPY main.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/main.sh

EXPOSE 3306
ENTRYPOINT ["main.sh"]
