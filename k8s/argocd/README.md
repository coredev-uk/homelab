# ArgoCD

This directory contains supplementary configurations for ArgoCD.

## Deployment

ArgoCD itself is deployed via the bootstrap process (see `bootstrap/kustomization.yaml`).

This directory contains additional resources:
- **ingress.yaml** - IngressRoute for ArgoCD UI access
- **certificate.yaml** - TLS certificate via cert-manager
- **middleware.yaml** - HTTPS redirect middleware

## ArgoCD Namespace

The `argocd` namespace is created by the bootstrap installation.

## Access

- **URL**: https://argocd.home.coredev.uk
- **TLS**: Managed by cert-manager with Let's Encrypt
- **Ingress**: Traefik IngressRoute
