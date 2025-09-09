# Homelab Setup Guide

## Prerequisites

1. **NixOS servers** with k3s configured (see [NixOS config](https://github.com/coredev-uk/nixos))
2. **Git access** to clone from GitHub  
3. **Kubernetes v1.25+** required for Longhorn v1.9.1
4. **Storage requirements**:
   - Sufficient disk space on nodes for Longhorn storage pool (recommended: 100GB+ per node)
   - `/var/lib/longhorn/` directory will be created automatically for Longhorn data
   - Media PVC configured for 1TiB shared storage across media services
5. **Network access** for pulling container images and accessing external services

## Node-Specific Setup

<details>
<summary><strong>📋 Master Node Setup (Control Plane)</strong></summary>

### System Requirements
- **Minimum specs**: 2 CPU cores, 4GB RAM, 20GB storage
- **Recommended**: 4+ CPU cores, 8GB+ RAM, 100GB+ storage
- **Network**: Static IP address configured
- **Role**: Runs Kubernetes control plane and workloads

### Prerequisites
- NixOS installed with k3s service enabled as server
- k3s configured with cluster-init and required firewall ports (6443/tcp)
- Built-in services disabled (servicelb, traefik, local-storage)

### Master Node Configuration
```bash
# Verify k3s cluster is running
sudo systemctl status k3s

# Set up kubectl access (if not already configured)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

# Verify cluster access
kubectl cluster-info
kubectl get nodes -o wide
```

### Storage Setup (Master Node)
```bash
# Verify Longhorn prerequisites are installed (should be via NixOS config)
sudo systemctl status iscsid

# Verify Longhorn storage directory
ls -la /var/lib/longhorn/

# Check disk space
df -h /var/lib/longhorn/
```

</details>

<details>
<summary><strong>🔧 Worker Node Setup</strong></summary>

### System Requirements
- **Minimum specs**: 1 CPU core, 2GB RAM, 10GB storage
- **Recommended**: 2+ CPU cores, 4GB+ RAM, 50GB+ storage
- **Network**: Access to master node
- **Role**: Runs workloads, provides distributed storage

### Prerequisites
- NixOS installed with k3s service enabled as agent
- k3s configured to join master server
- iscsi services enabled for Longhorn storage

### Worker Node Verification
```bash
# Verify k3s agent is running
sudo systemctl status k3s

# Check node joined cluster (run on master)
kubectl get nodes -o wide
```

### Storage Setup (Worker Node)
```bash
# Verify iscsi service is running (should be via NixOS config)
sudo systemctl status iscsid

# Verify Longhorn storage directory exists
ls -la /var/lib/longhorn/

# Check available disk space
df -h /var/lib/longhorn/
```

### Worker Node Labels (Optional)
```bash
# Label worker nodes for specific workloads (run on master)
kubectl label node <worker-node-name> node-role.kubernetes.io/worker=worker
kubectl label node <worker-node-name> storage=enabled

# Verify labels
kubectl get nodes --show-labels
```

</details>

## Initial Setup

### 1. Clone Repository on Hyperion
```bash
# SSH to Hyperion and clone the repo
ssh hyperion  # or however you access Hyperion
git clone https://github.com/coredev-uk/homelab.git
cd homelab
```

### 2. Configure Secrets
This project uses Sealed Secrets for secure secret management. Follow these steps:

#### a. Install kubeseal CLI
```bash
# Install kubeseal (on your local machine or the cluster)
KUBESEAL_VERSION='0.31.0'
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

#### b. Deploy Sealed Secrets Controller
```bash
# Apply the sealed-secrets controller (included in core deployment)
kubectl apply -k core/sealed-secrets/

# Wait for controller to be ready
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets
```

#### c. Generate SealedSecrets
```bash
# Navigate to secrets directory
cd secrets

# Copy the example file and fill in your values
cp secrets.env.example secrets.env
nano secrets.env

# Generate SealedSecret files (requires controller to be running)
./generate-sealed-secrets.sh

# Note: Do NOT apply the SealedSecrets yet - namespaces don't exist yet!
# These will be applied after ArgoCD creates the namespaces
```

**Required secrets to configure:**
- **PIHOLE_WEBPASSWORD**: Web admin password for Pi-hole
- **FRIGATE_MQTT_PASSWORD**: MQTT broker password for Frigate
- **WIREGUARD_PRIVATE_KEY**: Your VPN provider's WireGuard private key (raw format)
- **CLOUDFLARE_API_TOKEN**: API token for Cloudflare DNS challenges (cert-manager)
- **NOTIFIARR_API_KEY**: API key for Notifiarr notification service

**Note**: SERVER_COUNTRIES is now managed via ConfigMap (not secret) and defaults to "Netherlands".

### 3. Configure Frigate Cameras (Optional)
```bash
# Edit Frigate config to add your cameras
nano core/frigate/deployment.yaml
# Lines 150-170: Uncomment and configure with your camera RTSP URLs
```

### 4. Storage Verification
```bash
# Verify Longhorn prerequisites on nodes
kubectl get nodes -o wide

# Check available disk space
df -h /var/lib/longhorn/

# Verify storage class is available after deployment
kubectl get storageclass longhorn
```

## Deployment Steps

### 1. Bootstrap ArgoCD and Create Namespaces
```bash
kubectl apply -k bootstrap/
```

### 2. Wait for ArgoCD
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 3. Deploy Applications
```bash
kubectl apply -f apps/app-of-apps.yaml
```

### 4. Wait for ArgoCD Applications to Deploy
```bash
# Wait for ArgoCD to sync all applications
kubectl wait --for=condition=available --timeout=600s deployment/argocd-applicationset-controller -n argocd

# Monitor application sync status
kubectl get applications -n argocd

# Verify namespaces are created
kubectl get namespaces | grep -E "(dns|security|cert-manager|media)"
```

### 5. Apply Sealed Secrets (After Namespaces Exist)
```bash
# Now apply the SealedSecrets to the created namespaces
cd secrets
kubectl apply -f sealed-secrets/pihole-sealed-secret.yaml
kubectl apply -f sealed-secrets/frigate-sealed-secret.yaml
kubectl apply -f sealed-secrets/vpn-sealed-secret.yaml
kubectl apply -f sealed-secrets/cloudflare-sealed-secret.yaml
kubectl apply -f sealed-secrets/notifiarr-sealed-secret.yaml

# Verify SealedSecrets were created and unsealed
kubectl get sealedsecrets -A
kubectl get secrets -A | grep -E "(pihole|frigate|vpn|cloudflare|notifiarr)-secrets"
cd ..
```

### 6. Get ArgoCD Admin Password
```bash
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 7. Verify Storage Deployment
```bash
# Check Longhorn system pods
kubectl get pods -n longhorn-system

# Verify storage class is ready
kubectl get storageclass

# Check that PVCs are bound (may take a few minutes)
kubectl get pvc -A

# If PVCs are still pending, restart affected pods:
kubectl delete pods -l app=pihole -n dns
kubectl delete pods -l app=radarr -n media  # etc.

# Access Longhorn UI for storage management
echo "Longhorn UI: https://longhorn.home.coredev.uk"
```
### 8. Watch Deployment Progress
```bash
kubectl get pods -A --watch
```

## Access Configuration

### Configure DNS/Hosts
You have two options for accessing services:

#### Option 1: Using Pihole DNS (Recommended)
After Pihole is deployed and configured as your network DNS:
1. Access Pihole admin at `http://<hyperion-ip>/admin`
2. Go to **Local DNS** → **DNS Records**
3. Add these A records:

| Domain | IP Address |
|--------|------------|
| argocd.home.coredev.uk | `<hyperion-ip>` |
| glance.home.coredev.uk | `<hyperion-ip>` |
| pihole.home.coredev.uk | `<hyperion-ip>` |
| longhorn.home.coredev.uk | `<hyperion-ip>` |
| frigate.home.coredev.uk | `<hyperion-ip>` |
| radarr.home.coredev.uk | `<hyperion-ip>` |
| sonarr.home.coredev.uk | `<hyperion-ip>` |
| bazarr.home.coredev.uk | `<hyperion-ip>` |
| prowlarr.home.coredev.uk | `<hyperion-ip>` |
| jellyfin.home.coredev.uk | `<hyperion-ip>` |
| jellyseerr.home.coredev.uk | `<hyperion-ip>` |
| qbittorrent.home.coredev.uk | `<hyperion-ip>` |
| sabnzbd.home.coredev.uk | `<hyperion-ip>` |
| notifiarr.home.coredev.uk | `<hyperion-ip>` |
| cleanuparr.home.coredev.uk | `<hyperion-ip>` |
| flaresolverr.home.coredev.uk | `<hyperion-ip>` |
| huntarr.home.coredev.uk | `<hyperion-ip>` |

#### Option 2: Local /etc/hosts (Temporary)
For initial setup or if not using Pihole DNS:
```bash
# Add to /etc/hosts on your client machine
<hyperion-ip> argocd.home.coredev.uk glance.home.coredev.uk pihole.home.coredev.uk longhorn.home.coredev.uk frigate.home.coredev.uk
<hyperion-ip> radarr.home.coredev.uk sonarr.home.coredev.uk bazarr.home.coredev.uk prowlarr.home.coredev.uk
<hyperion-ip> jellyfin.home.coredev.uk jellyseerr.home.coredev.uk qbittorrent.home.coredev.uk sabnzbd.home.coredev.uk notifiarr.home.coredev.uk
<hyperion-ip> cleanuparr.home.coredev.uk flaresolverr.home.coredev.uk huntarr.home.coredev.uk
```

## Service URLs

| Service | URL | Direct Port | Purpose |
|---------|-----|-------------|---------|
| ArgoCD | https://argocd.home.coredev.uk | :80 | GitOps Dashboard |
| Glance | https://glance.home.coredev.uk | :8080 | Dashboard (Stocks, Crypto, RSS) |
| Pihole | https://pihole.home.coredev.uk | :80 | DNS Adblocking |
| Longhorn | https://longhorn.home.coredev.uk | :80 | Storage Management |
| Frigate | https://frigate.home.coredev.uk | :5000 | CCTV Management |
| Jellyfin | https://jellyfin.home.coredev.uk | :8096 | Media Server |
| Jellyseerr | https://jellyseerr.home.coredev.uk | :5055 | Media Requests |
| Radarr | https://radarr.home.coredev.uk | :7878 | Movie Management |
| Sonarr | https://sonarr.home.coredev.uk | :8989 | TV Management |
| Bazarr | https://bazarr.home.coredev.uk | :6767 | Subtitle Management |
| Prowlarr | https://prowlarr.home.coredev.uk | :9696 | Indexer Management |
| qBittorrent | https://qbittorrent.home.coredev.uk | :8080 | Torrent Client |
| SABnzbd | https://sabnzbd.home.coredev.uk | :8090 | Usenet Client |
| Notifiarr | https://notifiarr.home.coredev.uk | :5454 | Notifications |
| Cleanuparr | https://cleanuparr.home.coredev.uk | :11011 | Media Cleanup |
| Flaresolverr | https://flaresolverr.home.coredev.uk | :8191 | Cloudflare Bypass |
| Huntarr | https://huntarr.home.coredev.uk | :9705 | Torrent Management |

### Direct IP Access (Troubleshooting)
If ingress is not working, you can access services directly using:
```
http://<hyperion-ip>:<port>
```

For example:
- Pihole: `http://10.147.20.20:80/admin` 
- Jellyfin: `http://10.147.20.20:8096`
- Radarr: `http://10.147.20.20:7878`

**Note**: Direct IP access requires services to be configured as LoadBalancer or NodePort instead of ClusterIP.

## Post-Setup Configuration

### 1. Access Primary Services
- **ArgoCD**: `https://argocd.home.coredev.uk` (username: `admin`, password from step 3 above)
- **Glance**: `https://glance.home.coredev.uk` (your main dashboard)
- **Pihole**: `https://pihole.home.coredev.uk` (admin interface)

### 2. Configure Network DNS
- **Set Pihole as DNS**: Update router to use Hyperion's IP as DNS server for network-wide adblocking

### 3. Configure Media Stack
- **Set up connections** between arr-stack services (Radarr, Sonarr, Bazarr, Prowlarr)
- **Configure download clients** (qBittorrent, SABnzbd) in the arr services
- **Test VPN connectivity** for download clients

### 4. Add Camera Streams
- **Configure Frigate** with your camera RTSP streams in the deployment config

## Troubleshooting

### Check ArgoCD Applications
```bash
kubectl get applications -n argocd
```

### Check Pod Status
```bash
kubectl get pods -A
```

### View Service Logs
```bash
# Example: View Radarr logs
kubectl logs -f deployment/radarr -n media

# View ArgoCD logs
kubectl logs -f deployment/argocd-server -n argocd
```

### Check Storage
```bash
# View all persistent volumes and claims
kubectl get pv,pvc -A

# Check Longhorn system status
kubectl get pods -n longhorn-system

# Check storage class
kubectl get storageclass

# View Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system

# Check node storage capacity
kubectl describe nodes | grep -A5 "Capacity:"
```

### Longhorn-Specific Troubleshooting
```bash
# If PVCs are stuck in Pending:
# 1. Check if Longhorn CRDs are installed
kubectl get crd | grep longhorn

# 2. Check replica count for single-node setup
kubectl get settings.longhorn.io default-replica-count -n longhorn-system -o jsonpath='{.value}'

# 3. For single-node clusters, set replica count to 1
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ $NODE_COUNT -eq 1 ]; then
  kubectl patch settings.longhorn.io default-replica-count -n longhorn-system --type='merge' -p='{"value": "1"}'
fi

# 4. Check Longhorn manager logs
kubectl logs -l app=longhorn-manager -n longhorn-system -c longhorn-manager | tail -20

# 5. Restart pending pods after Longhorn configuration
kubectl get pods -A | grep Pending | awk '{print "kubectl delete pod " $2 " -n " $1}' | sh
```

### Restart Specific Service
```bash
# Example: Restart Radarr
kubectl rollout restart deployment/radarr -n media
```

## Migration from Docker Compose

1. **Export configurations** from your existing Docker setup
2. **Copy config directories** to `/opt/homelab/config/`
3. **Copy media files** to `/media/` (organized as `/media/movies/`, `/media/tv/`, etc.)
4. **Update service connections** in each app to use Kubernetes service names
5. **Test connectivity** between services

## Storage Management with Longhorn

### Overview
This homelab uses **Longhorn v1.9.1** as the distributed storage system, providing:
- **Replicated storage** with 2 replicas by default for high availability
- **Dynamic volume provisioning** via CSI driver
- **Volume expansion** support for growing storage needs
- **Web UI management** at `https://longhorn.home.coredev.uk`
- **Backup and snapshot** capabilities
- **Fast replica rebuilding** for improved performance
- **Enhanced data integrity** features
- **Kubernetes v1.25+** support

### Longhorn Configuration
- **Version**: v1.9.1 (deployed via Helm chart)
- **Default data path**: `/var/lib/longhorn/` on each node
- **Replica count**: Automatically configured (1 for single-node, 2+ for multi-node)
- **Storage class**: `longhorn` (default)
- **File system**: ext4
- **Reclaim policy**: Delete
- **Volume binding**: Immediate
- **Fast replica rebuilding**: Enabled for better performance
- **Revision counter**: Disabled for improved performance
- **Filesystem trim**: Enabled with snapshot removal

### Storage Features
- **Auto-salvage**: Enabled for automatic recovery
- **Replica soft anti-affinity**: Zone-aware replica placement
- **Storage over-provisioning**: 100% allowed
- **Minimal available storage**: 25% threshold
- **Volume expansion**: Supported for growing applications
- **Fast replica rebuilding**: Enabled for reduced downtime
- **Concurrent replica rebuilds**: Up to 5 per node
- **Snapshot data integrity**: Optional integrity checking
- **Filesystem trim**: Automatic snapshot cleanup during trim operations

### Managing Storage
```bash
# Check storage classes
kubectl get storageclass

# View persistent volumes and claims
kubectl get pv,pvc -A

# Check Longhorn system status
kubectl get pods -n longhorn-system

# View Longhorn volumes
kubectl get volumes.longhorn.io -n longhorn-system
```

### Backup Configuration
Longhorn supports backups to various destinations:
- **NFS**: Network File System shares
- **S3**: Amazon S3 or S3-compatible storage
- **Local**: Host filesystem paths

To configure backups, access the Longhorn UI and set up a backup target under **Settings** → **General**.

### Troubleshooting Storage Issues
```bash
# Check Longhorn manager logs
kubectl logs -f daemonset/longhorn-manager -n longhorn-system

# Check CSI plugin status
kubectl get daemonset/longhorn-csi-plugin -n longhorn-system

# Verify storage connectivity
kubectl describe nodes | grep -A5 "Capacity:"

# Check volume health
kubectl get volumes.longhorn.io -n longhorn-system -o wide
```

## Notes

- **VPN Services**: All VPN-dependent services use Gluetun sidecars
- **Storage**: Distributed persistent storage provided by Longhorn v1.9.1 with automated replica configuration
- **Performance**: Fast replica rebuilding and revision counter disabled for optimal performance
- **Ingress**: Services are accessible via Traefik ingress (built into k3s)
- **GitOps**: ArgoCD automatically syncs changes from Git repository
- **Pihole**: Set your router's DNS to Hyperion's IP for network-wide adblocking
- **Frigate**: Requires hardware acceleration (Intel QSV) and camera configuration
- **Glance**: All-in-one dashboard with service monitoring, stocks, crypto, and RSS feeds
- **Longhorn**: Provides distributed block storage with web-based management interface and advanced features
