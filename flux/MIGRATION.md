# FluxCD Migration Guide

This guide covers migrating from ArgoCD to FluxCD for this homelab.

## Overview

This branch (`feat/flux-migration`) adds complete FluxCD support alongside the existing ArgoCD setup. The migration preserves your existing `k8s/` application manifests and adds Flux configuration.

### What Changed

**Added:**
- `flux/` directory with Flux bootstrap and configuration
- `flux.yaml` file in each `k8s/*/` app directory (Flux Kustomization)
- `.sops.yaml` for SOPS secret encryption configuration
- `flux/SOPS.md` comprehensive SOPS documentation

**Removed:**
- `secrets/` directory (replaced with SOPS)
- ArgoCD will be removed after successful Flux migration

**Unchanged:**
- All `k8s/` application manifests (deployments, services, ingresses, etc.)
- Kustomize structure

## Prerequisites

### 1. Install Required Tools

```bash
# Flux CLI
brew install fluxcd/tap/flux

# SOPS for secret management
brew install sops

# age for encryption
brew install age

# K9s for cluster management (recommended)
brew install derailed/k9s/k9s
```

### 2. Verify Cluster Access

```bash
kubectl cluster-info
kubectl get nodes
```

## Migration Steps

### Phase 1: Bootstrap Flux

#### 1. Generate Flux Components

The `flux/flux-system/gotk-components.yaml` file needs to be generated:

```bash
# From the repo root
flux install --export > flux/flux-system/gotk-components.yaml

# Commit the generated file
git add flux/flux-system/gotk-components.yaml
git commit -m "feat: add flux system components"
```

#### 2. Install Flux

```bash
# Apply Flux system
kubectl apply -k flux/flux-system/

# Wait for Flux controllers to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/source-controller \
  deployment/kustomize-controller \
  deployment/helm-controller \
  deployment/notification-controller \
  -n flux-system

# Verify Flux is running
flux check
```

### Phase 2: Configure SOPS

#### 1. Generate Age Key

```bash
# Generate encryption key
age-keygen -o age.agekey

# Output will show:
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#
# Save the PUBLIC KEY for next step
```

**IMPORTANT**: Store `age.agekey` securely and never commit it to Git!

#### 2. Update SOPS Configuration

Edit `.sops.yaml` and replace the placeholder with your PUBLIC key:

```yaml
creation_rules:
  - path_regex: k8s/.*/secrets/.*\.yaml$
    encrypted_regex: ^(data|stringData)$
    age: >-
      age1YOUR_ACTUAL_PUBLIC_KEY_HERE  # Replace this!
```

#### 3. Create Kubernetes Secret with Private Key

```bash
# Create secret in flux-system namespace
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin

# Verify secret exists
kubectl get secret sops-age -n flux-system
```

### Phase 3: Deploy GitRepository Source

```bash
# Apply GitRepository (points to this repo)
kubectl apply -f flux/sources/homelab-repo.yaml

# Verify it's working
flux get sources git

# Should show:
# NAME     REVISION        READY   MESSAGE
# homelab  main@sha1:...   True    stored artifact for revision 'main@sha1:...'
```

### Phase 4: Deploy Infrastructure

```bash
# Apply infrastructure Kustomization
kubectl apply -f flux/infrastructure.yaml

# Watch progress
flux get kustomizations -w

# Check logs if issues occur
flux logs --kind=Kustomization --name=infrastructure --follow
```

This will deploy:
- Cert Manager
- MetalLB
- Traefik
- Cloudflare Tunnel
- Longhorn (via Helm)
- Shared Storage
- Intel GPU plugin
- Pi-hole
- Authelia

#### 5. Verify Infrastructure

```bash
# Check all Kustomizations
flux get kustomizations

# Check Helm releases
flux get helmreleases

# Check pods across all namespaces
kubectl get pods -A

# Or use K9s for visual inspection
k9s
```

### Phase 5: Deploy Media Stack

```bash
# Apply media-stack Kustomization
kubectl apply -f flux/media-stack.yaml

# Watch deployment
flux logs --kind=Kustomization --name=media-stack --follow
```

This deploys all media automation, download clients, Jellyfin, etc.

### Phase 6: Deploy Monitoring

```bash
# Apply monitoring Kustomization
kubectl apply -f flux/monitoring.yaml

# Watch deployment
flux logs --kind=Kustomization --name=monitoring --follow
```

### Phase 7: Migrate Secrets to SOPS

See `flux/SOPS.md` for detailed instructions. Summary:

