#!/bin/bash

# Load secrets from environment file
if [ ! -f "secrets.env" ]; then
    echo "Error: secrets.env not found. Copy from secrets.env.example and fill in values."
    exit 1
fi

source secrets.env

# Generate Pihole secrets
kubectl create secret generic pihole-secrets \
    --from-literal=WEBPASSWORD="$PIHOLE_WEBPASSWORD" \
    --dry-run=client -o yaml > pihole-secrets.yaml

# Generate Frigate secrets  
kubectl create secret generic frigate-secrets \
    --from-literal=MQTT_PASSWORD="$FRIGATE_MQTT_PASSWORD" \
    --dry-run=client -o yaml > frigate-secrets.yaml

# Generate VPN secrets
kubectl create secret generic vpn-secrets \
    --from-literal=VPN_USERNAME="$VPN_USERNAME" \
    --from-literal=VPN_PASSWORD="$VPN_PASSWORD" \
    --dry-run=client -o yaml > vpn-secrets.yaml

# Generate Cloudflare secrets
kubectl create secret generic cloudflare-api-token-secret \
    --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
    --dry-run=client -o yaml > cloudflare-secrets.yaml

echo "Generated secret files. Apply them with:"
echo "kubectl apply -f pihole-secrets.yaml -n dns"
echo "kubectl apply -f frigate-secrets.yaml -n security" 
echo "kubectl apply -f vpn-secrets.yaml -n downloads"
echo "kubectl apply -f cloudflare-secrets.yaml -n cert-manager"