#!/bin/bash

DOMAINS_FILE="docker/traefik/domains.txt"
CERT_FILE="docker/traefik/certs/local.crt"
KEY_FILE="docker/traefik/certs/local.key"

# Check mkcert installed
if ! command -v mkcert &> /dev/null; then
  echo "Error: mkcert is not installed. Run: brew install mkcert && mkcert -install"
  exit 1
fi

# Check domains file exists
if [ ! -f "$DOMAINS_FILE" ]; then
  echo "Error: $DOMAINS_FILE not found"
  exit 1
fi

# Read domains (skip empty lines and comments)
DOMAINS=$(grep -v '^\s*#' "$DOMAINS_FILE" | grep -v '^\s*$' | tr '\n' ' ')

if [ -z "$DOMAINS" ]; then
  echo "Error: No domains found in $DOMAINS_FILE"
  exit 1
fi

echo "Generating cert for domains:"
grep -v '^\s*#' "$DOMAINS_FILE" | grep -v '^\s*$' | sed 's/^/  - /'

# Create certs directory if not exists
mkdir -p "$(dirname "$CERT_FILE")"

# Generate cert
mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" $DOMAINS

# Restart Traefik to reload cert
if docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
  docker compose restart traefik
  echo "✓ Traefik restarted"
else
  echo "⚠ Traefik is not running, start it with: docker compose --profile infra up -d"
fi

echo "✓ Done"
