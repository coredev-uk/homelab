# Homelab Setup Guide

## Prerequisites

1. **k3s cluster running** on your NixOS server (Hyperion)
2. **Git access** to clone from GitHub
3. **Storage paths** available on the host:
   - `/media` - for media files (movies, TV shows, etc.)
   - `/opt/homelab/config` - for application configs

## Initial Setup

### 1. Clone Repository on Hyperion
```bash
# SSH to Hyperion and clone the repo
ssh hyperion  # or however you access Hyperion
git clone https://github.com/coredev-uk/homelab.git
cd homelab
```

### 2. Update Secrets & Configuration
Edit these files with your actual values:
```bash
# 1. VPN Configuration
nano core/vpn/config.yaml
# Replace:
# - WIREGUARD_PRIVATE_KEY: "YOUR_ACTUAL_PRIVATE_KEY"
# - SERVER_COUNTRIES: "Netherlands" (or your preferred country)

# 2. Pihole Password
nano core/pihole/deployment.yaml
# Change line 42: WEBPASSWORD: "your_secure_password"

# 3. Pihole LoadBalancer IP
nano core/pihole/deployment.yaml
# Update line 108: loadBalancerIP to Hyperion's IP or remove the line

# 4. Frigate RTMP Password
nano core/frigate/deployment.yaml
# Change line 50: RTMP_PASSWORD: "your_secure_password"

# 5. Notifiarr API Key
nano media/notifiarr/deployment.yaml
# Change line 57: API_KEY: "YOUR_NOTIFIARR_API_KEY"
```

### 3. Configure Frigate Cameras (Optional)
```bash
# Edit Frigate config to add your cameras
nano core/frigate/deployment.yaml
# Lines 70-87: Uncomment and configure with your camera RTSP URLs
```

### 4. Create Host Directories
```bash
# Create required directories
sudo mkdir -p /media /opt/homelab/config
sudo chown 1000:1000 /media /opt/homelab/config

# Create Frigate media directory  
sudo mkdir -p /opt/homelab/frigate/media
sudo chown 1000:1000 /opt/homelab/frigate/media
```

## Deployment Steps

### 1. Bootstrap ArgoCD
```bash
kubectl apply -k bootstrap/
```

### 2. Wait for ArgoCD
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```

### 3. Get ArgoCD Admin Password
```bash
echo "ArgoCD Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

### 4. Deploy Applications
```bash
kubectl apply -f apps/app-of-apps.yaml
```

### 5. Watch Deployment Progress
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
| argocd.local | `<hyperion-ip>` |
| glance.local | `<hyperion-ip>` |
| pihole.local | `<hyperion-ip>` |
| longhorn.local | `<hyperion-ip>` |
| frigate.local | `<hyperion-ip>` |
| radarr.local | `<hyperion-ip>` |
| sonarr.local | `<hyperion-ip>` |
| bazarr.local | `<hyperion-ip>` |
| prowlarr.local | `<hyperion-ip>` |
| jellyfin.local | `<hyperion-ip>` |
| jellyseerr.local | `<hyperion-ip>` |
| qbittorrent.local | `<hyperion-ip>` |
| sabnzbd.local | `<hyperion-ip>` |
| notifiarr.local | `<hyperion-ip>` |

#### Option 2: Local /etc/hosts (Temporary)
For initial setup or if not using Pihole DNS:
```bash
# Add to /etc/hosts on your client machine
<hyperion-ip> argocd.local glance.local pihole.local longhorn.local frigate.local
<hyperion-ip> radarr.local sonarr.local bazarr.local prowlarr.local
<hyperion-ip> jellyfin.local jellyseerr.local qbittorrent.local sabnzbd.local notifiarr.local
```

## Service URLs

| Service | URL | Direct Port | Purpose |
|---------|-----|-------------|---------|
| ArgoCD | http://argocd.local | :80 | GitOps Dashboard |
| Glance | http://glance.local | :8080 | Dashboard (Stocks, Crypto, RSS) |
| Pihole | http://pihole.local | :80 | DNS Adblocking |
| Longhorn | http://longhorn.local | :80 | Storage Management |
| Frigate | http://frigate.local | :5000 | CCTV Management |
| Jellyfin | http://jellyfin.local | :8096 | Media Server |
| Jellyseerr | http://jellyseerr.local | :5055 | Media Requests |
| Radarr | http://radarr.local | :7878 | Movie Management |
| Sonarr | http://sonarr.local | :8989 | TV Management |
| Bazarr | http://bazarr.local | :6767 | Subtitle Management |
| Prowlarr | http://prowlarr.local | :9696 | Indexer Management |
| qBittorrent | http://qbittorrent.local | :8080 | Torrent Client |
| SABnzbd | http://sabnzbd.local | :8090 | Usenet Client |
| Notifiarr | http://notifiarr.local | :5454 | Notifications |

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
- **ArgoCD**: `http://argocd.local` (username: `admin`, password from step 3 above)
- **Glance**: `http://glance.local` (your main dashboard)
- **Pihole**: `http://pihole.local` (admin interface)

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
kubectl get pv,pvc -A
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

## Notes

- **VPN Services**: All VPN-dependent services use Gluetun sidecars
- **Storage**: Persistent storage uses local-path provisioner
- **Ingress**: Services are accessible via Traefik ingress (built into k3s)
- **GitOps**: ArgoCD automatically syncs changes from Git repository
- **Pihole**: Set your router's DNS to Hyperion's IP for network-wide adblocking
- **Frigate**: Requires hardware acceleration (Intel QSV) and camera configuration
- **Glance**: All-in-one dashboard with service monitoring, stocks, crypto, and RSS feeds