# Migration Guide: Unified k8s/ Structure

## Overview

This guide helps you migrate from the old grouped structure (`media/`, `core/`, `security/`, `monitoring/`) to the new unified `k8s/` structure where each application has its own namespace.

## What's Changing

### Before (Main Branch)
```
homelab/
├── media/          # 12 apps in 'media' namespace
├── core/           # 5 apps in 'core' namespace
├── security/       # 1 app in 'security' namespace
├── monitoring/     # 4 apps split across namespaces
└── manifests/      # Shared networking/storage
```

**ArgoCD**: 6 Applications (grouped)

### After (Feature Branch)
```
homelab/
└── k8s/
    ├── radarr/         # Own namespace
    ├── sonarr/         # Own namespace
    ├── jellyfin/       # Own namespace
    └── ...27 apps total
```

**ArgoCD**: 27 Applications (individual)

## Critical Information

### Data Safety ✅
- All PersistentVolumes have `persistentVolumeReclaimPolicy: Retain`
- Your actual data on disk (`/opt/jellyfin`, `/opt/media`, etc.) **will NOT be deleted**
- However, PVCs will be deleted and recreated in new namespaces

### What Will Happen During Migration
1. ArgoCD syncs updated `app-of-apps.yaml`
2. Old grouped apps deleted → **resources in old namespaces deleted**
3. New individual apps created → **resources in new namespaces created**
4. PVs become "Released" (no longer bound to deleted PVCs)
5. New PVCs can't bind until PVs are manually cleared
6. **Apps won't start until PVs are rebound**

## Migration Steps

### Step 1: Pre-Migration Backup (REQUIRED)

Run the backup script to capture current state:

```bash
cd /home/paul/code/homelab
./scripts/pre-migration-backup.sh
```

This creates a timestamped backup directory with:
- All PV/PVC definitions
- All ConfigMaps and Secrets
- All ArgoCD Application states
- Summary report with current status

**Review the backup summary before proceeding!**

### Step 2: Prepare for Migration

1. **Review what will change:**
   ```bash
   # See all file changes
   git diff main..feat/unified-apps --stat
   
   # Review app-of-apps changes
   git diff main..feat/unified-apps apps/app-of-apps.yaml
   ```

2. **Verify all apps build correctly:**
   ```bash
   # On feature branch
   for dir in k8s/*/; do 
     kubectl kustomize "$dir" > /dev/null && echo "✅ $(basename $dir)"
   done
   ```

3. **Choose your migration strategy:**
   - **Option A**: Maintenance window (downtime acceptable) - Simplest
   - **Option B**: Rolling migration (minimize downtime) - More complex

### Step 3: Execute Migration

#### Option A: Maintenance Window (Recommended for First Time)

**IMPORTANT**: This will cause downtime for all applications during migration.

```bash
# 1. Run the migration script (dry-run first!)
./scripts/migrate-to-unified-structure.sh --dry-run

# 2. Review what it will do, then run for real
./scripts/migrate-to-unified-structure.sh

# The script will:
# - Disable auto-sync on old apps
# - Prompt you to merge the feature branch
# - Wait for you to confirm ArgoCD synced
# - Rebind all PersistentVolumes
# - Verify new apps
# - Clean up old apps
```

**Timeline:**
- Backup: ~2 minutes
- Git merge & ArgoCD sync: ~5 minutes
- PV rebinding: ~2 minutes
- Apps coming back up: ~5-10 minutes
- **Total downtime: 15-20 minutes**

#### Option B: Rolling Migration (Advanced)

If you need to minimize downtime, you can manually migrate apps one by one:

1. Disable auto-sync on old grouped apps
2. Create new individual apps with `prune: false` initially
3. Verify new apps work alongside old ones
4. Manually scale down old deployments
5. Rebind PVs to new namespaces
6. Scale up new deployments
7. Delete old apps once verified

**This is more complex and requires manual intervention per app.**

### Step 4: Post-Migration Verification

After migration completes:

```bash
# 1. Check all ArgoCD applications
kubectl get applications -n argocd

# Expected: 27 apps (excluding longhorn)
# All should show Sync: Synced, Health: Healthy

# 2. Check PersistentVolumes
kubectl get pv

# All should be in "Bound" state
# If any are "Released" or "Available", run rebinding again

# 3. Check pods in new namespaces
kubectl get pods -A | grep -E "radarr|sonarr|jellyfin|bazarr"

# All should be Running

# 4. Check ingress/services
kubectl get ingress -A

# Verify all your ingresses exist in new namespaces

# 5. Test application access
# Visit your apps via web browser:
# - https://jellyfin.home.coredev.uk
# - https://radarr.home.coredev.uk
# - etc.
```

### Step 5: Verify Data Integrity

Check that your applications still have their configuration:

1. **Jellyfin**: Check that your library and watch history are intact
2. **Radarr/Sonarr**: Verify your library still shows all movies/shows
3. **qBittorrent**: Check that active torrents are still there
4. **Prowlarr**: Verify indexers are configured

If configuration is missing, the PV may not have bound correctly.

## Troubleshooting

### Problem: PV stuck in "Released" state

**Symptoms:**
```
NAME           STATUS     CLAIM              AGE
jellyfin-pv    Released   media/jellyfin-pvc 5d
```

**Solution:**
```bash
# Clear the claimRef to make it Available
kubectl patch pv jellyfin-pv --type json \
  -p '[{"op": "remove", "path": "/spec/claimRef"}]'

# Verify it's now Available
kubectl get pv jellyfin-pv
# Should show: Available
```

### Problem: Pod stuck in "Pending" state

