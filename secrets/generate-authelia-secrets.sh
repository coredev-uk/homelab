#!/usr/bin/env bash

# Helper script to generate Authelia secrets for secrets.env file
# This generates all the random values needed for Authelia configuration

set -e

echo "=================================="
echo "Authelia Secrets Generator"
echo "=================================="
echo ""
echo "Copy these values to your secrets.env file:"
echo ""

# LLDAP Admin Password
echo "# LLDAP Admin Password (create your own secure password)"
echo "LLDAP_ADMIN_PASSWORD=YOUR_SECURE_PASSWORD_HERE"
echo ""

# LLDAP JWT Secret
echo "# LLDAP JWT Secret"
echo "LLDAP_JWT_SECRET=$(openssl rand -base64 32)"
echo ""

# Authelia Storage Encryption Key
echo "# Authelia Storage Encryption Key"
echo "AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)"
echo ""

# Authelia JWT Secret for Password Reset
echo "# Authelia JWT Secret for Password Reset"
echo "AUTHELIA_JWT_SECRET=$(openssl rand -hex 32)"
echo ""

# Authelia Session Secret
echo "# Authelia Session Secret"
echo "AUTHELIA_SESSION_SECRET=$(openssl rand -hex 32)"
echo ""

# Authelia OIDC HMAC Secret
echo "# Authelia OIDC HMAC Secret"
echo "AUTHELIA_OIDC_HMAC_SECRET=$(openssl rand -hex 32)"
echo ""

# Generate RSA key pair for OIDC
echo "# Generating RSA key pair for OIDC..."
TEMP_KEY=$(mktemp)
TEMP_PUB=$(mktemp)

openssl genrsa -out "$TEMP_KEY" 4096 2>/dev/null
openssl rsa -in "$TEMP_KEY" -pubout -out "$TEMP_PUB" 2>/dev/null

echo "# Authelia OIDC Private Key (RSA 4096)"
echo "# Note: This is a multi-line value - copy everything including BEGIN/END lines"
echo "AUTHELIA_OIDC_PRIVATE_KEY=\"\$(cat <<'EOF'"
cat "$TEMP_KEY"
echo "EOF"
echo ")\""
echo ""

# Cleanup temp files
rm -f "$TEMP_KEY" "$TEMP_PUB"

# Grafana Client Secret
echo "# Grafana OIDC Client Secret"
echo "AUTHELIA_GRAFANA_CLIENT_SECRET=$(openssl rand -hex 32)"
echo ""

# ArgoCD Client Secret
echo "# ArgoCD OIDC Client Secret"
echo "AUTHELIA_ARGOCD_CLIENT_SECRET=$(openssl rand -hex 32)"
echo ""

echo "=================================="
echo "Generation Complete!"
echo "=================================="
echo ""
echo "IMPORTANT: Add these values to your secrets.env file, then run:"
echo "  ./generate-sealed-secrets.sh"
echo ""
