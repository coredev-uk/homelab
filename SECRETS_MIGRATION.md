# Secrets Migration Guide

This guide covers migrating from plaintext `secrets.env` to SOPS-encrypted Kubernetes secrets.

## ✅ Secrets Created

The following unencrypted secret YAML files have been created:

1. **Pi-hole**: `k8s/pihole/secrets/pihole-password.yaml`
2. **Frigate**: `k8s/frigate/secrets/frigate-mqtt.yaml`
3. **SABnzbd VPN**: `k8s/sabnzbd/secrets/vpn-config.yaml`
4. **qBittorrent VPN**: `k8s/qbittorrent/secrets/vpn-config.yaml`
5. **Cert-Manager (Cloudflare)**: `k8s/cert-manager/secrets/cloudflare-api-token.yaml`
6. **Cloudflare Tunnel**: `k8s/cloudflare-tunnel/secrets/cloudflare-tunnel-token.yaml`
7. **Notifiarr**: `k8s/notifiarr/secrets/notifiarr-api-key.yaml`
8. **Glance**: `k8s/glance/secrets/glance-secrets.yaml`
9. **Authelia**: `k8s/authelia/secrets/authelia-secrets.yaml`

## 🔐 Encryption Steps

### Step 1: Generate Age Key (if not done already)

```bash
# Generate age encryption key
age-keygen -o ~/age.agekey

# This will output your public key like:
# Public key: age1abc123...xyz789

# IMPORTANT: Save this file securely and NEVER commit it to Git!
```

### Step 2: Update .sops.yaml

Replace the placeholder in `.sops.yaml` with your real public key:

```bash
# Get your public key
grep "public key:" ~/age.agekey

# Edit .sops.yaml and replace both occurrences of:
# age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# with your actual public key
```

### Step 3: Create Kubernetes Secret in Cluster

Flux needs the private key to decrypt secrets:

```bash
# Create the sops-age secret in flux-system namespace
cat ~/age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

### Step 4: Encrypt All Secrets

```bash
# Encrypt all secrets at once
find k8s -path "*/secrets/*.yaml" -type f ! -name "*example*" ! -name "README.md" \
  -exec sops --encrypt --in-place {} \;

# Verify encryption worked (should see "sops:" metadata)
head -20 k8s/pihole/secrets/pihole-password.yaml
```

### Step 5: Update Kustomizations

Each app needs to reference its secrets directory in `kustomization.yaml`:

#### Example: Pi-hole

Edit `k8s/pihole/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - app/
  - secrets/  # Add this line
```

#### Apps Needing Updates:

- `k8s/pihole/kustomization.yaml`
- `k8s/frigate/kustomization.yaml`
- `k8s/sabnzbd/kustomization.yaml`
- `k8s/qbittorrent/kustomization.yaml`
- `k8s/cert-manager/kustomization.yaml`
- `k8s/cloudflare-tunnel/kustomization.yaml`
- `k8s/notifiarr/kustomization.yaml`
- `k8s/glance/kustomization.yaml`
- `k8s/authelia/kustomization.yaml`

### Step 6: Update Flux Kustomizations for SOPS Decryption

Apps with encrypted secrets need SOPS decryption enabled in their `flux.yaml`:

#### Example: Pi-hole

Edit `k8s/pihole/flux.yaml` and add the `decryption` section:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: pihole
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./k8s/pihole
  sourceRef:
    kind: GitRepository
    name: homelab
  dependsOn:
    - name: traefik
  decryption:  # Add this section
    provider: sops
    secretRef:
      name: sops-age
  wait: true
  timeout: 5m
```

#### Apps Needing SOPS Decryption:

All apps with secrets need this decryption block added to their `flux.yaml`.

### Step 7: Commit and Push

```bash
# Add all encrypted secrets
git add k8s/*/secrets/
git add k8s/*/kustomization.yaml
git add k8s/*/flux.yaml
git add .sops.yaml

# Commit
git commit -m "feat: migrate secrets to SOPS encryption"

# Push to trigger Flux reconciliation
git push
```

### Step 8: Verify Deployment

```bash
# Force Flux to reconcile
flux reconcile kustomization infrastructure --with-source
flux reconcile kustomization media-stack --with-source

# Check if secrets were created
kubectl get secrets -n pihole
kubectl get secrets -n frigate
# etc...

# Check for errors
flux get kustomizations
kubectl get pods -A
```

## 🔍 Verification

To verify a secret was encrypted correctly:

```bash
# Should show encrypted values
cat k8s/pihole/secrets/pihole-password.yaml

# Should show "sops:" metadata at the bottom
tail -20 k8s/pihole/secrets/pihole-password.yaml

# To decrypt locally (for verification)
sops --decrypt k8s/pihole/secrets/pihole-password.yaml
```

## 🧹 Cleanup After Migration

Once verified working:

```bash
# Securely backup secrets.env to password manager or secure storage
# Then delete it:
rm secrets/secrets.env

# Remove old sealed-secrets directory
rm -rf secrets/sealed-secrets/

# Commit cleanup
git add secrets/
git commit -m "chore: remove old sealed-secrets and plaintext secrets"
git push
```

## 🆘 Troubleshooting

### "Error: failed to get the data key"

- Make sure `.sops.yaml` has your real public key (not placeholder)
- Make sure `sops-age` secret exists in `flux-system` namespace

### "Secret not found" errors in pods

- Verify the secret name in deployment matches the secret metadata name
- Check Flux Kustomization has `decryption` block configured
- Run `flux logs --kind=Kustomization --name=pihole` to see errors

### Need to edit an encrypted secret

```bash
# SOPS will decrypt, open in editor, then re-encrypt on save
sops k8s/pihole/secrets/pihole-password.yaml
```

## 📝 Notes

- **NEVER** commit `age.agekey` (private key) to Git
- **ALWAYS** backup your age key securely
- Encrypted secrets are safe to commit to Git
- You can still read field names in encrypted secrets (only values are encrypted)

## 📝 .gitignore Protection

The `.gitignore` is currently configured to block ALL secret YAML files:

```
**/secrets/*.yaml
!**/secrets/*example*.yaml
!**/secrets/README.md
```

**After encrypting your secrets with SOPS:**

1. Remove these three lines from `.gitignore`
2. Then commit your encrypted secrets

This ensures you can't accidentally commit unencrypted secrets to Git.

