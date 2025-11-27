#!/usr/bin/env bash
# =============================================================================
# Pre-Migration Backup Script
# =============================================================================
# Creates a comprehensive backup of your cluster state before migration.
# This script is READ-ONLY and makes NO changes to your cluster.
#
# Usage:
#   ./pre-migration-backup.sh [backup-dir]
#
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BACKUP_DIR="${1:-./pre-migration-backup-$(date +%Y%m%d-%H%M%S)}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_cluster_connection() {
    log_info "Checking cluster connection..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    local context=$(kubectl config current-context)
    log_info "Connected to cluster context: $context"
    
    read -p "Is this the correct cluster? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_error "Backup cancelled by user"
        exit 1
    fi
}

create_backup_structure() {
    log_info "Creating backup directory: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"/{namespaces,pvs,pvcs,configmaps,secrets,argocd,deployments}
}

backup_namespaces() {
    log_info "Backing up namespaces..."
    
    local namespaces=(
        "media"
        "core"
        "security"
        "monitoring"
        "argocd"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get namespace "$ns" -o yaml > "$BACKUP_DIR/namespaces/${ns}.yaml"
            log_success "Backed up namespace: $ns"
        else
            log_info "Namespace not found (may not exist yet): $ns"
        fi
    done
}

backup_persistent_volumes() {
    log_info "Backing up PersistentVolumes..."
    
    kubectl get pv -o yaml > "$BACKUP_DIR/pvs/all-pvs.yaml"
    
    # Backup each PV individually
    kubectl get pv --no-headers -o custom-columns=":metadata.name" | while read pv; do
        kubectl get pv "$pv" -o yaml > "$BACKUP_DIR/pvs/${pv}.yaml"
        
        # Get PV details
        local phase=$(kubectl get pv "$pv" -o jsonpath='{.status.phase}')
        local capacity=$(kubectl get pv "$pv" -o jsonpath='{.spec.capacity.storage}')
        local claim=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || echo "none")
        local ns=$(kubectl get pv "$pv" -o jsonpath='{.spec.claimRef.namespace}' 2>/dev/null || echo "none")
        
        echo "$pv,$phase,$capacity,$ns/$claim" >> "$BACKUP_DIR/pvs/pv-status.csv"
        log_success "Backed up PV: $pv (Phase: $phase, Claim: $ns/$claim)"
    done
}

backup_persistent_volume_claims() {
    log_info "Backing up PersistentVolumeClaims..."
    
    local namespaces=(
        "media"
        "core"
        "security"
        "monitoring"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get pvc -n "$ns" -o yaml > "$BACKUP_DIR/pvcs/${ns}-pvcs.yaml" 2>/dev/null || true
            
            kubectl get pvc -n "$ns" --no-headers -o custom-columns=":metadata.name" 2>/dev/null | while read pvc; do
                kubectl get pvc "$pvc" -n "$ns" -o yaml > "$BACKUP_DIR/pvcs/${ns}-${pvc}.yaml"
                local phase=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.status.phase}')
                local volume=$(kubectl get pvc "$pvc" -n "$ns" -o jsonpath='{.spec.volumeName}')
                log_success "Backed up PVC: $ns/$pvc (Phase: $phase, Volume: $volume)"
            done
        fi
    done
}

backup_configmaps() {
    log_info "Backing up ConfigMaps..."
    
    local namespaces=(
        "media"
        "core"
        "security"
        "monitoring"
        "argocd"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get configmaps -n "$ns" -o yaml > "$BACKUP_DIR/configmaps/${ns}-configmaps.yaml" 2>/dev/null || true
            log_success "Backed up ConfigMaps from: $ns"
        fi
    done
}

backup_secrets() {
    log_info "Backing up Secrets..."
    
    local namespaces=(
        "media"
        "core"
        "security"
        "monitoring"
        "argocd"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get secrets -n "$ns" -o yaml > "$BACKUP_DIR/secrets/${ns}-secrets.yaml" 2>/dev/null || true
            log_success "Backed up Secrets from: $ns"
        fi
    done
}

backup_argocd_applications() {
    log_info "Backing up ArgoCD Applications..."
    
    if kubectl get namespace argocd &> /dev/null; then
        kubectl get applications -n argocd -o yaml > "$BACKUP_DIR/argocd/all-applications.yaml"
        
        kubectl get applications -n argocd --no-headers -o custom-columns=":metadata.name" | while read app; do
            kubectl get application "$app" -n argocd -o yaml > "$BACKUP_DIR/argocd/${app}.yaml"
            
            local sync=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "unknown")
            local health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "unknown")
            
            echo "$app,$sync,$health" >> "$BACKUP_DIR/argocd/app-status.csv"
            log_success "Backed up ArgoCD app: $app (Sync: $sync, Health: $health)"
        done
    fi
}

