#!/usr/bin/env bash

# Script to process the Gluetun auth config with the actual API key
# This should be run after generating the sealed secrets

set -e

if [ ! -f "secrets.env" ]; then
  echo "Error: secrets.env not found."
  exit 1
fi

# Source the secrets to get the API key
source secrets.env

if [ -z "$GLUETUN_API_KEY" ]; then
  echo "Error: GLUETUN_API_KEY not found in secrets.env"
  echo "Run ./generate-sealed-secrets.sh first to generate the API key"
  exit 1
fi

echo "Processing Gluetun auth config with API key..."

# Create processed auth config
mkdir -p processed-configs

# Replace the placeholder with the actual API key
sed "s/GLUETUN_API_KEY_PLACEHOLDER/$GLUETUN_API_KEY/g" \
  ../core/vpn/config.yaml > processed-configs/vpn-config-with-auth.yaml

echo "Generated processed-configs/vpn-config-with-auth.yaml"
echo ""
echo "Apply with:"
echo "kubectl apply -f processed-configs/vpn-config-with-auth.yaml"