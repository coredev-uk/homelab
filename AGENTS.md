# Agent Tools Configuration

This document provides coding guidelines and available tools for this homelab GitOps repository.

## Build/Test/Lint Commands

- **Validate YAML**: `kubectl apply --dry-run=client -k .` (validate Kubernetes manifests)
- **Test deployment**: `kubectl apply --dry-run=server -k <directory>` (server-side validation)
- **Lint commits**: `npx commitlint --from HEAD~1` (if commitlint installed)
- **Generate secrets**: `cd secrets && ./generate-sealed-secrets.sh` (create sealed secrets)
- **Deploy changes**: Commit and push to trigger ArgoCD sync (preferred over direct kubectl)

## Code Style Guidelines

- **YAML**: 2-space indentation, lowercase keys, no trailing spaces
- **Naming**: Use kebab-case for resource names, lowercase for namespaces
- **Labels**: Always include `app` label, use descriptive values
- **Comments**: Include purpose/context for complex configurations
- **Secrets**: Use SealedSecrets, never commit plaintext secrets
- **GitOps**: Prefer git commits over direct kubectl for changes (ArgoCD auto-syncs)
- **Commits**: Follow conventional commits (feat/fix/docs/chore) with scopes (media/core/infra)

## Available Agents

### `/homelab-deploy`
Deploy or update homelab services using GitOps workflow.

**Usage:** `/homelab-deploy [service-name]`

**Examples:**
- `/homelab-deploy` - Deploy all services via ArgoCD app-of-apps
- `/homelab-deploy media` - Deploy only media stack applications
- `/homelab-deploy core` - Deploy only core infrastructure

**What it does:**
1. Validates Kubernetes cluster connectivity
2. Applies the specified kustomization or app-of-apps configuration
3. Monitors ArgoCD application sync status
4. Reports deployment status and any issues

### `/homelab-status`
Check the health and status of homelab services.

**Usage:** `/homelab-status [service-name]`

**Examples:**
- `/homelab-status` - Check status of all services
- `/homelab-status jellyfin` - Check specific service status
- `/homelab-status argocd` - Check ArgoCD health

**What it does:**
1. Queries ArgoCD for application sync status
2. Checks Kubernetes pod health and readiness
3. Validates ingress and service connectivity
4. Reports resource usage and storage status

### `/homelab-secrets`
Manage sealed secrets for the homelab environment.

**Usage:** `/homelab-secrets [action] [secret-name]`

**Examples:**
- `/homelab-secrets generate` - Generate new sealed secrets from secrets.env
- `/homelab-secrets validate qbittorrent` - Validate specific service secrets
- `/homelab-secrets list` - List all sealed secrets

**What it does:**
1. Uses kubeseal to encrypt secrets
2. Validates secret format and required fields
3. Applies sealed secrets to the cluster
4. Verifies secret availability to applications

### `/homelab-backup`
Manage backups of persistent volumes and configurations.

**Usage:** `/homelab-backup [action] [service]`

**Examples:**
- `/homelab-backup create` - Create backup of all persistent data
- `/homelab-backup restore sonarr` - Restore specific service data
- `/homelab-backup list` - List available backups

**What it does:**
1. Creates snapshots of persistent volumes
2. Backs up application configurations
3. Manages backup retention policies
4. Handles restore operations with validation

### `/homelab-update`
Update application versions and dependencies.

**Usage:** `/homelab-update [service] [version]`

**Examples:**
- `/homelab-update` - Update all services to latest versions
- `/homelab-update jellyfin latest` - Update specific service
- `/homelab-update check` - Check for available updates

**What it does:**
1. Checks current vs available versions
2. Updates image tags in deployment manifests
3. Validates compatibility and breaking changes
4. Commits changes following conventional commits

## Service Categories

### Core Infrastructure
- `argocd` - GitOps controller
- `cert-manager` - TLS certificate management
- `metallb` - Load balancer
- `traefik` - Ingress controller
- `sealed-secrets` - Secret management
- `pihole` - DNS and ad blocking

### Media Stack
- `radarr` - Movie management
- `sonarr` - TV show management
- `bazarr` - Subtitle management
- `prowlarr` - Indexer management
- `jellyfin` - Media server
- `jellyseerr` - Media requests
- `qbittorrent` - Torrent client
- `sabnzbd` - Usenet client

### Monitoring
- `prometheus` - Metrics collection
- `grafana` - Metrics visualization
- `node-exporter` - System metrics

### Utilities
- `glance` - Dashboard
- `notifiarr` - Notifications
- `frigate` - CCTV and object detection

## Common Workflows

### Initial Setup
```bash
/homelab-deploy bootstrap  # Install ArgoCD
/homelab-secrets generate  # Create sealed secrets
/homelab-deploy           # Deploy all applications
/homelab-status           # Verify deployment
```

### Service Update
```bash
/homelab-update check jellyfin  # Check for updates
/homelab-update jellyfin latest # Update to latest
/homelab-status jellyfin        # Verify update
```

### Troubleshooting
```bash
/homelab-status service-name    # Check service health
/homelab-deploy service-name    # Redeploy if needed
/homelab-secrets validate       # Check secret issues
```

## Requirements

- `kubectl` configured for your cluster
- `kubeseal` for sealed secrets management
- ArgoCD CLI (`argocd`) for advanced operations
- Git access for committing configuration changes

## Notes

- All commands follow GitOps principles - changes are committed to git
- Secrets are encrypted using sealed-secrets before storage
- Commands validate cluster state before making changes
- Backup operations should be run before major updates