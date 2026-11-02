ARG ALPINE_VERSION=3.23
FROM alpine:${ALPINE_VERSION}

RUN apk add --no-cache \
    python3 py3-flask py3-requests py3-gunicorn && \
    mkdir -p /run/api_script/

COPY app /run/api_script/app

WORKDIR /run/api_script

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "4", "--timeout", "180", "--access-logfile", "-", "--error-logfile", "-", "app.app:app"]