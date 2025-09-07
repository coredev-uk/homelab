#!/usr/bin/env bash

# Script to generate SealedSecrets from the existing secrets.env file
# This script requires kubeseal to be installed and the sealed-secrets controller to be running

set -e

if [ ! -f "secrets.env" ]; then
  echo "Error: secrets.env not found. Copy from secrets.env.example and fill in values."
  exit 1
fi

# Source the secrets
source secrets.env

# Create sealed-secrets directory if it doesn't exist
mkdir -p sealed-secrets

# Function to create and seal a secret with a single key-value pair
create_sealed_secret() {
  local name=$1
  local namespace=$2
  local key=$3
  local value=$4
  local output_file=$5

  echo "Creating SealedSecret for $name in namespace $namespace..."

  # Create temporary secret
  kubectl create secret generic "$name" \
    --from-literal="$key=$value" \
    --namespace="$namespace" \
    --dry-run=client -o yaml >/tmp/temp-secret.yaml

  # Seal the secret with appropriate scope
  kubeseal --controller-namespace=sealed-secrets \
    --format yaml \
    </tmp/temp-secret.yaml >"sealed-secrets/$output_file"

  # Clean up temporary file
  rm /tmp/temp-secret.yaml

  echo "Generated sealed-secrets/$output_file"
}

# Function to create and seal a secret with multiple key-value pairs
create_sealed_secret_multi() {
  local name=$1
  local namespace=$2
  local output_file=$3
  shift 3
  local keys_values=("$@")

  echo "Creating SealedSecret for $name in namespace $namespace..."

  # Build kubectl command with multiple key-value pairs
  local kubectl_cmd="kubectl create secret generic \"$name\" --namespace=\"$namespace\" --dry-run=client -o yaml"

  for ((i = 0; i < ${#keys_values[@]}; i += 2)); do
    local key="${keys_values[i]}"
    local value="${keys_values[i + 1]}"
    kubectl_cmd="$kubectl_cmd --from-literal=\"$key=$value\""
  done

  # Create temporary secret
  eval "$kubectl_cmd" >/tmp/temp-secret.yaml

  # Seal the secret with appropriate scope
  kubeseal --controller-namespace=sealed-secrets \
    --format yaml \
    </tmp/temp-secret.yaml >"sealed-secrets/$output_file"

  # Clean up temporary file
  rm /tmp/temp-secret.yaml

  echo "Generated sealed-secrets/$output_file"
}

# Generate Pihole SealedSecret
create_sealed_secret "pihole-secrets" "dns" "WEBPASSWORD" "$PIHOLE_WEBPASSWORD" "pihole-sealed-secret.yaml"

# Generate Frigate SealedSecret with MQTT and RTSP credentials
create_sealed_secret_multi "frigate-secrets" "security" "frigate-sealed-secret.yaml" \
  "MQTT_PASSWORD" "$FRIGATE_MQTT_PASSWORD" \
  "RTSP_USER" "$FRIGATE_RTSP_USER" \
  "RTSP_PASSWORD" "$FRIGATE_RTSP_PASSWORD"

# Generate VPN SealedSecret
create_sealed_secret "vpn-secrets" "tunnelled" "WIREGUARD_PRIVATE_KEY" "$WIREGUARD_PRIVATE_KEY" "vpn-sealed-secret.yaml"

# Generate Cloudflare SealedSecret
create_sealed_secret "cloudflare-api-token-secret" "cert-manager" "api-token" "$CLOUDFLARE_API_TOKEN" "cloudflare-sealed-secret.yaml"

# Generate Notifiarr SealedSecret
create_sealed_secret "notifiarr-secrets" "media" "API_KEY" "$NOTIFIARR_API_KEY" "notifiarr-sealed-secret.yaml"

# Generate Glance SealedSecret with weather location and pihole password
create_sealed_secret_multi "glance-secrets" "media" "glance-sealed-secret.yaml" \
  "PIHOLE_WEBPASSWORD" "$PIHOLE_WEBPASSWORD" \
  "GLANCE_WEATHER_LOCATION" "$GLANCE_WEATHER_LOCATION"

echo ""
echo "All SealedSecrets generated successfully!"
echo ""
echo "Apply them with:"
echo "kubectl apply -f sealed-secrets/pihole-sealed-secret.yaml"
echo "kubectl apply -f sealed-secrets/frigate-sealed-secret.yaml"
echo "kubectl apply -f sealed-secrets/vpn-sealed-secret.yaml"
echo "kubectl apply -f sealed-secrets/cloudflare-sealed-secret.yaml"
echo "kubectl apply -f sealed-secrets/notifiarr-sealed-secret.yaml"
echo "kubectl apply -f sealed-secrets/glance-sealed-secret.yaml"
echo ""
echo "After applying, you can remove the old plain text secrets:"
echo "kubectl delete secret pihole-secrets -n dns --ignore-not-found"
echo "kubectl delete secret frigate-secrets -n security --ignore-not-found"
echo "kubectl delete secret vpn-secrets -n tunnelled --ignore-not-found"
echo "kubectl delete secret cloudflare-api-token-secret -n cert-manager --ignore-not-found"
echo "kubectl delete secret notifiarr-secrets -n media --ignore-not-found"
echo "kubectl delete secret glance-secrets -n media --ignore-not-found"

