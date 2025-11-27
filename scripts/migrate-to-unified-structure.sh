#!/usr/bin/env bash
# =============================================================================
# Migration Script: Old Structure → k8s/ Unified Structure
# =============================================================================
# This script helps migrate from the old grouped structure (media/, core/, etc.)
# to the new unified k8s/ structure with individual app namespaces.
#
# IMPORTANT: Review this script and test in a non-production environment first!
#
# Usage:
#   ./migrate-to-unified-structure.sh [--dry-run] [--skip-backup]
#
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
SKIP_BACKUP=false
BACKUP_DIR="./migration-backup-$(date +%Y%m%d-%H%M%S)"

# Apps that need PV rebinding (PVC moves to different namespace)
declare -A PV_MIGRATIONS=(
    ["jellyfin-pv"]="media:jellyfin"
    ["radarr-pv"]="media:radarr"
    ["sonarr-pv"]="media:sonarr"
    ["bazarr-pv"]="media:bazarr"
    ["prowlarr-pv"]="media:prowlarr"
    ["qbittorrent-pv"]="media:qbittorrent"
    ["sabnzbd-pv"]="media:sabnzbd"
    ["cleanuparr-pv"]="media:cleanuparr"
    ["huntarr-pv"]="media:huntarr"
    ["pihole-pv"]="core:pihole"
    ["frigate-pv"]="security:frigate"
)

# ArgoCD apps to disable auto-sync
OLD_APPS=(
    "core-apps"
    "media-apps"
    "security-apps"
    "manifests"
    "monitoring"
)

# =============================================================================
# Helper Functions
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if ArgoCD is installed
    if ! kubectl get namespace argocd &> /dev/null; then
        log_error "ArgoCD namespace not found"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

create_backup() {
    if [[ "$SKIP_BACKUP" == true ]]; then
        log_warning "Skipping backup (--skip-backup flag set)"
        return
    fi
    
    log_info "Creating backup in: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup all PVCs with their namespace
    log_info "Backing up PVCs..."
    for pv in "${!PV_MIGRATIONS[@]}"; do
        local old_ns="${PV_MIGRATIONS[$pv]%%:*}"
        local pvc_name="${pv%-pv}-pvc"
        
        if kubectl get pvc "$pvc_name" -n "$old_ns" &> /dev/null; then
            kubectl get pvc "$pvc_name" -n "$old_ns" -o yaml > "$BACKUP_DIR/${old_ns}-${pvc_name}.yaml"
            log_success "Backed up PVC: $old_ns/$pvc_name"
        fi
    done
    
    # Backup all PVs
    log_info "Backing up PVs..."
    for pv in "${!PV_MIGRATIONS[@]}"; do
        if kubectl get pv "$pv" &> /dev/null; then
            kubectl get pv "$pv" -o yaml > "$BACKUP_DIR/${pv}.yaml"
            log_success "Backed up PV: $pv"
        fi
    done
    
    # Backup all ConfigMaps and Secrets from old namespaces
    log_info "Backing up ConfigMaps and Secrets..."
    for ns in media core security monitoring; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get configmaps -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-configmaps.yaml" 2>/dev/null || true
            kubectl get secrets -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-secrets.yaml" 2>/dev/null || true
            log_success "Backed up ConfigMaps/Secrets from namespace: $ns"
        fi
    done
    
    # Backup ArgoCD Applications
    log_info "Backing up ArgoCD Applications..."
    kubectl get applications -n argocd -o yaml > "$BACKUP_DIR/argocd-applications.yaml"
    
    log_success "Backup completed: $BACKUP_DIR"
}

disable_argocd_autosync() {
    log_info "Disabling auto-sync on old ArgoCD apps..."
    
    for app in "${OLD_APPS[@]}"; do
        if kubectl get application "$app" -n argocd &> /dev/null; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY-RUN] Would disable auto-sync for: $app"
            else
                kubectl patch application "$app" -n argocd \
                    --type merge \
                    -p '{"spec":{"syncPolicy":{"automated":null}}}' || true
                log_success "Disabled auto-sync for: $app"
            fi
        else
            log_warning "Application not found: $app"
        fi
    done
}