backup_deployments() {
    log_info "Backing up Deployments..."
    
    local namespaces=(
        "media"
        "core"
        "security"
        "monitoring"
    )
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            kubectl get deployments -n "$ns" -o yaml > "$BACKUP_DIR/deployments/${ns}-deployments.yaml" 2>/dev/null || true
            log_success "Backed up Deployments from: $ns"
        fi
    done
}

create_summary() {
    log_info "Creating backup summary..."
    
    cat > "$BACKUP_DIR/BACKUP_SUMMARY.txt" <<EOF
================================================================================
Pre-Migration Backup Summary
================================================================================
Backup Date: $(date)
Cluster Context: $(kubectl config current-context)
Kubernetes Version: $(kubectl version --short 2>/dev/null | grep Server || echo "unknown")

================================================================================
Backup Contents
================================================================================

Namespaces: $(find "$BACKUP_DIR/namespaces" -type f | wc -l) files
PersistentVolumes: $(find "$BACKUP_DIR/pvs" -type f -name "*.yaml" | wc -l) files
PersistentVolumeClaims: $(find "$BACKUP_DIR/pvcs" -type f | wc -l) files
ConfigMaps: $(find "$BACKUP_DIR/configmaps" -type f | wc -l) files
Secrets: $(find "$BACKUP_DIR/secrets" -type f | wc -l) files
ArgoCD Applications: $(find "$BACKUP_DIR/argocd" -type f -name "*.yaml" | wc -l) files
Deployments: $(find "$BACKUP_DIR/deployments" -type f | wc -l) files

================================================================================
PersistentVolume Status
================================================================================
EOF
    
    if [[ -f "$BACKUP_DIR/pvs/pv-status.csv" ]]; then
        echo "" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
        echo "PV_NAME,PHASE,CAPACITY,CLAIM" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
        cat "$BACKUP_DIR/pvs/pv-status.csv" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
    fi
    
    cat >> "$BACKUP_DIR/BACKUP_SUMMARY.txt" <<EOF

================================================================================
ArgoCD Application Status
================================================================================
EOF
    
    if [[ -f "$BACKUP_DIR/argocd/app-status.csv" ]]; then
        echo "" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
        echo "APP_NAME,SYNC_STATUS,HEALTH_STATUS" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
        cat "$BACKUP_DIR/argocd/app-status.csv" >> "$BACKUP_DIR/BACKUP_SUMMARY.txt"
    fi
    
    cat >> "$BACKUP_DIR/BACKUP_SUMMARY.txt" <<EOF

================================================================================
Restore Information
================================================================================

To restore a specific resource:
  kubectl apply -f <backup-file>

To restore an entire namespace:
  kubectl apply -f $BACKUP_DIR/configmaps/<namespace>-configmaps.yaml
  kubectl apply -f $BACKUP_DIR/secrets/<namespace>-secrets.yaml
  kubectl apply -f $BACKUP_DIR/pvcs/<namespace>-pvcs.yaml
  kubectl apply -f $BACKUP_DIR/deployments/<namespace>-deployments.yaml

IMPORTANT: This backup is for reference and emergency recovery only.
The migration script will handle most of the migration process automatically.

================================================================================
EOF
}

main() {
    echo "======================================================================="
    echo "  Pre-Migration Backup Script"
    echo "======================================================================="
    echo ""
    
    check_cluster_connection
    create_backup_structure
    
    backup_namespaces
    backup_persistent_volumes
    backup_persistent_volume_claims
    backup_configmaps
    backup_secrets
    backup_argocd_applications
    backup_deployments
    
    create_summary
    
    echo ""
    echo "======================================================================="
    log_success "Backup completed successfully!"
    echo "======================================================================="
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""
    echo "Summary file: $BACKUP_DIR/BACKUP_SUMMARY.txt"
    echo ""
    log_info "Review the summary file for details about your cluster state"
    echo ""
}

main
