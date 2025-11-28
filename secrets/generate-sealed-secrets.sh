#!/usr/bin/env bash

# Script to generate SealedSecrets from the existing secrets.env file
# This script requires kubeseal to be installed and the sealed-secrets controller to be running
#
# Usage:
#   ./generate-sealed-secrets.sh           # Generate and apply sealed secrets
#   ./generate-sealed-secrets.sh --dry-run # Generate only, don't apply

set -e

DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "Running in dry-run mode - sealed secrets will be generated but not applied"
fi

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

# Generate Pihole SealedSecret (in pihole namespace)
create_sealed_secret "pihole-secrets" "pihole" "WEBPASSWORD" "$PIHOLE_WEBPASSWORD" "pihole-sealed-secret.yaml"

# Generate Frigate SealedSecret with MQTT and RTSP credentials (in frigate namespace)
create_sealed_secret_multi "frigate-secrets" "frigate" "frigate-sealed-secret.yaml" \
  "MQTT_PASSWORD" "$FRIGATE_MQTT_PASSWORD" \
  "RTSP_USER" "$FRIGATE_RTSP_USER" \
  "RTSP_PASSWORD" "$FRIGATE_RTSP_PASSWORD"

# Generate Cloudflare SealedSecret (in cert-manager namespace)
create_sealed_secret "cloudflare-api-token-secret" "cert-manager" "api-token" "$CLOUDFLARE_API_TOKEN" "cloudflare-sealed-secret.yaml"

# Generate Notifiarr SealedSecret (in notifiarr namespace)
create_sealed_secret "notifiarr-secrets" "notifiarr" "API_KEY" "$NOTIFIARR_API_KEY" "notifiarr-sealed-secret.yaml"

# Generate Glance SealedSecret with weather location and pihole password (in glance namespace)
create_sealed_secret_multi "glance-secrets" "glance" "glance-sealed-secret.yaml" \
  "PIHOLE_WEBPASSWORD" "$PIHOLE_WEBPASSWORD" \
  "GLANCE_WEATHER_LOCATION" "$GLANCE_WEATHER_LOCATION" \
  "RADARR_API_KEY" "$RADARR_API_KEY" \
  "SONARR_API_KEY" "$SONARR_API_KEY" \
  "GITHUB_TOKEN" "$GITHUB_TOKEN"

# Generate VPN SealedSecret for qBittorrent (in qbittorrent namespace)
create_sealed_secret_multi "vpn-secrets" "qbittorrent" "qbittorrent-vpn-sealed-secret.yaml" \
  "QBIT_VPN_PRIVATE_KEY" "$QBIT_VPN_PRIVATE_KEY" \
  "PROTON_VPN_EMAIL" "$PROTON_VPN_EMAIL" \
  "PROTON_VPN_PASSWORD" "$PROTON_VPN_PASSWORD"

# Generate VPN SealedSecret for SABnzbd (in sabnzbd namespace)
create_sealed_secret_multi "vpn-secrets" "sabnzbd" "sabnzbd-vpn-sealed-secret.yaml" \
  "SAB_VPN_PRIVATE_KEY" "$SAB_VPN_PRIVATE_KEY" \
  "PROTON_VPN_EMAIL" "$PROTON_VPN_EMAIL" \
  "PROTON_VPN_PASSWORD" "$PROTON_VPN_PASSWORD"

# Generate Cloudflare Tunnel SealedSecret (in cloudflare-tunnel namespace)
create_sealed_secret "cloudflare-tunnel-token" "cloudflare-tunnel" "token" "$CLOUDFLARE_TUNNEL_TOKEN" "cloudflare-tunnel-sealed-secret.yaml"

# Generate LLDAP SealedSecret (in authelia namespace)
create_sealed_secret_multi "lldap-secret" "authelia" "lldap-sealed-secret.yaml" \
  "admin-password" "$LLDAP_ADMIN_PASSWORD" \
  "jwt-secret" "$LLDAP_JWT_SECRET"