wait_for_pv_release() {
    local pv_name=$1
    local timeout=60
    local elapsed=0
    
    log_info "Waiting for PV to be released: $pv_name"
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(kubectl get pv "$pv_name" -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
        
        if [[ "$status" == "Released" ]] || [[ "$status" == "Available" ]]; then
            log_success "PV $pv_name is now: $status"
            return 0
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_warning "Timeout waiting for PV to be released: $pv_name"
    return 1
}

rebind_persistent_volumes() {
    log_info "Starting PV rebinding process..."
    
    for pv in "${!PV_MIGRATIONS[@]}"; do
        local migration="${PV_MIGRATIONS[$pv]}"
        local old_ns="${migration%%:*}"
        local new_ns="${migration##*:}"
        
        log_info "Processing PV: $pv ($old_ns → $new_ns)"
        
        # Check if PV exists
        if ! kubectl get pv "$pv" &> /dev/null; then
            log_warning "PV not found: $pv (might not be created yet)"
            continue
        fi
        
        # Get current PV status
        local pv_status=$(kubectl get pv "$pv" -o jsonpath='{.status.phase}')
        log_info "Current PV status: $pv_status"
        
        if [[ "$pv_status" == "Bound" ]]; then
            local current_claim=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.name}')
            local current_ns=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.namespace}')
            
            if [[ "$current_ns" == "$new_ns" ]]; then
                log_success "PV already bound to new namespace: $pv → $new_ns/$current_claim"
                continue
            fi
            
            log_info "PV currently bound to: $current_ns/$current_claim"
            log_warning "Waiting for old PVC to be deleted..."
            
        elif [[ "$pv_status" == "Released" ]]; then
            log_info "PV is in Released state, clearing claim reference..."
            
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY-RUN] Would clear claimRef for: $pv"
            else
                kubectl patch pv "$pv" --type json -p '[{"op": "remove", "path": "/spec/claimRef"}]'
                log_success "Cleared claimRef for: $pv"
                
                # Wait for PV to become Available
                sleep 2
                local new_status=$(kubectl get pv "$pv" -o jsonpath='{.status.phase}')
                log_success "PV status now: $new_status"
            fi
            
        elif [[ "$pv_status" == "Available" ]]; then
            log_success "PV already available for binding: $pv"
        fi
    done
    
    log_success "PV rebinding process completed"
}

verify_new_apps() {
    log_info "Verifying new ArgoCD applications..."
    
    local apps=(
        "jellyfin" "radarr" "sonarr" "bazarr" "prowlarr" 
        "qbittorrent" "sabnzbd" "cleanuparr" "huntarr"
        "pihole" "frigate" "grafana" "prometheus"
        "jellyseerr" "glance" "notifiarr"
        "traefik" "cert-manager" "metallb" "cloudflare-tunnel"
        "sealed-secrets" "intel-gpu" "kube-state-metrics" "node-exporter"
        "shared-storage" "argocd-apps"
    )
    
    local missing_apps=()
    
    for app in "${apps[@]}"; do
        if kubectl get application "$app" -n argocd &> /dev/null; then
            local sync_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}')
            local health_status=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}')
            log_info "App: $app - Sync: $sync_status, Health: $health_status"
        else
            missing_apps+=("$app")
        fi
    done
    
    if [[ ${#missing_apps[@]} -gt 0 ]]; then
        log_warning "Missing applications: ${missing_apps[*]}"
    else
        log_success "All applications found in ArgoCD"
    fi
}

cleanup_old_apps() {
    log_info "Cleaning up old ArgoCD applications..."
    
    for app in "${OLD_APPS[@]}"; do
        if kubectl get application "$app" -n argocd &> /dev/null; then
            if [[ "$DRY_RUN" == true ]]; then
                log_info "[DRY-RUN] Would delete application: $app"
            else
                read -p "Delete old application '$app'? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    # Remove finalizers to prevent it from deleting resources
                    kubectl patch application "$app" -n argocd \
                        --type json \
                        -p '[{"op": "remove", "path": "/metadata/finalizers"}]' || true
                    
                    kubectl delete application "$app" -n argocd
                    log_success "Deleted application: $app"
                else
                    log_info "Skipped deleting: $app"
                fi
            fi
        fi
    done
}

print_summary() {
    echo ""
    echo "======================================================================="
    log_success "Migration Process Summary"
    echo "======================================================================="
    echo ""
    echo "Next Steps:"
    echo "  1. Update your Git repository to the new structure (merge feature branch)"
    echo "  2. Verify ArgoCD applications are syncing correctly"
    echo "  3. Check that all PVs are bound to new PVCs"
    echo "  4. Verify all applications are healthy"
    echo ""
    echo "Verification commands:"
    echo "  kubectl get applications -n argocd"
    echo "  kubectl get pv"
    echo "  kubectl get pods --all-namespaces"
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""
    echo "======================================================================="
}

# =============================================================================
# Main Script
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                log_info "Running in DRY-RUN mode"
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--dry-run] [--skip-backup]"
                echo ""
                echo "Options:"
                echo "  --dry-run       Show what would be done without making changes"
                echo "  --skip-backup   Skip backup creation (not recommended)"
                echo "  -h, --help      Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    echo "======================================================================="
    echo "  Homelab Migration: Unified k8s/ Structure"
    echo "======================================================================="
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "DRY-RUN MODE: No changes will be made"
    fi
    
    # Run migration steps
    check_prerequisites
    create_backup
    
    echo ""
    log_info "Step 1: Disable auto-sync on old ArgoCD apps"
    disable_argocd_autosync
    
    echo ""
    log_warning "MANUAL STEP REQUIRED:"
    echo "  1. Merge your feature branch to main (or update targetRevision in ArgoCD)"
    echo "  2. ArgoCD will detect the new app-of-apps.yaml with 27 individual apps"
    echo "  3. Wait for old apps to be deleted and new apps to be created"
    echo ""
    read -p "Press ENTER when you've updated Git and ArgoCD has synced the new structure..."
    
    echo ""
    log_info "Step 2: Rebind PersistentVolumes to new namespaces"
    rebind_persistent_volumes
    
    echo ""
    log_info "Step 3: Verify new applications"
    verify_new_apps
    
    echo ""
    log_info "Step 4: Cleanup old applications"
    cleanup_old_apps
    
    print_summary
}

# Run main function
main "$@"
