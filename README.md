<div align="center">

# Core's Kubernetes Homelab
═══════════════════════════

</div>

A personal Kubernetes homelab configuration using ArgoCD for GitOps deployment of a complete media automation stack, DNS services, storage management, and monitoring tools. This setup includes the popular *arr media management suite, torrent/usenet clients with VPN integration, and essential infrastructure services.

**Note:** This configuration is tailored for my specific environment and setup. You can fork this repository and modify the configurations to work with your own infrastructure.

## Quick Start

See [SETUP.md](SETUP.md) for detailed setup instructions.

## Structure

```
├── apps/                    # ArgoCD application definitions
├── bootstrap/               # ArgoCD installation and initial setup
├── core/                    # Core infrastructure services
├── manifests/               # Shared Kubernetes manifests
├── media/                   # Media automation stack
├── monitoring/              # Observability stack
├── secrets/                 # Sealed secrets configuration
└── tunnelled/               # VPN-routed services
```

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)