# Generate Authelia SealedSecret (in authelia namespace)
create_sealed_secret_multi "authelia-secrets" "authelia" "authelia-sealed-secret.yaml" \
  "ldap-password" "$LLDAP_ADMIN_PASSWORD" \
  "storage-encryption-key" "$AUTHELIA_STORAGE_ENCRYPTION_KEY" \
  "jwt-secret" "$AUTHELIA_JWT_SECRET" \
  "session-secret" "$AUTHELIA_SESSION_SECRET" \
  "oidc-hmac-secret" "$AUTHELIA_OIDC_HMAC_SECRET" \
  "oidc-private-key" "$AUTHELIA_OIDC_PRIVATE_KEY" \
  "grafana-client-secret" "$AUTHELIA_GRAFANA_CLIENT_SECRET" \
  "argocd-client-secret" "$AUTHELIA_ARGOCD_CLIENT_SECRET"

# Generate Grafana OIDC SealedSecret (in grafana namespace)
create_sealed_secret "grafana-secrets" "grafana" "oidc-client-secret" "$AUTHELIA_GRAFANA_CLIENT_SECRET" "grafana-sealed-secret.yaml"

# Generate ArgoCD OIDC SealedSecret (in argocd namespace)
create_sealed_secret "argocd-secret" "argocd" "oidc.authelia.clientSecret" "$AUTHELIA_ARGOCD_CLIENT_SECRET" "argocd-sealed-secret.yaml"

echo ""
echo "All SealedSecrets generated successfully!"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
  echo "Dry-run mode: Sealed secrets generated but not applied."
  echo ""
  echo "To apply them manually, run:"
  echo "kubectl apply -f sealed-secrets/pihole-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/frigate-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/cloudflare-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/notifiarr-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/glance-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/qbittorrent-vpn-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/sabnzbd-vpn-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/cloudflare-tunnel-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/lldap-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/authelia-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/grafana-sealed-secret.yaml"
  echo "kubectl apply -f sealed-secrets/argocd-sealed-secret.yaml"
else
  echo "Applying SealedSecrets to cluster..."
  kubectl apply -f sealed-secrets/pihole-sealed-secret.yaml
  kubectl apply -f sealed-secrets/frigate-sealed-secret.yaml
  kubectl apply -f sealed-secrets/cloudflare-sealed-secret.yaml
  kubectl apply -f sealed-secrets/notifiarr-sealed-secret.yaml
  kubectl apply -f sealed-secrets/glance-sealed-secret.yaml
  kubectl apply -f sealed-secrets/qbittorrent-vpn-sealed-secret.yaml
  kubectl apply -f sealed-secrets/sabnzbd-vpn-sealed-secret.yaml
  kubectl apply -f sealed-secrets/cloudflare-tunnel-sealed-secret.yaml
  kubectl apply -f sealed-secrets/lldap-sealed-secret.yaml
  kubectl apply -f sealed-secrets/authelia-sealed-secret.yaml
  kubectl apply -f sealed-secrets/grafana-sealed-secret.yaml
  kubectl apply -f sealed-secrets/argocd-sealed-secret.yaml

  echo ""
  echo "Cleaning up old plain text secrets from old namespaces..."
  kubectl delete secret pihole-secrets -n dns --ignore-not-found
  kubectl delete secret pihole-secrets -n pihole --ignore-not-found
  kubectl delete secret frigate-secrets -n security --ignore-not-found
  kubectl delete secret frigate-secrets -n frigate --ignore-not-found
  kubectl delete secret cloudflare-api-token-secret -n cert-manager --ignore-not-found
  kubectl delete secret notifiarr-secrets -n media --ignore-not-found
  kubectl delete secret notifiarr-secrets -n notifiarr --ignore-not-found
  kubectl delete secret glance-secrets -n media --ignore-not-found
  kubectl delete secret glance-secrets -n glance --ignore-not-found
  kubectl delete secret vpn-secrets -n media --ignore-not-found
  kubectl delete secret vpn-secrets -n qbittorrent --ignore-not-found
  kubectl delete secret vpn-secrets -n sabnzbd --ignore-not-found
  kubectl delete secret cloudflare-tunnel-token -n cloudflare-tunnel --ignore-not-found

  echo ""
  echo "SealedSecrets applied and old secrets cleaned up successfully!"
fi