**Symptoms:**
```
NAME                        READY   STATUS    RESTARTS   AGE
jellyfin-5b7f8c4d9-xyz      0/1     Pending   0          2m
```

**Check:**
```bash
kubectl describe pod -n jellyfin jellyfin-5b7f8c4d9-xyz
```

**Common causes:**
- PVC not bound (check `kubectl get pvc -n jellyfin`)
- PV not available (check `kubectl get pv`)
- Insufficient resources (check node capacity)

### Problem: ArgoCD app shows "OutOfSync"

**Solution:**
```bash
# Sync the application
kubectl patch application <app-name> -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"manual"},"sync":{"syncStrategy":{"hook":{}}}}}'

# Or use ArgoCD CLI
argocd app sync <app-name>

# Or use the UI
# Visit ArgoCD UI and click "Sync" button
```

### Problem: ConfigMap or Secret missing in new namespace

**Symptoms:**
- App can't start
- Logs show "secret not found" or "configmap not found"

**Solution:**
Check your sealed-secrets or manual secrets:
```bash
# List secrets in new namespace
kubectl get secrets -n <app-name>

# If missing, recreate from backup
kubectl apply -f ./pre-migration-backup-*/secrets/<old-namespace>-secrets.yaml

# Or recreate sealed secrets
cd secrets/
./generate-sealed-secrets.sh
```

## Rollback Procedure

If migration fails and you need to rollback:

```bash
# 1. Switch back to main branch
git checkout main
git push origin main:feat/unified-apps --force

# 2. Wait for ArgoCD to sync old structure
# Or manually sync in ArgoCD UI

# 3. If PVs are stuck in Released state:
# Use the backup to identify old claim references
kubectl patch pv <pv-name> --type json \
  -p '[{"op": "add", "path": "/spec/claimRef", "value": {"namespace": "<old-ns>", "name": "<old-pvc-name>"}}]'

# 4. Verify old apps come back up
kubectl get applications -n argocd
kubectl get pods -A
```

## Files Changed

### New Files Created
- `scripts/migrate-to-unified-structure.sh` - Main migration script
- `scripts/pre-migration-backup.sh` - Backup script
- `k8s/shared-storage/kustomization.yaml` - Fixed missing file
- All apps now in `k8s/` directory

### Modified Files
- `apps/app-of-apps.yaml` - Now defines 27 individual apps
- `k8s/metallb/kustomization.yaml` - Removed duplicate namespace
- `k8s/traefik/kustomization.yaml` - Removed duplicate namespace

### Deleted Files/Directories
- `media/` - Entire directory
- `core/` - Entire directory
- `security/` - Entire directory
- `monitoring/` - Entire directory
- `manifests/` - Entire directory
- `config/` - Entire directory (shared ConfigMaps removed)

## Apps Requiring PV Rebinding

The following 11 apps have PVCs moving to new namespaces:

| App | Old Namespace | New Namespace | PV Name | Data Path |
|-----|---------------|---------------|---------|-----------|
| jellyfin | media | jellyfin | jellyfin-pv | /opt/jellyfin |
| radarr | media | radarr | radarr-pv | /opt/radarr |
| sonarr | media | sonarr | sonarr-pv | /opt/sonarr |
| bazarr | media | bazarr | bazarr-pv | /opt/bazarr |
| prowlarr | media | prowlarr | prowlarr-pv | /opt/prowlarr |
| qbittorrent | media | qbittorrent | qbittorrent-pv | /opt/qbittorrent |
| sabnzbd | media | sabnzbd | sabnzbd-pv | /opt/sabnzbd |
| cleanuparr | media | cleanuparr | cleanuparr-pv | /opt/cleanuparr |
| huntarr | media | huntarr | huntarr-pv | /opt/huntarr |
| pihole | core | pihole | pihole-pv | /opt/pihole |
| frigate | security | frigate | frigate-pv | /opt/frigate |

**All data paths on your host remain unchanged and are safe!**

## Additional Notes

### Secrets
- VPN secrets moved from `media` namespace to `qbittorrent` and `sabnzbd` namespaces
- You may need to recreate sealed secrets after migration

### ConfigMaps
- Shared `common-env-config` removed
- PUID/PGID/TZ now inline in each deployment
- VPN configs now per-app in `config.yaml` files

### Networking
- Service names updated to be namespace-scoped
- Example: `sabnzbd-proxy.media.svc` → `proxy.sabnzbd.svc`
- Ingress moved into each app directory

### Storage
- Shared PVs (`media-pv`, `downloads-pv`) remain in `k8s/shared-storage/`
- Per-app PVs defined in each app's `storage.yaml`

## Support

If you encounter issues during migration:

1. Check the backup summary: `cat ./pre-migration-backup-*/BACKUP_SUMMARY.txt`
2. Review ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
3. Check this troubleshooting guide above
4. Review the migration script logs

## Post-Migration Cleanup

After successful migration and verification (wait at least 24-48 hours):

```bash
# 1. Delete old namespace resources (if any remain)
kubectl delete namespace media --dry-run=client
kubectl delete namespace core --dry-run=client
# Remove --dry-run=client when ready

# 2. Delete backup (if no longer needed)
rm -rf ./pre-migration-backup-*

# 3. Merge feature branch if not already done
git checkout main
git merge feat/unified-apps
git push origin main
```

## Summary

- ✅ **Data is safe** - All PVs have Retain policy
- ⚠️ **Downtime expected** - 15-20 minutes for full migration
- 🔧 **Manual intervention needed** - PV rebinding requires manual steps
- 📦 **Backup required** - Always run backup script first
- 🧪 **Test recommended** - Try on dev cluster if available

**Good luck with your migration!**
