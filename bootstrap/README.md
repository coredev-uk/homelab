# ArgoCD Bootstrap

This directory contains the necessary files to bootstrap ArgoCD in a declarative
way.

## Prerequisites

1. A running k3s cluster
2. kubectl installed and configured
3. Cloudflare API token (for cert-manager)

## Installation Steps

1. First, install cert-manager (required for SSL certificates):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
```

2. Create Cloudflare API token secret:

```bash
kubectl create namespace cert-manager
kubectl create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=your-token-here \
  -n cert-manager
```

3. Apply the ArgoCD bootstrap configuration:

```bash
kubectl apply -k .
```

4. Wait for all pods to be ready:

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

5. Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

6. Access ArgoCD UI:

- Navigate to https://argocd.lab.coredev.uk
- Login with username: admin and the password from step 5

## Post-Installation

1. Apply the root application to bootstrap the rest of your infrastructure:

```bash
kubectl apply -f ../apps.yaml
```

2. ArgoCD will now manage the deployment of all other applications defined in
   your GitOps repository.

## Configuration

The bootstrap configuration includes:

- ArgoCD installation with custom configurations
- RBAC settings for admin access
- Ingress configuration with SSL
- High availability settings

## Notes

- The ArgoCD server is configured to use HTTPS with certificates from Let's
  Encrypt
- RBAC is configured with a default readonly policy and an org-admin role
- The server is exposed via Traefik IngressRoute
