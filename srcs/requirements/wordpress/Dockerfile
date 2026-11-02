ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
        php83 php83-fpm php83-phar php83-mysqli php83-curl php83-dom \
        php83-mbstring php83-xml php83-simplexml php83-gd php83-zip \
        php83-openssl php83-session php83-tokenizer php83-fileinfo \
        php83-iconv php83-ctype php83-exif php83-intl php83-pecl-redis \
        php83-opcache \
        mariadb-client curl && \
    ln -s /usr/bin/php83 /usr/bin/php && \
    curl -fsSL -o /usr/local/bin/wp \
        https://github.com/wp-cli/wp-cli/releases/download/v2.12.0/wp-cli-2.12.0.phar && \
    chmod +x /usr/local/bin/wp && \
    (getent group www-data || addgroup -g 82 -S www-data) && \
    (getent passwd www-data || adduser -u 82 -D -S -G www-data www-data) && \
    mkdir -p /var/www/html /run/php

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf
COPY tools/main.sh /usr/local/bin/main.sh
RUN chmod +x /usr/local/bin/main.sh
RUN echo "memory_limit = 512M" > /etc/php83/conf.d/99-memory.ini

WORKDIR /var/www/html
EXPOSE 9000
ENTRYPOINT [ "main.sh" ]