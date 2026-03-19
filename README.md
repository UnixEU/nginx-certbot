# Nginx + Certbot Docker Template

This repository builds a single Docker image that contains:

- `nginx` built from the official [NGINX GitHub repository](https://github.com/nginx/nginx)
- `certbot` installed from the official [Certbot GitHub repository](https://github.com/certbot/certbot)

The container serves HTTP on port `80`, HTTPS on port `443`, and stores certificates and ACME challenge files on bind-mounted folders from this repository.

## Quick Start

Create a local `.env` file before first use:

```bash
cp .env.example .env
```

Then update `.env`, using [`./.env.example`](./.env.example) as the reference template.

## What To Edit

The most important variables are:

- `IMAGE_NAME`
- `IMAGE_TAG`
- `CONTAINER_NAME`
- `SERVER_NAME`
- `CERTBOT_CERT_NAME`
- `HOST_HTTP_PORT`
- `HOST_HTTPS_PORT`
- `HTTP_REDIRECT_TO_HTTPS`
- `LETSENCRYPT_DIR`
- `ACME_WEBROOT_DIR`
- `NGINX_LOG_DIR`

Example production-style values:

```env
SERVER_NAME=example.com
CERTBOT_CERT_NAME=example.com
HOST_HTTP_PORT=80
HOST_HTTPS_PORT=443
HTTP_REDIRECT_TO_HTTPS=true
SELF_SIGNED_CN=example.com
```

The default bind-mounted folders are:

- `./letsencrypt` for certificates
- `./www/certbot` for ACME webroot challenges
- `./logs/nginx` for access and error logs

## Start The Container

Build and start:

```bash
docker compose up -d --build
```

Check logs:

```bash
docker compose logs -f
```

The container will create a temporary self-signed certificate on first startup if no real certificate exists yet. This allows `nginx` to start on `443` immediately.

## Issue The First Let's Encrypt Certificate

Make sure:

- your domain points to this server
- ports `80` and `443` are reachable from the internet
- `SERVER_NAME` and `CERTBOT_CERT_NAME` in `.env` match your intended certificate

Issue the certificate with the webroot plugin:

```bash
docker compose exec nginx-certbot certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d example.com \
  --email you@example.com \
  --agree-tos \
  --no-eff-email
```

For multiple domains:

```bash
docker compose exec nginx-certbot certbot certonly \
  --webroot \
  -w /var/www/certbot \
  -d example.com \
  -d www.example.com \
  --email you@example.com \
  --agree-tos \
  --no-eff-email
```

After the certificate is issued, reload `nginx` so it picks up the real certificate:

```bash
docker compose exec nginx-certbot nginx -s reload
```

## Renew Certificates

Manual renewal:

```bash
docker compose exec nginx-certbot certbot renew
docker compose exec nginx-certbot nginx -s reload
```

Dry run test:

```bash
docker compose exec nginx-certbot certbot renew --dry-run
```

## Useful Commands

Open a shell in the container:

```bash
docker compose exec nginx-certbot sh
```

Check installed versions:

```bash
docker compose exec nginx-certbot nginx -v
docker compose exec nginx-certbot certbot --version
```

Rebuild after changing image source refs in `.env`:

```bash
docker compose up -d --build
```

Inspect the resolved Compose configuration:

```bash
docker compose config
```

## Template Layout

- [`./Dockerfile`](./Dockerfile)
- [`./docker-compose.yaml`](./docker-compose.yaml)
- [`./.env.example`](./.env.example)
- [`./nginx.conf`](./nginx.conf)
- [`./default.conf.template`](./default.conf.template)
- [`./docker-entrypoint.sh`](./docker-entrypoint.sh)

## Notes

- This template intentionally keeps both `nginx` and `certbot` in the same container because that is the goal of this repo.
- For larger production setups, many teams split reverse proxy and certificate automation into separate services, but this repo is optimized for a simple single-container deployment model.
- The image now includes a Docker health check using `nginx -t` so Compose and other runtimes can detect broken runtime configuration more quickly.
