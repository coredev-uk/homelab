# Cleanup Report - Unused Files

## 🔍 Analysis Complete

All files have been scanned for unused ArgoCD leftovers and orphaned configurations.

## 🗑️ Files/Directories to Remove

### 1. **`k8s/media/` directory** - EMPTY & UNUSED
```bash
k8s/media/
├── bazarr/app/          # Empty directory
├── huntarr/app/         # Empty directory  
├── jellyseerr/app/      # Empty directory
├── notifiarr/app/       # Empty directory
├── prowlarr/app/        # Empty directory
├── radarr/app/          # Empty directory
└── sonarr/app/          # Empty directory
```

**Status**: Contains only empty subdirectories, not referenced anywhere  
**Safe to delete**: ✅ Yes

### 2. **`secrets/sealed-secrets/` directory** - EMPTY
```bash
secrets/sealed-secrets/  # Empty directory (old sealed-secrets location)
```

**Status**: Empty, replaced by SOPS  
**Safe to delete**: ✅ Yes

### 3. **`secrets/secrets.env` file** - PLAINTEXT SECRETS
```bash
secrets/secrets.env      # 5.4KB plaintext passwords
```

**Status**: Contains unencrypted passwords/tokens, migrated to SOPS  
**Action required**: ⚠️ Backup to password manager THEN delete

## ✅ All Apps Verified

All 24 apps in `k8s/` have corresponding `flux.yaml` files and are properly referenced in Flux:

```
✅ authelia          ✅ bazarr            ✅ cert-manager
✅ cleanuparr        ✅ cloudflare-tunnel ✅ frigate
✅ glance            ✅ homebridge        ✅ huntarr
✅ intel-gpu         ✅ jellyfin          ✅ jellyseerr
✅ kube-prometheus-stack  ✅ longhorn     ✅ metallb
✅ notifiarr         ✅ pihole            ✅ prowlarr
✅ qbittorrent       ✅ radarr            ✅ sabnzbd
✅ shared-storage    ✅ sonarr            ✅ traefik
```

## 🔍 No ArgoCD Leftovers Found

- ✅ No `apps/` directory
- ✅ No `bootstrap/` directory  
- ✅ No ArgoCD Application CRDs
- ✅ No ArgoCD-specific configurations

## 📋 Root Files - All Valid

All root configuration files are in use:

```
✅ .commitlintrc.json       # Commit message linting
✅ .conventionalcommits     # Conventional commits spec
✅ .gitignore               # Git ignore rules
✅ .sops.yaml               # SOPS encryption config
✅ LICENSE                  # Repository license
✅ README.md                # Main documentation
✅ renovate.json            # Renovate bot config
✅ SECRETS_MIGRATION.md     # Migration guide (new)
```

## 🧹 Cleanup Commands

Run these commands to clean up unused files:

```bash
# 1. Remove empty media directory
rm -rf k8s/media/

# 2. Remove empty sealed-secrets directory  
rm -rf secrets/sealed-secrets/

# 3. Backup and remove plaintext secrets (AFTER migrating to SOPS!)
# IMPORTANT: Only do this after encrypting secrets with SOPS
# cp secrets/secrets.env ~/backup-secrets.env  # Backup first!
# rm secrets/secrets.env

# 4. Commit cleanup
git add k8s/ secrets/
git commit -m "chore: remove unused directories and old secrets"
git push
```

## ⚠️ Important Notes

1. **DO NOT** delete `secrets/secrets.env` until AFTER:
   - You've encrypted all secrets with SOPS
   - Verified they work in the cluster
   - Backed up the file securely

2. The `k8s/media/` directory is completely empty and safe to delete immediately

3. All 24 Kubernetes apps are properly configured with Flux

## 📊 Storage Savings

Removing these files will clean up:
- ~5.4 KB from `secrets/secrets.env` (once migrated)
- Empty directories taking up inode space

---

**Generated**: 2026-01-03
