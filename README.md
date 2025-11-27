<div align="center">

# Homelab Configuration

</div>

A personal Kubernetes homelab configuration using ArgoCD for GitOps deployment of a complete media automation stack, DNS services, storage management, and monitoring tools. This setup includes the popular *arr media management suite, torrent/usenet clients, and essential infrastructure services.

**Note:** This configuration is tailored for my specific environment and setup. You can fork this repository and modify the configurations to work with your own infrastructure.

## Architecture

This homelab uses ArgoCD's **App of Apps** pattern to organize applications into logical groups:

- **Infrastructure**: Core services (storage, networking, security, certificates)
- **Media Stack**: Media server, automation tools, and download clients
- **Monitoring**: Observability stack (Prometheus, Grafana, exporters)

Each application is deployed as a separate ArgoCD Application resource, allowing for independent management, updates, and rollbacks while maintaining a GitOps workflow.

## Quick Start

<details>
<summary><strong>📖 Installation Guide</strong></summary>

### Prerequisites

- **Kubernetes cluster** running k3s v1.25+ or similar
- **kubectl** configured with cluster admin access
- **kubeseal** CLI installed for sealed secrets ([installation guide](https://github.com/bitnami-labs/sealed-secrets#kubeseal))
- **Git** for cloning the repository
- **Storage**: Sufficient disk space for Longhorn distributed storage (recommended: 100GB+ per node)
- **Network**: Static IP range for MetalLB load balancer

### Setup Steps

#### 1. Clone Repository

```bash
git clone https://github.com/coredev-uk/homelab.git
cd homelab
```

#### 2. Bootstrap ArgoCD

```bash
kubectl apply -k bootstrap/
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

#### 3. Configure Secrets

```bash
cd secrets

# Copy example and configure values
cp secrets.env.example secrets.env
nano secrets.env
```

**Required secrets:**
- **PIHOLE_WEBPASSWORD**: Pi-hole admin password
- **FRIGATE_MQTT_PASSWORD**: MQTT broker password for Frigate
- **CLOUDFLARE_API_TOKEN**: API token for cert-manager DNS challenges
- **NOTIFIARR_API_KEY**: Notifiarr API key for notifications
- **GLANCE_WEATHER_LOCATION**: Weather location for Glance dashboard

#### 4. Generate Sealed Secrets

```bash
# Generate sealed secrets
./generate-sealed-secrets.sh

cd ..
```

#### 5. Deploy Applications

```bash
kubectl apply -f apps/app-of-apps.yaml

# Monitor deployment
kubectl get applications -n argocd
watch kubectl get pods -A
```

#### 6. Get ArgoCD Admin Password

```bash
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

#### 7. Access Services

Once deployed, services are accessible via their configured ingress routes. ArgoCD is exposed via LoadBalancer service.

Find the ArgoCD LoadBalancer IP:
```bash
kubectl get svc argocd-server -n argocd
```

Access the ArgoCD UI at `http://<LOADBALANCER-IP>` with username `admin` and the password from step 6.

</details>

<details>
<summary><strong>📋 Services Overview</strong></summary>

### Core Infrastructure
- **ArgoCD**: GitOps deployment and management with web UI
- **Sealed Secrets**: Secure secret management with encryption
- **Longhorn**: Distributed persistent storage with replication
- **Traefik**: Ingress controller and reverse proxy
- **MetalLB**: Load balancer for bare metal Kubernetes
- **Cert Manager**: Automatic SSL certificate management via Let's Encrypt
- **Cloudflare Tunnel**: Secure external access without port forwarding

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

</details>

## Structure

```
├── apps/                    # ArgoCD application definitions
│   ├── infrastructure/      # Infrastructure app-of-apps
│   ├── media-stack/         # Media stack app-of-apps
│   ├── monitoring/          # Monitoring app-of-apps
│   └── app-of-apps.yaml    # Root application manifest
├── bootstrap/               # ArgoCD installation and initial setup
├── k8s/                     # Kubernetes manifests for all services
│   ├── argocd/             # ArgoCD ingress and configuration
│   ├── cert-manager/       # Certificate management
│   ├── cloudflare-tunnel/  # Cloudflare tunnel for external access
│   ├── intel-gpu/          # Intel GPU device plugin
│   ├── longhorn/           # Distributed block storage
│   ├── metallb/            # Load balancer
│   ├── pihole/             # DNS ad blocking
│   ├── sealed-secrets/     # Secret encryption controller
│   ├── shared-storage/     # Shared persistent volumes
│   ├── traefik/            # Ingress controller
│   ├── frigate/            # Security camera system
│   ├── jellyfin/           # Media server
│   ├── jellyseerr/         # Media requests
│   ├── radarr/             # Movie management
│   ├── sonarr/             # TV series management
│   ├── bazarr/             # Subtitle management
│   ├── prowlarr/           # Indexer management
│   ├── qbittorrent/        # Torrent client
│   ├── sabnzbd/            # Usenet client
│   ├── cleanuparr/         # Media cleanup
│   ├── huntarr/            # Torrent management
│   ├── notifiarr/          # Notifications
│   ├── glance/             # Dashboard
│   ├── prometheus/         # Metrics collection
│   ├── grafana/            # Metrics visualization
│   ├── kube-state-metrics/ # Kubernetes metrics
│   └── node-exporter/      # Node metrics
└── secrets/                 # Sealed secrets configuration
    └── sealed-secrets/      # Generated sealed secret manifests
```

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Feedback & Suggestions

If you have any recommendations or suggestions for improving this homelab configuration, please feel free to contact me at [core@coredev.uk](mailto:core@coredev.uk).

---

*This project was developed with assistance from AI to help with configuration management, documentation, and infrastructure optimization.*
