<div align="center">

# Homelab Configuration

</div>

A personal Kubernetes homelab configuration using FluxCD for GitOps deployment of a complete media automation stack, DNS services, storage management, and monitoring tools. This setup includes the popular *arr media management suite, torrent/usenet clients, and essential infrastructure services.

**Note:** This configuration is tailored for my specific environment and setup. You can fork this repository and modify the configurations to work with your own infrastructure.

## Architecture

This homelab uses FluxCD for declarative, GitOps-driven deployments organized into three logical groups:

- **Infrastructure**: Core services (storage, networking, security, certificates)
- **Media Stack**: Media server, automation tools, and download clients  
- **Monitoring**: Observability stack (Prometheus, Grafana, exporters)

Each application has a `flux.yaml` defining its Flux Kustomization, with automatic reconciliation from Git and dependency management.

## Quick Start

<details>
<summary><strong>📖 Installation Guide</strong></summary>

### Prerequisites

- **Kubernetes cluster** (Talos Linux recommended, k3s/k8s 1.25+)
- **kubectl** configured with cluster admin access
- **flux** CLI installed ([installation guide](https://fluxcd.io/flux/installation/))
- **sops** and **age** for secret management ([see SOPS guide](flux/SOPS.md))
- **Git** for cloning the repository
- **Storage**: Sufficient disk space for Longhorn distributed storage (recommended: 100GB+ per node)
- **Network**: Static IP range for MetalLB load balancer

### Setup Steps

#### 1. Clone Repository

```bash
git clone https://github.com/coredev-uk/homelab.git
cd homelab
```

#### 2. Install Required Tools

```bash
# Flux CLI
brew install fluxcd/tap/flux

# SOPS and age for secrets
brew install sops age

# K9s for cluster management (optional but recommended)
brew install derailed/k9s/k9s
```

#### 3. Bootstrap Flux

```bash
# Generate Flux components
flux install --export > flux/flux-system/gotk-components.yaml

# Apply Flux system
kubectl apply -k flux/flux-system/

# Wait for Flux controllers
kubectl wait --for=condition=available --timeout=300s \
  deployment/source-controller \
  deployment/kustomize-controller \
  deployment/helm-controller \
  deployment/notification-controller \
  -n flux-system

# Verify Flux is running
flux check
```

#### 4. Configure SOPS for Secrets

```bash
# Generate age encryption key
age-keygen -o age.agekey

# This outputs your public key - copy it!
# Public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Update .sops.yaml with your public key
# Replace the placeholder age key with your actual public key

# Create Kubernetes secret with private key
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

**IMPORTANT**: Store `age.agekey` securely and never commit it to Git! See [flux/SOPS.md](flux/SOPS.md) for detailed instructions.

#### 5. Create Secrets

Create and encrypt your secrets using SOPS. Example for Pi-hole:

```bash
# Create secret directory
mkdir -p k8s/pihole/secrets

# Create secret
kubectl create secret generic pihole-password \
  --from-literal=password=YOUR_PASSWORD \
  --namespace=pihole \
  --dry-run=client -o yaml > k8s/pihole/secrets/pihole-password.yaml

# Encrypt with SOPS
sops --encrypt --in-place k8s/pihole/secrets/pihole-password.yaml

# Update kustomization.yaml to include secrets/
```

Repeat for other required secrets:
- **Frigate**: MQTT password
- **Cloudflare**: API token for cert-manager
- **Notifiarr**: API key
- **Glance**: Weather location

See [flux/SOPS.md](flux/SOPS.md) for complete guide.

#### 6. Deploy GitRepository Source

```bash
# Apply GitRepository (points to this repo)
kubectl apply -f flux/sources/homelab-repo.yaml

# Verify
flux get sources git
```

#### 7. Deploy Applications

```bash
# Deploy infrastructure (core services)
kubectl apply -f flux/infrastructure.yaml

# Wait for infrastructure to be ready
flux get kustomizations -w

# Deploy media stack
kubectl apply -f flux/media-stack.yaml

# Deploy monitoring
kubectl apply -f flux/monitoring.yaml

# Monitor all deployments
watch kubectl get pods -A
```

#### 8. Access Services

Services are accessible via their configured ingress routes through Traefik.

Check service status:
```bash
flux get kustomizations
flux get helmreleases
kubectl get ingress -A
```

</details>

<details>
<summary><strong>📋 Services Overview</strong></summary>

### Core Infrastructure
- **FluxCD**: GitOps deployment and reconciliation
- **Sealed Secrets**: Legacy secret encryption (being migrated to SOPS)
- **Longhorn**: Distributed persistent storage with replication
- **Traefik**: Ingress controller and reverse proxy
- **MetalLB**: Load balancer for bare metal Kubernetes
- **Cert Manager**: Automatic SSL certificate management via Let's Encrypt
- **Cloudflare Tunnel**: Secure external access without port forwarding
- **Authelia**: Authentication and SSO

### DNS & Security
- **Pi-hole**: Network-wide DNS ad blocking with metrics exporter
- **Frigate**: AI-powered security camera system with Intel GPU acceleration

### Media Server
- **Jellyfin**: Media server for movies, TV shows, and music with hardware transcoding
- **Jellyseerr**: Media request management interface

### Media Automation
- **Radarr**: Automated movie collection management
- **Sonarr**: Automated TV series collection management  
- **Bazarr**: Automated subtitle management
- **Prowlarr**: Indexer management and search aggregation

### Download Clients
- **qBittorrent**: Torrent client with web UI
- **SABnzbd**: Usenet downloader with metrics exporter

### Monitoring & Observability
- **Glance**: Unified dashboard with weather, stocks, RSS feeds, and service status
- **Grafana**: Metrics visualization and alerting dashboards
- **Prometheus**: Time-series metrics collection and storage
- **Kube State Metrics**: Kubernetes cluster metrics
- **Node Exporter**: Host system metrics collection

### Utilities
- **Notifiarr**: Centralized notification system for *arr apps
- **Cleanuparr**: Automated media library cleanup and management
- **Huntarr**: Advanced torrent health monitoring
- **Homebridge**: HomeKit bridge for smart home integration

</details>

## Structure

```
├── .sops.yaml               # SOPS encryption configuration
├── flux/                    # FluxCD configuration
│   ├── flux-system/        # Flux controllers and bootstrap
│   ├── sources/            # GitRepository sources
│   ├── infrastructure/     # Infrastructure apps aggregation
│   ├── media-stack/        # Media stack apps aggregation
│   ├── monitoring/         # Monitoring apps aggregation
│   ├── infrastructure.yaml # Master infrastructure Kustomization
│   ├── media-stack.yaml    # Master media Kustomization
│   ├── monitoring.yaml     # Master monitoring Kustomization
│   ├── README.md           # Flux documentation
│   ├── MIGRATION.md        # Migration guide (from ArgoCD)
│   └── SOPS.md             # Secret management guide
└── k8s/                    # Kubernetes manifests for all services
    ├── authelia/           # Authentication
    ├── cert-manager/       # Certificate management
    ├── cloudflare-tunnel/  # Cloudflare tunnel for external access
    ├── intel-gpu/          # Intel GPU device plugin
    ├── longhorn/           # Distributed block storage (HelmRelease)
    ├── metallb/            # Load balancer
    ├── pihole/             # DNS ad blocking
    ├── sealed-secrets/     # Secret encryption controller
    ├── shared-storage/     # Shared persistent volumes
    ├── traefik/            # Ingress controller
    ├── frigate/            # Security camera system
    ├── jellyfin/           # Media server
    ├── jellyseerr/         # Media requests
    ├── radarr/             # Movie management
    ├── sonarr/             # TV series management
    ├── bazarr/             # Subtitle management
    ├── prowlarr/           # Indexer management
    ├── qbittorrent/        # Torrent client
    ├── sabnzbd/            # Usenet client
    ├── cleanuparr/         # Media cleanup
    ├── huntarr/            # Torrent management
    ├── notifiarr/          # Notifications
    ├── homebridge/         # HomeKit bridge
    ├── glance/             # Dashboard
    ├── prometheus/         # Metrics collection
    ├── grafana/            # Metrics visualization
    ├── kube-state-metrics/ # Kubernetes metrics
    └── node-exporter/      # Node metrics
```

Each app directory contains:
- `kustomization.yaml` - Kustomize configuration
- `namespace.yaml` - Kubernetes namespace
- `flux.yaml` - Flux Kustomization with dependencies
- `app/` - Application manifests (deployments, services, ingresses)
- `secrets/` - SOPS-encrypted secrets (if needed)

## GitOps Workflow

### Making Changes

```bash
# 1. Edit manifests
nvim k8s/radarr/app/deployment.yaml

# 2. Commit and push
git add k8s/radarr/
git commit -m "feat: update radarr resources"
git push

# 3. Flux automatically reconciles (within 1 minute)
# Or force immediate reconciliation:
flux reconcile kustomization media-stack --with-source
```

### Monitoring

```bash
# Check all Kustomizations
flux get kustomizations

# Check Helm releases
flux get helmreleases

# View logs
flux logs --kind=Kustomization --name=infrastructure --follow

# Use K9s for visual cluster management
k9s
```

### Managing Secrets

```bash
# Create new secret
kubectl create secret generic api-key \
  --from-literal=key=mysecret \
  --namespace=myapp \
  --dry-run=client -o yaml > k8s/myapp/secrets/api-key.yaml

# Encrypt with SOPS
sops --encrypt --in-place k8s/myapp/secrets/api-key.yaml

# Edit existing encrypted secret
sops k8s/myapp/secrets/api-key.yaml

# View decrypted content (without modifying)
sops --decrypt k8s/myapp/secrets/api-key.yaml
```

See [flux/SOPS.md](flux/SOPS.md) for comprehensive secret management guide.

## Documentation

- [Flux Architecture & Operations](flux/README.md)
- [SOPS Secret Management](flux/SOPS.md)
- [Migration from ArgoCD](flux/MIGRATION.md)

## Talos Linux Compatibility

This configuration is designed to work seamlessly with Talos Linux:

- **Immutable OS**: All configuration via Kubernetes API
- **No SSH**: Use kubectl and talosctl for cluster management
- **Persistent storage**: Configured for Longhorn + future NAS integration
- **GitOps-native**: Perfect fit for Talos philosophy

For Talos-specific configuration, see your Talos controlplane/worker configs.

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Feedback & Suggestions

If you have any recommendations or suggestions for improving this homelab configuration, please feel free to contact me at [core@coredev.uk](mailto:core@coredev.uk).

---

*This project was developed with assistance from AI to help with configuration management, documentation, and infrastructure optimization.*
