# Secrets Management

This directory contains secret templates and examples. 

## Setup

1. Copy `secrets.env.example` to `secrets.env`
2. Fill in your actual values in `secrets.env` 
3. Run `./generate-secrets.sh` to create Kubernetes secrets
4. **Never commit `secrets.env` or generated secret files**

## Files

- `secrets.env.example` - Template with placeholder values (safe to commit)
- `secrets.env` - Your actual secrets (DO NOT COMMIT)
- `generate-secrets.sh` - Script to generate K8s secrets from env file
- `*.yaml` - Generated secret files (DO NOT COMMIT)