```bash
# For each sealed secret:
# 1. Extract from cluster
kubectl get secret my-secret -n namespace -o yaml > temp.yaml

# 2. Clean up cluster-specific fields (uid, resourceVersion, etc.)

# 3. Encrypt with SOPS
sops --encrypt --in-place temp.yaml

# 4. Move to app secrets directory
mv temp.yaml k8s/namespace/secrets/my-secret.yaml

# 5. Update app's kustomization.yaml to include secrets/

# 6. Test locally
sops --decrypt k8s/namespace/secrets/my-secret.yaml | kubectl apply --dry-run=client -f -

# 7. Commit
git add k8s/namespace/secrets/
git commit -m "feat: migrate namespace secrets to SOPS"
git push

# 8. Flux will automatically apply the encrypted secret
```

### Phase 8: Remove ArgoCD (After Verification)

**ONLY after all apps are working with Flux:**

```bash
# Delete ArgoCD applications
kubectl delete -f apps/app-of-apps.yaml

# Delete ArgoCD installation
kubectl delete -k bootstrap/

# Remove ArgoCD namespace
kubectl delete namespace argocd

# Clean up local files (in a new commit)
git rm -r apps/ bootstrap/
git commit -m "feat: remove argocd after flux migration"
```

## Verification Checklist

After migration, verify:

- [ ] All Flux Kustomizations are healthy: `flux get kustomizations`
- [ ] All HelmReleases are deployed: `flux get helmreleases`
- [ ] All pods are running: `kubectl get pods -A`
- [ ] All secrets are working (apps that need them are running)
- [ ] Ingresses are accessible
- [ ] Longhorn storage is working
- [ ] Monitoring stack is collecting metrics
- [ ] Media automation services are functional

## Troubleshooting

### Kustomization Failing

```bash
# Check status
flux get kustomizations

# View detailed logs
flux logs --kind=Kustomization --name=<name> --follow

# Describe the resource
kubectl describe kustomization <name> -n flux-system
```

### HelmRelease Failing

```bash
# Check Helm releases
flux get helmreleases

# View logs
flux logs --kind=HelmRelease --name=longhorn --follow

# Check Helm status directly
helm list -A
```

### Secret Decryption Issues

```bash
# Verify sops-age secret exists
kubectl get secret sops-age -n flux-system

# Check Kustomization has decryption config
kubectl get kustomization <app-name> -n flux-system -o yaml

# Look for:
# spec:
#   decryption:
#     provider: sops
#     secretRef:
#       name: sops-age

# Test local decryption
sops --decrypt k8s/app/secrets/secret.yaml

# Restart the Kustomization
flux suspend kustomization <app-name>
flux resume kustomization <app-name>
```

### App Not Deploying

```bash
# Check app's Flux Kustomization
kubectl get kustomization <app-name> -n flux-system -o yaml

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check app logs
kubectl logs -n <namespace> deployment/<app-name>

# Use K9s for easier debugging
k9s -n <namespace>
```

## Rollback Plan

If issues occur, you can rollback to ArgoCD:

```bash
# 1. Suspend all Flux Kustomizations
flux suspend kustomization --all

# 2. Re-apply ArgoCD bootstrap
kubectl apply -k bootstrap/

# 3. Wait for ArgoCD
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 4. Re-apply applications
kubectl apply -f apps/app-of-apps.yaml

# 5. Delete Flux (optional)
flux uninstall
```

## Operational Changes

### With ArgoCD (Before)
- UI at http://argocd.home.coredev.uk
- Click applications to see status
- View logs in UI
- Sync via UI or CLI

### With Flux (After)
- No UI by default (can add Weave GitOps if desired)
- Use CLI: `flux get kustomizations`
- Use K9s for visual cluster management
- GitOps is automatic (no manual sync needed)

### Daily Workflow

```bash
# Check status
flux get kustomizations
flux get helmreleases

# View logs
flux logs --kind=Kustomization --name=infrastructure

# Force reconciliation (like ArgoCD sync)
flux reconcile kustomization infrastructure --with-source

# Check sources
flux get sources git
```

## Benefits After Migration

1. **Simpler architecture**: No separate ArgoCD control plane
2. **True GitOps**: Flux manages itself via Git
3. **Better secrets**: SOPS with age encryption for better security and DX
4. **Kubernetes-native**: Everything is standard CRDs
5. **CLI-friendly**: Perfect for terminal workflow
6. **Lighter weight**: Fewer components running

## Additional Resources

- [Flux Documentation](https://fluxcd.io/flux/)
- [SOPS Documentation](flux/SOPS.md)
- [Migration FAQ](https://fluxcd.io/flux/migration/)
- [K9s Documentation](https://k9scli.io/)

## Support

If you encounter issues:
1. Check Flux logs: `flux logs`
2. Verify CRDs: `flux check`
3. Review this guide's troubleshooting section
4. Check Flux GitHub issues: https://github.com/fluxcd/flux2/issues
