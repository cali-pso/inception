ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache vsftpd

COPY conf/vsftpd.conf /etc/vsftpd/vsftpd.conf
COPY tools/main.sh /usr/local/bin/main.sh
RUN chmod +x /usr/local/bin/main.sh

EXPOSE 21 21000-21010
ENTRYPOINT ["main.sh"]