#!/bin/bash
set -e

echo "🏠 Homelab Deployment Script"
echo "=============================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Pre-deployment checks
log_info "Running pre-deployment checks..."

# Check if kubectl is working
if ! kubectl cluster-info >/dev/null 2>&1; then
    log_error "kubectl is not configured or cluster is not accessible"
    exit 1
fi

# Check node count for replica configuration
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
log_info "Detected $NODE_COUNT node(s) in cluster"

# Step 1: Bootstrap ArgoCD
log_info "Deploying ArgoCD bootstrap..."
kubectl apply -k bootstrap/

log_info "Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Step 2: Deploy sealed-secrets controller
log_info "Deploying sealed-secrets controller..."
kubectl apply -k core/sealed-secrets/
kubectl wait --for=condition=available --timeout=300s deployment/sealed-secrets-controller -n sealed-secrets

# Step 3: Generate and apply secrets (if not already done)
if [ -f "secrets/secrets.env" ]; then
    log_info "Generating sealed secrets..."
    cd secrets
    if command -v kubeseal >/dev/null 2>&1; then
        ./generate-sealed-secrets.sh
    else
        log_info "Using nix-shell for kubeseal..."
        nix-shell -p kubeseal --run "./generate-sealed-secrets.sh"
    fi
    cd ..
else
    log_warn "secrets/secrets.env not found - you'll need to configure secrets manually"
fi

# Step 4: Deploy applications
log_info "Deploying ArgoCD applications..."
kubectl apply -f apps/app-of-apps.yaml

# Wait for namespaces to be created
log_info "Waiting for namespaces to be created..."
sleep 30
while ! kubectl get namespace dns >/dev/null 2>&1; do
    log_info "Waiting for namespaces..."
    sleep 10
done

# Step 5: Apply sealed secrets
if [ -d "secrets/sealed-secrets" ]; then
    log_info "Applying sealed secrets..."
    kubectl apply -f secrets/sealed-secrets/
fi

# Step 6: Wait for Longhorn to be ready and configure
log_info "Waiting for Longhorn deployment to be ready..."
sleep 60

log_info "Waiting for Longhorn manager to be available..."
kubectl wait --for=condition=available --timeout=300s deployment/longhorn-manager -n longhorn-system || true

log_info "Waiting for Longhorn CRDs to be established..."
kubectl wait --for condition=established --timeout=300s crd/engineimages.longhorn.io || true
kubectl wait --for condition=established --timeout=300s crd/nodes.longhorn.io || true

# Configure replica count based on node count
if [ $NODE_COUNT -eq 1 ]; then
    log_info "Single node detected - configuring Longhorn for 1 replica..."
    sleep 30
    kubectl patch settings.longhorn.io default-replica-count -n longhorn-system --type='merge' -p='{"value": "1"}' 2>/dev/null || true
    log_info "Note: When adding more nodes, increase replica count for better redundancy"
else
    log_info "Multi-node cluster detected ($NODE_COUNT nodes) - using default replica count"
fi

# Step 7: Wait for key components to be ready
log_info "Waiting for core components to be ready..."
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s || true
kubectl wait --for=condition=ready pod -l app=longhorn-csi-plugin -n longhorn-system --timeout=300s || true

# Step 8: Get ArgoCD password
log_info "Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Final status check
log_info "Checking deployment status..."
RUNNING_PODS=$(kubectl get pods -A --no-headers | grep -c "Running\|Completed")
TOTAL_PODS=$(kubectl get pods -A --no-headers | wc -l)

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo "ArgoCD URL: http://argocd.local"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "Status: $RUNNING_PODS/$TOTAL_PODS pods running"
echo ""
echo "📝 Next Steps:"
echo "1. Add to /etc/hosts: <your-node-ip> argocd.local pihole.local jellyfin.local"
echo "2. Access ArgoCD to monitor deployments"
echo "3. Configure Pihole as your DNS server for network-wide ad blocking"
if [ $NODE_COUNT -eq 1 ]; then
    echo "4. When adding more nodes, consider increasing Longhorn replica count:"
    echo "   kubectl patch settings.longhorn.io default-replica-count -n longhorn-system --type='merge' -p='{\"value\": \"3\"}'"
fi