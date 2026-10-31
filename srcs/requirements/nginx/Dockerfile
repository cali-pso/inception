ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache nginx openssl && \
    mkdir -p /run/nginx /etc/nginx/ssl

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY tools/main.sh /usr/local/bin/main.sh
RUN chmod +x /usr/local/bin/main.sh

EXPOSE 443
ENTRYPOINT [ "main.sh" ]