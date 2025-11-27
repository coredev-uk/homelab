# Shared Configuration

This directory contains ConfigMaps that are used across multiple application namespaces.

## ConfigMaps

### common-env-config
Contains standard environment variables used by LinuxServer.io-based containers:
- `TZ`: Timezone (Europe/London)
- `PUID`: User ID (1000)
- `PGID`: Group ID (100 - users group)
- `UMASK`: File creation mask (002)

**Used by:** radarr, sonarr, bazarr, jellyfin, jellyseerr, sabnzbd, qbittorrent, notifiarr, glance, huntarr

### vpn-config-shared
Contains VPN configuration for gluetun sidecars:
- VPN provider and connection settings
- Firewall rules and subnet configuration
- Proxy configuration (Shadowsocks, HTTP)

**Used by:** sabnzbd, qbittorrent

### gluetun-auth-config-shared
Contains gluetun authentication and authorization configuration:
- API access control for monitoring tools

**Used by:** sabnzbd, qbittorrent

## Deployment Strategy

These ConfigMaps need to be created in each namespace that uses them, since ConfigMaps are namespace-scoped. Consider using a tool like:
- Kustomize with `configMapGenerator` and namespace overlays
- ArgoCD's multi-source applications
- A custom controller to sync ConfigMaps across namespaces

Alternatively, convert to environment variables directly in deployments or use a centralized configuration service.
