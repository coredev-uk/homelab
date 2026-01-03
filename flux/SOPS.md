# SOPS Secret Management

This homelab uses [SOPS](https://github.com/getsops/sops) (Secrets OPerationS) with [age](https://github.com/FiloSottile/age) encryption for managing Kubernetes secrets in Git.

## Why SOPS?

**Key advantages:**
- Secrets are **human-readable** in Git (field names visible, only values encrypted)
- **Cluster-independent**: Not tied to a specific cluster's controller
- **Local decryption**: Can decrypt secrets locally for debugging
- **Easier key rotation**: Simple age key management
- **Integrated with Flux**: Automatic decryption on apply

## Prerequisites

Install required tools:

```bash
# Install SOPS
brew install sops

# Install age
brew install age

# Flux CLI (if not already installed)
brew install fluxcd/tap/flux
```

## Initial Setup

### 1. Generate Age Key Pair

```bash
# Generate a new age key pair
age-keygen -o age.agekey

# This will output something like:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# 
# The private key is saved in age.agekey
```

**IMPORTANT**: 
- Keep `age.agekey` (private key) SECURE and NEVER commit it to Git
- Add it to `.gitignore` (already done)
- Back it up securely (password manager, encrypted backup, etc.)

### 2. Update .sops.yaml

Replace the placeholder age public key in `.sops.yaml` with your actual public key:

```yaml
age: >-
  age1YOUR_ACTUAL_PUBLIC_KEY_HERE
```

### 3. Create Kubernetes Secret with Private Key

The Flux source-controller needs the private key to decrypt secrets:

```bash
# Create the secret in flux-system namespace
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

### 4. Configure Flux to Use SOPS

Flux Kustomizations that need to decrypt secrets must reference the age secret. This is configured per-Kustomization, NOT in the GitRepository:

```yaml
# Example: k8s/pihole/flux.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: pihole
  namespace: flux-system
spec:
  # ... other fields ...
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

**Note**: Only apps with encrypted secrets need the `decryption` section. Apps in this homelab with SOPS-encrypted secrets:
- pihole
- authelia
- cloudflare-tunnel
- notifiarr
- frigate
- glance

## Creating Encrypted Secrets

### Method 1: Encrypt Existing Secrets

```bash
# Create a secret normally
kubectl create secret generic my-secret \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > k8s/myapp/secrets/my-secret.yaml

# Encrypt it with SOPS (uses .sops.yaml config automatically)
sops --encrypt --in-place k8s/myapp/secrets/my-secret.yaml

# Commit to Git
git add k8s/myapp/secrets/my-secret.yaml
git commit -m "feat: add myapp secret"
git push
```

### Method 2: Create and Encrypt in One Step

```bash
# Create encrypted secret directly
sops k8s/myapp/secrets/my-secret.yaml
# This opens your editor - paste the secret YAML, save and exit
# SOPS automatically encrypts it
```

### Method 3: From Files

```bash
# Create secret from files
kubectl create secret generic tls-cert \
  --from-file=tls.crt=cert.pem \
  --from-file=tls.key=key.pem \
  --dry-run=client -o yaml | sops --encrypt /dev/stdin > k8s/myapp/secrets/tls-secret.yaml
```

## Viewing/Editing Encrypted Secrets

### View Decrypted Content

```bash
# View decrypted content (doesn't modify file)
sops --decrypt k8s/myapp/secrets/my-secret.yaml

# Decrypt and pipe to kubectl
sops --decrypt k8s/myapp/secrets/my-secret.yaml | kubectl apply -f -
```

### Edit Encrypted Secret

```bash
# Edit secret (decrypts, opens editor, re-encrypts on save)
sops k8s/myapp/secrets/my-secret.yaml
```

## Secret Organization

Organize secrets in each app's directory:

```
k8s/
  myapp/
    secrets/
      api-keys.yaml
      database-credentials.yaml
    kustomization.yaml  # References secrets/
    deployment.yaml
    flux.yaml
```

Update the app's `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - secrets/  # Kustomize will include all .yaml files
  - app/
```

## Example: Encrypted Secret

Here's what an encrypted secret looks like in Git:

```yaml
apiVersion: v1
kind: Secret
metadata:
    name: api-keys
    namespace: myapp
type: Opaque
data:
    api-key: ENC[AES256_GCM,data:rJ0X...,iv:abc...,tag:xyz...,type:str]
    secret-token: ENC[AES256_GCM,data:kL9Y...,iv:def...,tag:uvw...,type:str]
sops:
    kms: []
    gcp_kms: []
    azure_kv: []
    hc_vault: []
    age:
        - recipient: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
          enc: |
            -----BEGIN AGE ENCRYPTED FILE-----
            ...
            -----END AGE ENCRYPTED FILE-----
    lastmodified: "2025-12-31T02:54:00Z"
    mac: ENC[AES256_GCM,data:...,iv:...,tag:...,type:str]
    pgp: []
    version: 3.8.1
```

Notice:
- **Field names** are visible (api-key, secret-token)
- **Values** are encrypted (ENC[...])
- **Metadata** about encryption at the bottom

## Key Rotation

To rotate your age key:

1. Generate new key pair: `age-keygen -o age-new.agekey`
2. Update `.sops.yaml` with new public key
3. Re-encrypt all secrets:
   ```bash
   find k8s -name "*.yaml" -path "*/secrets/*" -exec sops updatekeys --yes {} \;
   ```
4. Update the Kubernetes secret:
   ```bash
   cat age-new.agekey | kubectl create secret generic sops-age \
     --namespace=flux-system \
     --from-file=age.agekey=/dev/stdin \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
5. Restart Flux controllers:
   ```bash
   flux suspend kustomization --all
   flux resume kustomization --all
   ```

## Troubleshooting

### "Failed to decrypt" error in Flux

```bash
# Check if sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization has decryption configured
kubectl get kustomization pihole -n flux-system -o yaml | grep -A3 decryption

# Restart source-controller
kubectl rollout restart deployment/source-controller -n flux-system
```

### "no age key found" error locally

```bash
# Set SOPS_AGE_KEY_FILE environment variable
export SOPS_AGE_KEY_FILE=/path/to/age.agekey

# Or use --age flag
sops --age /path/to/age.agekey --decrypt secret.yaml
```

### Secret not decrypting in cluster

```bash
# Check Flux logs
flux logs --kind=Kustomization --name=infrastructure

# Check if secret matches .sops.yaml patterns
# Ensure encrypted_regex matches your secret structure
```

## Security Best Practices

1. **Never commit** `age.agekey` (private key) to Git
2. **Back up** your private key securely (encrypted backup, password manager)
3. **Use different keys** for different environments (prod vs dev)
4. **Rotate keys** periodically (every 6-12 months)
5. **Audit access**: Only admins should have the private key
6. **Test decryption** locally before pushing to ensure secrets work

## Reference

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Documentation](https://github.com/FiloSottile/age)
- [Flux SOPS Guide](https://fluxcd.io/flux/guides/mozilla-sops/)
