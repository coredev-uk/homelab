<div align="center">

# Homelab Configuration

</div>

A personal Kubernetes homelab configuration using ArgoCD for GitOps deployment of a complete media automation stack, DNS services, storage management, and monitoring tools. This setup includes the popular *arr media management suite, torrent/usenet clients with VPN integration, and essential infrastructure services.

**Note:** This configuration is tailored for my specific environment and setup. You can fork this repository and modify the configurations to work with your own infrastructure.

## Quick Start

<details>
<summary><strong>📖 Installation Guide</strong></summary>

### Prerequisites

- **Kubernetes cluster** with k3s v1.25+ running
- **kubectl** configured with cluster access
- **kubeseal** CLI installed ([installation instructions](https://github.com/bitnami-labs/sealed-secrets#kubeseal))
- **Git access** to clone repository
- **Storage requirements**: Sufficient disk space for Longhorn (recommended: 100GB+ per node)

### Setup Steps

#### 1. Clone Repository

```bash
git clone https://github.com/coredev-uk/homelab.git
cd homelab
```

#### 2. Deploy Sealed Secrets Controller

```bash
kubectl apply -k core/sealed-secrets/
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets
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
- **WIREGUARD_PRIVATE_KEY**: Legacy VPN private key (kept for compatibility)
- **CLOUDFLARE_API_TOKEN**: API token for cert-manager DNS challenges
- **NOTIFIARR_API_KEY**: Notifiarr API key for notifications
- **GLANCE_WEATHER_LOCATION**: Weather location for Glance dashboard

#### 4. VPN Configuration

This homelab uses a ConfigMap approach for VPN settings, making it easy to switch providers by updating `/manifests/vpn-config.yaml`.

##### a. Configure VPN Settings

1. **Update the ConfigMap** (`manifests/vpn-config.yaml`) with your VPN provider's details:
   - Replace `YOUR_VPN_SERVER_PUBLIC_KEY_HERE` with your VPN server's public key
   - Replace `YOUR_VPN_ENDPOINT_HERE:51820` with your VPN server's endpoint
   - Update IP addresses if needed (Address fields in the WireGuard configs)

2. **Add private keys to secrets.env**:
   ```bash
   QFLOOD_WIREGUARD_PRIVATE_KEY="your_qflood_private_key_here"
   SABNZBD_WIREGUARD_PRIVATE_KEY="your_sabnzbd_private_key_here"
   ```

##### b. (Optional) Customize VPN Settings

Edit `manifests/vpn-config.yaml` to change VPN provider or settings:
```yaml
# Change VPN_PROVIDER to switch providers (wireguard, custom, etc.)
VPN_PROVIDER: "custom"
```

##### c. Generate All Sealed Secrets

```bash
# Generate sealed secrets (including VPN configs)
./generate-sealed-secrets.sh

cd ..
```

#### 5. Bootstrap ArgoCD

```bash
kubectl apply -k bootstrap/
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

#### 6. Deploy Applications

```bash
kubectl apply -f apps/app-of-apps.yaml

# Monitor deployment
kubectl get applications -n argocd
kubectl get namespaces | grep -E "(dns|security|cert-manager|media|monitoring)"
```

#### 7. Apply Sealed Secrets

```bash
cd secrets

# Apply standard secrets
kubectl apply -f sealed-secrets/pihole-sealed-secret.yaml
kubectl apply -f sealed-secrets/frigate-sealed-secret.yaml
kubectl apply -f sealed-secrets/vpn-sealed-secret.yaml
kubectl apply -f sealed-secrets/cloudflare-sealed-secret.yaml
kubectl apply -f sealed-secrets/notifiarr-sealed-secret.yaml
kubectl apply -f sealed-secrets/glance-sealed-secret.yaml

# Apply VPN secrets (if generated)
kubectl apply -f sealed-secrets/qflood-wireguard-sealed-secret.yaml
kubectl apply -f sealed-secrets/sabnzbd-wireguard-sealed-secret.yaml

# Verify secrets were created
kubectl get sealedsecrets -A
kubectl get secrets -A | grep -E "(pihole|frigate|vpn|cloudflare|notifiarr|glance|qflood|sabnzbd)"

cd ..
```

#### 8. Get ArgoCD Admin Password

```bash
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

#### 9. Watch Deployment Progress

```bash
kubectl get pods -A --watch
```

</details>

<details>
<summary><strong>📋 Services Overview</strong></summary>

### Core Infrastructure
- **ArgoCD**: GitOps deployment and management
- **Sealed Secrets**: Secure secret management
- **Longhorn**: Distributed persistent storage
- **Traefik**: Ingress controller and load balancer
- **MetalLB**: Load balancer for bare metal
- **Cert Manager**: Automatic SSL certificate management

### DNS & Security
- **Pihole**: Network-wide DNS ad blocking
- **Frigate**: AI-powered security camera system with Intel GPU acceleration

### Media Automation Stack
- **Jellyfin**: Media server for movies, TV shows, and music
- **Jellyseerr**: Media request management interface
- **Radarr**: Movie collection management
- **Sonarr**: TV series collection management  
- **Bazarr**: Subtitle management for media
- **Prowlarr**: Indexer management for search providers

### Download Clients (VPN-Protected)
- **QFlood**: Modern qBittorrent + Flood UI with VPN protection
  - Auto port forwarding for optimal seeding
  - Privoxy proxy for secure indexer access
  - Modern web interface replacing old qBittorrent UI
- **SABnzbd**: Usenet downloader with dedicated VPN connection

### Monitoring & Dashboards
- **Glance**: All-in-one dashboard with stocks, crypto, RSS feeds, and service monitoring
- **Grafana**: Metrics visualization and alerting
- **Prometheus**: Metrics collection and storage
- **Node Exporter**: System metrics collection

### Utilities
- **Notifiarr**: Centralized notification system
- **Cleanuparr**: Automated media library cleanup
- **Huntarr**: Advanced torrent management

### Storage & Networking
- **Longhorn**: Replicated block storage with web UI
- **Host Path Volumes**: Direct node storage access for media files
- **Ingress Routes**: HTTPS access via custom domain names

</details>

## Structure

```
├── apps/                    # ArgoCD application definitions
├── bootstrap/               # ArgoCD installation and initial setup
├── core/                    # Core infrastructure services
├── manifests/               # Shared Kubernetes manifests
├── media/                   # Media automation stack (including VPN-secured apps)
├── monitoring/              # Observability stack
└── secrets/                 # Sealed secrets configuration
```

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Feedback & Suggestions

If you have any recommendations or suggestions for improving this homelab configuration, please feel free to contact me at [core@coredev.uk](mailto:core@coredev.uk).

---

*This project was developed with assistance from AI to help with configuration management, documentation, and infrastructure optimization.*
