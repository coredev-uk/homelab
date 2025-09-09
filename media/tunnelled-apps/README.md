# Tunnelled Applications Management Guide

This directory contains VPN-secured media applications with individual gluetun sidecars for optimal performance and isolation.

## 📁 File Structure

```
tunnelled-apps/
├── qbittorrent.yaml         # BitTorrent client + VPN sidecar
├── prowlarr.yaml           # Indexer manager + VPN sidecar  
├── sabnzbd.yaml            # Usenet downloader + VPN sidecar
├── vpn-config.yaml         # Shared VPN provider settings
├── qbittorrent-config.yaml # qBittorrent configuration template
├── sabnzbd-scripts.yaml    # SABnzbd post-processing scripts
├── kustomization.yaml      # Kustomize resource management
└── README.md              # This file
```

## 🏗️ Architecture Overview

Each application runs in its own pod with a dedicated gluetun VPN sidecar:

| **Application** | **Pod** | **VPN Port** | **App Port** | **Optimization** |
|-----------------|---------|--------------|--------------|------------------|
| qBittorrent     | `qbittorrent-xxx` | 8000 | 8080 | P2P + Port Forwarding |
| Prowlarr        | `prowlarr-xxx` | 8001 | 9696 | Low-latency indexing |
| SABnzbd         | `sabnzbd-xxx` | 8002 | 8080 | High-bandwidth downloads |

## 🚀 Deployment Commands

### Deploy All Applications
```bash
# Deploy entire tunnelled apps stack
kubectl apply -k media/tunnelled-apps/

# Check deployment status
kubectl get pods -n media -l app.kubernetes.io/name=tunnelled-apps
```

### Deploy Individual Applications
```bash
# Deploy only qBittorrent
kubectl apply -f media/tunnelled-apps/qbittorrent.yaml

# Deploy only Prowlarr
kubectl apply -f media/tunnelled-apps/prowlarr.yaml

# Deploy only SABnzbd
kubectl apply -f media/tunnelled-apps/sabnzbd.yaml
```

### Remove Individual Applications
```bash
# Remove only qBittorrent (keeps others running)
kubectl delete -f media/tunnelled-apps/qbittorrent.yaml

# Remove only Prowlarr
kubectl delete -f media/tunnelled-apps/prowlarr.yaml

# Remove only SABnzbd
kubectl delete -f media/tunnelled-apps/sabnzbd.yaml
```

## 🔧 Common Management Tasks

### Restart Individual Applications
```bash
# Restart qBittorrent pod (VPN reconnects automatically)
kubectl rollout restart deployment/qbittorrent -n media

# Restart Prowlarr pod
kubectl rollout restart deployment/prowlarr -n media

# Restart SABnzbd pod
kubectl rollout restart deployment/sabnzbd -n media
```

### Check VPN Status
```bash
# Check qBittorrent VPN status
kubectl exec -n media deployment/qbittorrent -c gluetun -- wget -qO- http://localhost:8000/v1/publicip/ip

# Check Prowlarr VPN status  
kubectl exec -n media deployment/prowlarr -c gluetun -- wget -qO- http://localhost:8001/v1/publicip/ip

# Check SABnzbd VPN status
kubectl exec -n media deployment/sabnzbd -c gluetun -- wget -qO- http://localhost:8002/v1/publicip/ip
```

### View Logs
```bash
# View qBittorrent application logs
kubectl logs -n media deployment/qbittorrent -c qbittorrent -f

# View qBittorrent VPN logs
kubectl logs -n media deployment/qbittorrent -c gluetun -f

# View Prowlarr logs
kubectl logs -n media deployment/prowlarr -c prowlarr -f

# View SABnzbd logs
kubectl logs -n media deployment/sabnzbd -c sabnzbd -f
```

## ⚙️ Configuration Updates

### Update VPN Settings (affects all apps)
1. Edit `vpn-config.yaml`
2. Apply changes: `kubectl apply -f media/tunnelled-apps/vpn-config.yaml`
3. Restart deployments to pick up changes:
   ```bash
   kubectl rollout restart deployment/qbittorrent -n media
   kubectl rollout restart deployment/prowlarr -n media  
   kubectl rollout restart deployment/sabnzbd -n media
   ```

### Update qBittorrent Configuration
1. Edit `qbittorrent-config.yaml`
2. Apply changes: `kubectl apply -f media/tunnelled-apps/qbittorrent-config.yaml`
3. Restart qBittorrent: `kubectl rollout restart deployment/qbittorrent -n media`

### Update SABnzbd Scripts
1. Edit `sabnzbd-scripts.yaml`
2. Apply changes: `kubectl apply -f media/tunnelled-apps/sabnzbd-scripts.yaml`
3. Restart SABnzbd: `kubectl rollout restart deployment/sabnzbd -n media`

## 🎯 Resource Scaling

### Scale Applications Individually
```bash
# Scale qBittorrent (usually keep at 1)
kubectl scale deployment/qbittorrent --replicas=1 -n media

# Scale Prowlarr (usually keep at 1)
kubectl scale deployment/prowlarr --replicas=1 -n media

# Scale SABnzbd (can scale to 2+ for multiple downloads)
kubectl scale deployment/sabnzbd --replicas=2 -n media
```

### Adjust Resource Limits
Edit the individual YAML files and modify the `resources` section:
```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "200m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

## 🔍 Troubleshooting

### VPN Connection Issues
```bash
# Check if VPN is connected
kubectl exec -n media deployment/qbittorrent -c gluetun -- wget -qO- https://ipinfo.io/country

# Check gluetun control server
kubectl port-forward -n media deployment/qbittorrent 8000:8000
# Visit: http://localhost:8000/v1/publicip/ip
```

### Port Conflicts
Each deployment uses unique control ports:
- qBittorrent gluetun: 8000
- Prowlarr gluetun: 8001  
- SABnzbd gluetun: 8002

### Application Won't Start
```bash
# Check pod events
kubectl describe pod -n media -l app=qbittorrent

# Check init container logs
kubectl logs -n media deployment/qbittorrent -c setup-config
```

## 🚨 Emergency Procedures

### Disable VPN for Debugging
Temporarily comment out the gluetun container in any YAML file and redeploy to test application functionality without VPN.

### Restore Previous Configuration
```bash
# View configuration history
kubectl rollout history deployment/qbittorrent -n media

# Rollback to previous version
kubectl rollout undo deployment/qbittorrent -n media
```

## 📊 Monitoring

### Check Resource Usage
```bash
# View resource usage for all tunnelled apps
kubectl top pods -n media -l app.kubernetes.io/name=tunnelled-apps

# View detailed resource info
kubectl describe pods -n media -l app=qbittorrent
```

### Application URLs
- qBittorrent: `http://qbittorrent.media:8080`
- Prowlarr: `http://prowlarr.media:9696`
- SABnzbd: `http://sabnzbd.media:8080`
- FlareSolverr: `http://prowlarr.media:8191`