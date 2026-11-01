ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache redis

COPY conf/redis.conf /etc/redis.conf

EXPOSE 6379
USER redis
ENTRYPOINT ["redis-server", "/etc/redis.conf"]