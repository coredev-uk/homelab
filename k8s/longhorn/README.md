# Longhorn Storage

This directory contains additional configurations for Longhorn distributed block storage.

## Deployment

Longhorn itself is deployed as a Helm chart via ArgoCD (see `apps/app-of-apps.yaml`).

This directory only contains supplementary resources:
- Ingress for Longhorn UI access

The Helm chart is deployed to the `longhorn-system` namespace and manages:
- Storage provisioning
- Volume management
- Snapshots and backups
- UI dashboard
