# Homelab GitOps Repository

This repository contains Kubernetes manifests for a complete homelab media stack managed via ArgoCD GitOps.

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Services Included

### Media Stack (arr-stack)
- **Radarr** - Movie management
- **Sonarr** - TV show management  
- **Bazarr** - Subtitle management
- **Prowlarr** - Indexer management
- **Jellyfin** - Media server
- **Jellyseerr** - Media requests

### Download Clients
- **qBittorrent** - Torrent client
- **SABnzbd** - Usenet client

### Infrastructure
- **Pihole** - DNS adblocking
- **Frigate** - CCTV and object detection

### Utilities
- **Glance** - Modern dashboard with stocks, crypto, and RSS
- **Notifiarr** - Notifications

## Repository Structure

```
├── bootstrap/           # ArgoCD installation
├── core/               # Core infrastructure apps
├── media/              # Media stack applications
├── apps/               # Application definitions
└── manifests/          # Raw Kubernetes manifests
```

## Quick Start

1. Install ArgoCD: `kubectl apply -k bootstrap/`
2. Wait for ArgoCD to be ready
3. Set up secrets (see [SETUP.md](SETUP.md))
4. Apply app-of-apps: `kubectl apply -f apps/`

## Requirements

- k3s/k8s cluster
- Persistent storage (local-path or longhorn)
- Storage paths: `/media` for media files, `/opt/homelab/config` for app configs
- Ingress controller (traefik for k3s)

## Contributing

This project follows [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. See [.conventionalcommits](.conventionalcommits) for details.
