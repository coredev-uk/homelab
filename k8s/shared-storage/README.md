# Shared Storage

This directory contains PersistentVolume definitions for shared storage across multiple applications.

## Current Status

⚠️ **ACTION REQUIRED**: The PVCs need to be created in each namespace that uses them.

## Storage Resources

### PersistentVolumes (Cluster-scoped)
- `downloads-pv`: 100Gi, ReadWriteMany, hostPath: /opt/downloads
- `media-pv`: 500Gi, ReadWriteMany, hostPath: /opt/media
- `frigate-pv`: 50Gi, ReadWriteOnce, hostPath: /opt/frigate
- `jellyfin-pv`: 50Gi, ReadWriteOnce, hostPath: /opt/jellyfin

### PersistentVolumeClaims (Namespace-scoped)

The following apps need PVCs created in their namespaces:

**media-pvc** (binds to media-pv):
- bazarr
- cleanuparr
- jellyfin
- radarr
- sonarr

**downloads-pvc** (binds to downloads-pv):
- qbittorrent
- radarr
- sabnzbd
- sonarr

**jellyfin-pvc** (binds to jellyfin-pv):
- jellyfin

**frigate-pvc** (binds to frigate-pv):
- frigate

## Migration Note

These PVCs were previously in the shared `media` and `security` namespaces. Now that apps are in individual namespaces, the PVCs need to be created in each app's namespace. Since hostPath volumes with ReadWriteMany can be bound by multiple PVCs, this is safe.

## TODO

Create PVC resources in each app's namespace, or create a kustomization to generate them automatically.
