ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache nginx && mkdir -p /run/nginx

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY www/ /usr/share/site-default/
COPY tools/main.sh /usr/local/bin/main.sh
RUN chmod +x /usr/local/bin/main.sh

EXPOSE 80
ENTRYPOINT ["main.sh"]