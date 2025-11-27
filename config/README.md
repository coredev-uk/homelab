# Shared Configuration

This directory contains shared configuration files that are used across multiple application namespaces via Kustomize.

## Configuration Files

### common-env.env
Contains standard environment variables used by LinuxServer.io-based containers:
- `TZ`: Timezone (Europe/London)
- `PUID`: User ID (1000)
- `PGID`: Group ID (100 - users group)
- `UMASK`: File creation mask (002)

**Used by:** radarr, sonarr, bazarr, jellyfin, jellyseerr, sabnzbd, qbittorrent, notifiarr, glance, huntarr, prowlarr, cleanuparr

### vpn-config.env
Contains VPN configuration for gluetun sidecars:
- VPN provider and connection settings
- Firewall rules and subnet configuration
- Proxy configuration (Shadowsocks, HTTP)

**Used by:** sabnzbd, qbittorrent

### gluetun-auth.toml
Contains gluetun authentication and authorization configuration:
- API access control for monitoring tools

**Used by:** sabnzbd, qbittorrent

## How It Works

Each app uses Kustomize's `configMapGenerator` to create namespace-scoped ConfigMaps from these shared files.

Example from `k8s/radarr/app/kustomization.yaml`:
```yaml
configMapGenerator:
  - name: common-env-config
    envs:
      - ../../../config/common-env.env
```

This generates a ConfigMap named `common-env-config` in the `radarr` namespace with the values from the shared file.

## Benefits

- **Single source of truth**: Update once in `config/`, applies to all apps
- **Namespace isolation**: Each app gets its own ConfigMap instance
- **No duplication**: Config files are not copied into each app directory
- **Version control**: Kustomize tracks changes via hash suffixes

## Legacy Files

The following files are kept for reference but not actively used:
- `common-config.yaml` - Original ConfigMap format
- `vpn-config.yaml` - Original ConfigMap format
