# Shared Storage

This directory contains PersistentVolume definitions for shared storage across multiple applications.

## Storage Resources

### PersistentVolumes (Cluster-scoped)
- `downloads-pv`: 100Gi, ReadWriteMany, hostPath: /opt/downloads
- `media-pv`: 500Gi, ReadWriteMany, hostPath: /opt/media

### Application-Specific PVs
App-specific PVs are now defined in each app's deployment.yaml:
- `frigate-pv`: 50Gi, ReadWriteOnce, hostPath: /opt/frigate (in k8s/frigate/app/deployment.yaml)
- `jellyfin-pv`: 50Gi, ReadWriteOnce, hostPath: /opt/jellyfin (in k8s/jellyfin/app/deployment.yaml)

### PersistentVolumeClaims (Namespace-scoped)

Each app has PVCs created in their namespace (defined in storage.yaml):

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
- jellyfin (defined in k8s/jellyfin/app/storage.yaml)

**frigate-pvc** (binds to frigate-pv):
- frigate (defined in k8s/frigate/app/deployment.yaml)

## Architecture Notes

- **Shared volumes** (downloads-pv, media-pv): Use ReadWriteMany with hostPath, allowing multiple PVCs from different namespaces to bind to the same volume
- **App-specific volumes** (frigate-pv, jellyfin-pv): Use ReadWriteOnce and are co-located with their app deployments for better encapsulation
- All PVCs reference `storageClassName: ""` to prevent dynamic provisioning and ensure binding to pre-defined PVs
