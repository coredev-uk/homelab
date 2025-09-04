#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo -e "${BLUE}"
echo "🏠 Homelab Deployment Validator"
echo "================================"
echo -e "${NC}"

# Test 1: Cluster connectivity
log_step "Testing cluster connectivity..."
if kubectl cluster-info >/dev/null 2>&1; then
    log_info "✅ Cluster is accessible"
else
    log_error "❌ Cannot connect to cluster"
    exit 1
fi

# Test 2: ArgoCD deployment
log_step "Checking ArgoCD deployment..."
if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
    ARGOCD_READY=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}')
    if [ "$ARGOCD_READY" = "1" ]; then
        log_info "✅ ArgoCD is running"
        ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Not found")
        log_info "   Password: $ARGOCD_PASSWORD"
    else
        log_warn "⚠️  ArgoCD deployment exists but not ready"
    fi
else
    log_error "❌ ArgoCD not deployed"
fi

# Test 3: Longhorn CRDs
log_step "Checking Longhorn CRDs..."
REQUIRED_CRDS=("engineimages.longhorn.io" "nodes.longhorn.io" "volumes.longhorn.io")
MISSING_CRDS=()

for crd in "${REQUIRED_CRDS[@]}"; do
    if kubectl get crd "$crd" >/dev/null 2>&1; then
        log_info "✅ CRD $crd exists"
    else
        log_error "❌ Missing CRD: $crd"
        MISSING_CRDS+=("$crd")
    fi
done

# Test 4: Longhorn deployment
log_step "Checking Longhorn deployment..."
if kubectl get deployment longhorn-ui -n longhorn-system >/dev/null 2>&1; then
    CSI_READY=$(kubectl get daemonset longhorn-csi-plugin -n longhorn-system -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    if [ "$CSI_READY" -gt 0 ]; then
        log_info "✅ Longhorn CSI driver is ready"
    else
        log_warn "⚠️  Longhorn CSI driver not ready"
    fi
    
    # Check replica count setting
    REPLICA_COUNT=$(kubectl get settings.longhorn.io default-replica-count -n longhorn-system -o jsonpath='{.value}' 2>/dev/null || echo "3")
    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    if [ "$NODE_COUNT" -eq 1 ] && [ "$REPLICA_COUNT" -eq 1 ]; then
        log_info "✅ Replica count correctly set for single-node ($REPLICA_COUNT)"
    elif [ "$NODE_COUNT" -eq 1 ] && [ "$REPLICA_COUNT" -ne 1 ]; then
        log_warn "⚠️  Single node but replica count is $REPLICA_COUNT (should be 1)"
        log_info "   Run: ./scripts/fix-longhorn-single-node.sh"
    else
        log_info "✅ Replica count: $REPLICA_COUNT for $NODE_COUNT nodes"
    fi
else
    log_error "❌ Longhorn not deployed"
fi

# Test 5: PVC binding
log_step "Checking PVC binding..."
PENDING_PVCS=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -c "Pending" || echo "0")
BOUND_PVCS=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -c "Bound" || echo "0")

if [ "$PENDING_PVCS" -eq 0 ] && [ "$BOUND_PVCS" -gt 0 ]; then
    log_info "✅ All PVCs are bound ($BOUND_PVCS total)"
elif [ "$PENDING_PVCS" -gt 0 ]; then
    log_warn "⚠️  $PENDING_PVCS PVCs are pending, $BOUND_PVCS are bound"
    kubectl get pvc -A | grep Pending | head -3
else
    log_info "ℹ️  No PVCs found"
fi

# Test 6: Core services
log_step "Checking core services..."
CORE_SERVICES=("pihole" "cert-manager" "traefik")
for service in "${CORE_SERVICES[@]}"; do
    RUNNING_PODS=$(kubectl get pods -A -l app="$service" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [ "$RUNNING_PODS" -gt 0 ]; then
        log_info "✅ $service: $RUNNING_PODS pod(s) running"
    else
        log_warn "⚠️  $service: No running pods found"
    fi
done

# Test 7: ArgoCD applications
log_step "Checking ArgoCD applications..."
if kubectl get applications -n argocd >/dev/null 2>&1; then
    SYNCED_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | grep -c "Synced" || echo "0")
    TOTAL_APPS=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l || echo "0")
    log_info "✅ ArgoCD applications: $SYNCED_APPS/$TOTAL_APPS synced"
    
    if [ "$SYNCED_APPS" -lt "$TOTAL_APPS" ]; then
        log_info "Applications status:"
        kubectl get applications -n argocd --no-headers | awk '{print "   " $1 ": " $2 " / " $3}'
    fi
else
    log_warn "⚠️  No ArgoCD applications found"
fi

# Summary
echo ""
log_step "Deployment Summary"
TOTAL_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l || echo "0")
RUNNING_PODS=$(kubectl get pods -A --no-headers 2>/dev/null | grep -c "Running\|Completed" || echo "0")
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)

echo "Cluster: $NODE_COUNT node(s)"
echo "Pods: $RUNNING_PODS/$TOTAL_PODS running"
echo "Storage: Longhorn with $REPLICA_COUNT replica(s)"

if [ ${#MISSING_CRDS[@]} -eq 0 ] && [ "$PENDING_PVCS" -eq 0 ] && [ "$RUNNING_PODS" -gt 30 ]; then
    echo -e "${GREEN}🎉 Deployment appears successful!${NC}"
    echo ""
    echo "Access URLs (add to /etc/hosts):"
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    echo "$NODE_IP argocd.local pihole.local jellyfin.local longhorn.local"
else
    echo -e "${YELLOW}⚠️  Deployment needs attention${NC}"
    if [ ${#MISSING_CRDS[@]} -gt 0 ]; then
        echo "Missing CRDs: ${MISSING_CRDS[*]}"
    fi
    if [ "$PENDING_PVCS" -gt 0 ]; then
        echo "Pending PVCs: $PENDING_PVCS"
    fi
fi