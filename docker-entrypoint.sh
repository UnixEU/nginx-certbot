#!/bin/sh
set -eu

SERVER_NAME="${SERVER_NAME:-_}"
CERTBOT_CERT_NAME="${CERTBOT_CERT_NAME:-default}"
ACME_WEBROOT="${ACME_WEBROOT:-/var/www/certbot}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
HTTP_BIND="${HTTP_BIND:-0.0.0.0}"
HTTPS_BIND="${HTTPS_BIND:-0.0.0.0}"
HTTPS_REDIRECT_PORT="${HTTPS_REDIRECT_PORT:-443}"
HTTP_REDIRECT_TO_HTTPS="${HTTP_REDIRECT_TO_HTTPS:-false}"
HTTP_RESPONSE_TEXT="${HTTP_RESPONSE_TEXT:-nginx + certbot container is running}"
HTTPS_RESPONSE_TEXT="${HTTPS_RESPONSE_TEXT:-secure nginx + certbot container is running}"
SELF_SIGNED_CN="${SELF_SIGNED_CN:-localhost}"
SELF_SIGNED_DAYS="${SELF_SIGNED_DAYS:-1}"

export SERVER_NAME
export CERTBOT_CERT_NAME
export ACME_WEBROOT
export HTTP_PORT
export HTTPS_PORT
export HTTP_BIND
export HTTPS_BIND
export HTTPS_REDIRECT_PORT
export HTTP_REDIRECT_TO_HTTPS
export HTTP_RESPONSE_TEXT
export HTTPS_RESPONSE_TEXT

mkdir -p \
  /var/cache/nginx/client_temp \
  /var/cache/nginx/proxy_temp \
  /var/cache/nginx/fastcgi_temp \
  /var/cache/nginx/uwsgi_temp \
  /var/cache/nginx/scgi_temp \
  "$ACME_WEBROOT" \
  "/etc/letsencrypt/live/$CERTBOT_CERT_NAME" \
  /var/log/nginx

envsubst '${SERVER_NAME} ${CERTBOT_CERT_NAME} ${ACME_WEBROOT} ${HTTP_PORT} ${HTTPS_PORT} ${HTTP_BIND} ${HTTPS_BIND} ${HTTP_RESPONSE_TEXT} ${HTTPS_RESPONSE_TEXT}' \
  < /etc/nginx/templates/default.conf.template \
  > /etc/nginx/conf.d/default.conf

if [ "$HTTP_REDIRECT_TO_HTTPS" = "true" ]; then
  if [ "$HTTPS_REDIRECT_PORT" = "443" ]; then
    sed -i "s|#__HTTP_REDIRECT__#|return 301 https://\$host\$request_uri;|g" /etc/nginx/conf.d/default.conf
  else
    sed -i "s|#__HTTP_REDIRECT__#|return 301 https://\$host:$HTTPS_REDIRECT_PORT\$request_uri;|g" /etc/nginx/conf.d/default.conf
  fi
else
  sed -i "s|#__HTTP_REDIRECT__#|return 200 '${HTTP_RESPONSE_TEXT}\\n';|g" /etc/nginx/conf.d/default.conf
fi

if [ ! -f "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/fullchain.pem" ] || [ ! -f "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/privkey.pem" ]; then
  echo "Generating a temporary self-signed certificate for startup..."
  openssl req -x509 -nodes -newkey rsa:2048 -days "$SELF_SIGNED_DAYS" \
    -keyout "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/privkey.pem" \
    -out "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/fullchain.pem" \
    -subj "/CN=$SELF_SIGNED_CN"
fi

exec "$@"
