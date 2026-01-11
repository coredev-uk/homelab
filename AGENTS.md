# Agent Guide: Homelab Kubernetes Configuration

This is a **Kubernetes homelab** managed with **FluxCD GitOps**. Changes are deployed by committing to Git.

## Quick Reference

| Tool | Purpose |
|------|---------|
| `kubectl` | Kubernetes CLI (never use Docker commands) |
| `flux` | GitOps reconciliation |
| `sops` | Secret encryption/decryption |
| `kustomize` | Manifest building |
| `kubeconform` | YAML validation |

## Build/Lint/Test Commands

### Validate All Manifests (CI equivalent)
```bash
# Validate Flux system manifests
flux install --export | kubeconform -strict -ignore-missing-schemas -summary

# Build and validate a single service
kustomize build k8s/<service>/app | kubeconform -strict -ignore-missing-schemas -summary

# Validate a specific HelmRelease
kubeconform -strict -ignore-missing-schemas -summary k8s/<service>/app/helm.yaml

# Lint YAML files
yamllint -d '{extends: relaxed, rules: {line-length: {max: 120}}}' k8s/<service>/

# Validate Flux Kustomization (dry-run)
flux build kustomization <name> --path ./flux/<stack> --kustomization-file ./flux/<stack>.yaml --dry-run
```

### Single Service Validation
```bash
# Validate one service end-to-end
kustomize build k8s/radarr/app | kubeconform -strict -ignore-missing-schemas -summary
```

### Check Secret Encryption
```bash
# Verify secret is properly encrypted
grep -q "sops:" k8s/<service>/secrets/*.yaml && echo "Encrypted" || echo "NOT encrypted"

# Decrypt and view secret
sops --decrypt k8s/<service>/secrets/secret.yaml
```

### Flux Reconciliation
```bash
flux get kustomizations                              # Check all status
flux reconcile kustomization <name> --with-source    # Force sync after push
flux logs --kind=Kustomization --name=<name>         # View errors
```

## Code Style Guidelines

### Directory Structure (Required)
```
k8s/<service>/
├── namespace.yaml        # Namespace definition
├── flux.yaml             # Flux Kustomization with dependencies
├── kustomization.yaml    # References namespace.yaml and app/
└── app/
    ├── kustomization.yaml
    ├── deployment.yaml   # Main workload
    ├── ingress.yaml      # IngressRoute + Certificate
    └── ...
```

### YAML Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line length**: Max 120 characters
- **Quotes**: Use double quotes for string values containing special characters
- **Lists**: Use `- ` prefix with space, aligned with parent key

### Naming Conventions
| Resource | Convention | Example |
|----------|------------|---------|
| Namespace | lowercase, matches service | `radarr` |
| Deployment | lowercase service name | `radarr` |
| Service | matches deployment name | `radarr` |
| PVC | `<service>-config` | `radarr-config` |
| IngressRoute | `<service>-ingressroute` | `radarr-ingressroute` |
| Certificate | `<service>-tls` | `radarr-tls` |
| Labels | `app: <service>` | `app: radarr` |

### Required Metadata & Annotations

**Deployments with UI must include Glance annotations:**
```yaml
metadata:
  annotations:
    glance/name: "Radarr"
    glance/icon: "di:radarr"
    glance/url: "https://radarr.home.coredev.uk"
    glance/description: "Movie Management"
```

### Resource Specifications (Required)
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "1000m"
```

### Security Context (Standard Pattern)
```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "988"
  - name: TZ
    value: "Europe/London"
```

### Health Probes (Required for all deployments)
```yaml
startupProbe:
  httpGet:
    path: /ping
    port: 7878
  initialDelaySeconds: 15
  periodSeconds: 5
  failureThreshold: 12
livenessProbe:
  httpGet:
    path: /ping
    port: 7878
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /ping
    port: 7878
  periodSeconds: 10
```

### Storage Patterns
```yaml
# Config PVC (Longhorn)
storageClassName: longhorn
accessModes: [ReadWriteOnce]
storage: 1Gi

# Shared media (NFS)
nfs:
  server: 192.168.20.40
  path: /var/nfs/shared/Homelab
```

### Flux Dependencies
Declare dependencies in `flux.yaml`:
```yaml
dependsOn:
  - name: longhorn      # Required for PVC
  - name: intel-gpu     # Required for GPU workloads
```

## Commit Message Convention

Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` New service or feature
- `fix:` Bug fix
- `docs:` Documentation only
- `chore:` Maintenance (version bumps, cleanup)
- `refactor:` Code restructure without behavior change

Example: `feat: add huntarr service for torrent health monitoring`

## GitOps Workflow

1. Edit manifests in `k8s/<service>/`
2. Validate: `kustomize build k8s/<service>/app | kubeconform -strict -ignore-missing-schemas`
3. Commit and push to Git
4. Flux reconciles within 1 minute (or force: `flux reconcile kustomization <name> --with-source`)

**Never use `kubectl apply` directly** - Flux will revert uncommitted changes.

## Common Pitfalls

- **Gluetun proxy limitations**: Does not support GeoIP lookups; remove proxy config if service fails with "Failed to get IP address"
- **Secret encryption**: All files in `k8s/*/secrets/*.yaml` must be SOPS-encrypted
- **Resource limits**: Verify changes don't exceed node capacity before committing
- **Namespace isolation**: Each service has its own namespace; use FQDN for cross-namespace refs: `<svc>.<ns>.svc.cluster.local`

## Key Documentation

- `flux/README.md` - Flux architecture
- `flux/SOPS.md` - Secret management guide
- `.sops.yaml` - Encryption rules
