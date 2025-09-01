# Secrets Management

This directory contains secret templates and examples. 

## Setup

1. Copy `secrets.env.example` to `secrets.env`
2. Fill in your actual values in `secrets.env` 
3. Run `./generate-secrets.sh` to create Kubernetes secrets
4. **Never commit `secrets.env` or generated secret files**

## VPN Configuration

For the VPN (gluetun with WireGuard):
- Get your WireGuard private key from your VPN provider (ProtonVPN, etc.)
- Use the raw private key - kubectl will automatically base64 encode it
- Specify server countries as comma-separated values (e.g., "Netherlands,Germany")

## Files

- `secrets.env.example` - Template with placeholder values (safe to commit)
- `secrets.env` - Your actual secrets (DO NOT COMMIT)
- `generate-secrets.sh` - Script to generate K8s secrets from env file
- `*.yaml` - Generated secret files (DO NOT COMMIT)