ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache php83 php83-fpm \
    php83-mysqli php83-session curl && \
        mkdir -p /var/www/adminer /run/php && \
        curl -fsSL -o /var/www/adminer/adminer.php \
https://github.com/vrana/adminer/releases/download/v6.2.0/adminer-6.2.0.php

COPY conf/www.conf /etc/php83/php-fpm.d/www.conf

EXPOSE 9000
ENTRYPOINT ["php-fpm83", "-F"]