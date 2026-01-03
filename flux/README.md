# Flux Configuration

This directory contains FluxCD GitOps configuration for the homelab.

## Structure

```
flux/
├── flux-system/               # Flux controllers and CRDs
│   ├── namespace.yaml
│   ├── gotk-components.yaml   # Generated via: flux install --export
│   └── kustomization.yaml
├── sources/                   # Git/Helm repository sources
│   └── homelab-repo.yaml     # Points to this Git repository
├── infrastructure/            # Infrastructure apps aggregation
│   └── kustomization.yaml    # References all k8s/*/flux.yaml
├── media-stack/               # Media apps aggregation
│   └── kustomization.yaml
├── monitoring/                # Monitoring apps aggregation
│   └── kustomization.yaml
├── infrastructure.yaml        # Master Kustomization for infrastructure
├── media-stack.yaml           # Master Kustomization for media
├── monitoring.yaml            # Master Kustomization for monitoring
├── MIGRATION.md               # Detailed migration guide
└── SOPS.md                    # SOPS secret management guide
```

## Quick Start

### Prerequisites

```bash
brew install fluxcd/tap/flux sops age
```

### Bootstrap

```bash
# 1. Generate Flux components
flux install --export > flux/flux-system/gotk-components.yaml

# 2. Apply Flux system
kubectl apply -k flux/flux-system/

# 3. Setup SOPS (see SOPS.md)
age-keygen -o age.agekey
# Update .sops.yaml with public key
cat age.agekey | kubectl create secret generic sops-age -n flux-system --from-file=age.agekey=/dev/stdin

# 4. Apply GitRepository source
kubectl apply -f flux/sources/homelab-repo.yaml

# 5. Deploy apps
kubectl apply -f flux/infrastructure.yaml
kubectl apply -f flux/media-stack.yaml
kubectl apply -f flux/monitoring.yaml
```

### Verify

```bash
flux check
flux get kustomizations
flux get helmreleases
flux get sources git
```

## Architecture

### App-Level Flux Configuration

Each app in `k8s/*/` has a `flux.yaml` file defining its Flux Kustomization:

```yaml
# k8s/radarr/flux.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: radarr
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./k8s/radarr
  sourceRef:
    kind: GitRepository
    name: homelab
  dependsOn:
    - name: traefik
    - name: shared-storage
```

### Dependency Chain

```
GitRepository (homelab)
    ↓
infrastructure.yaml → flux/infrastructure/ → k8s/*/flux.yaml
    ├── cert-manager
    ├── metallb
    ├── traefik (depends: cert-manager, metallb)
    ├── longhorn (HelmRelease)
    └── ...
    ↓
media-stack.yaml (depends: infrastructure)
    ├── radarr (depends: traefik, shared-storage)
    ├── sonarr (depends: traefik, shared-storage)
    ├── jellyfin (depends: intel-gpu)
    └── ...
    ↓
monitoring.yaml (depends: infrastructure)
    ├── prometheus
    ├── grafana (depends: prometheus)
    └── ...
```

## Common Operations

### Check Status

```bash
# All Kustomizations
flux get kustomizations

# Specific app
flux get kustomization radarr

# Helm releases
flux get helmreleases
```

### Force Reconciliation

```bash
# Reconcile infrastructure (like ArgoCD sync)
flux reconcile kustomization infrastructure --with-source

# Reconcile specific app
flux reconcile kustomization radarr
```

### View Logs

```bash
# All Flux logs
flux logs

# Specific Kustomization
flux logs --kind=Kustomization --name=infrastructure --follow

# Specific HelmRelease
flux logs --kind=HelmRelease --name=longhorn
```

### Suspend/Resume

```bash
# Suspend (stop reconciliation)
flux suspend kustomization media-stack

# Resume
flux resume kustomization media-stack
```

## Secret Management

Secrets are managed using **SOPS** with age encryption.

See [SOPS.md](./SOPS.md) for comprehensive documentation.

**Quick example:**

```bash
# Create secret
kubectl create secret generic api-key --from-literal=key=secret --dry-run=client -o yaml > k8s/app/secrets/api-key.yaml

# Encrypt with SOPS
sops --encrypt --in-place k8s/app/secrets/api-key.yaml

# Commit to Git
git add k8s/app/secrets/
git commit -m "feat: add api key secret"
git push

# Flux automatically decrypts and applies
```

## Migration from ArgoCD

See [MIGRATION.md](./MIGRATION.md) for detailed migration instructions.

## Troubleshooting

### Kustomization not reconciling

```bash
flux get kustomization <name>
flux logs --kind=Kustomization --name=<name>
kubectl describe kustomization <name> -n flux-system
```

### Source not updating

```bash
flux get sources git
flux reconcile source git homelab
```

### SOPS decryption failing

```bash
kubectl get secret sops-age -n flux-system
kubectl get kustomization <app-name> -n flux-system -o yaml | grep -A3 decryption
```

## Resources

- [Flux Documentation](https://fluxcd.io/flux/)
- [SOPS Guide](./SOPS.md)
- [Migration Guide](./MIGRATION.md)
- [Flux GitHub](https://github.com/fluxcd/flux2)
