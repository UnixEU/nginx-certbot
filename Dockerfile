FROM python:3.12-slim-bookworm AS builder

ARG NGINX_REPO=https://github.com/nginx/nginx.git
ARG NGINX_REF=release-1.28.0
ARG CERTBOT_REPO=https://github.com/certbot/certbot.git
ARG CERTBOT_REF=v3.3.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gcc \
        git \
        libpcre2-dev \
        libssl-dev \
        make \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

RUN git clone --depth 1 --branch "${NGINX_REF}" "${NGINX_REPO}" nginx \
    && cd nginx \
    && ./auto/configure \
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --modules-path=/usr/lib/nginx/modules \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --with-compat \
        --with-file-aio \
        --with-http_ssl_module \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_stub_status_module \
        --with-threads \
    && make -j"$(nproc)" \
    && make install \
    && rm -rf /usr/src/nginx

RUN python -m venv /opt/certbot \
    && git clone --depth 1 --branch "${CERTBOT_REF}" "${CERTBOT_REPO}" certbot \
    && /opt/certbot/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
    && /opt/certbot/bin/pip install --no-cache-dir /usr/src/certbot/certbot \
    && rm -rf /usr/src/certbot

FROM python:3.12-slim-bookworm

ENV PATH="/opt/certbot/bin:${PATH}"

RUN mkdir -p \
        /etc/nginx/conf.d \
        /etc/nginx/templates \
        /etc/letsencrypt \
        /var/www/certbot \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gettext-base \
        libpcre2-8-0 \
        openssl \
        zlib1g \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /opt/certbot /opt/certbot

COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && mkdir -p \
        /var/cache/nginx/client_temp \
        /var/cache/nginx/proxy_temp \
        /var/cache/nginx/fastcgi_temp \
        /var/cache/nginx/uwsgi_temp \
        /var/cache/nginx/scgi_temp \
        /var/log/nginx

EXPOSE 80 443

VOLUME ["/etc/letsencrypt", "/var/www/certbot"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nginx -t || exit 1

STOPSIGNAL SIGQUIT

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
