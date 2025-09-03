# Notifiarr Configuration Guide

## Overview
Notifiarr provides Discord notifications and monitoring for your media stack. Configuration is done through the Notifiarr web interface after the applications are running.

## Initial Setup

1. **Get Notifiarr API Key**: 
   - Sign up at [notifiarr.com](https://notifiarr.com)
   - Get your API key from the dashboard

2. **Access Notifiarr Web Interface**:
   - URL: `https://notifiarr.home.coredev.uk` (when ingress is configured)
   - Or port-forward: `kubectl port-forward -n media svc/notifiarr 5454:5454`

## Application Configuration

After your *arr applications are running, configure them in Notifiarr:

### 1. Get API Keys from Applications

```bash
# Sonarr API Key
kubectl exec -n media deployment/sonarr -- cat /config/config.xml | grep -o '<ApiKey>[^<]*' | cut -d'>' -f2

# Radarr API Key  
kubectl exec -n media deployment/radarr -- cat /config/config.xml | grep -o '<ApiKey>[^<]*' | cut -d'>' -f2

# Prowlarr API Key
kubectl exec -n media deployment/prowlarr -- cat /config/config.xml | grep -o '<ApiKey>[^<]*' | cut -d'>' -f2

# Bazarr API Key
kubectl exec -n media deployment/bazarr -- cat /config/config/config.ini | grep -o 'apikey = .*' | cut -d' ' -f3
```

### 2. Application URLs (Internal)

Configure these URLs in Notifiarr:

- **Sonarr**: `http://sonarr.media:8989`
- **Radarr**: `http://radarr.media:7878`  
- **Prowlarr**: `http://prowlarr.media:9696`
- **Bazarr**: `http://bazarr.media:6767`
- **qBittorrent**: `http://qbittorrent.downloads:8080`
- **SABnzbd**: `http://sabnzbd.downloads:8080`

### 3. Downloader Credentials

For qBittorrent and SABnzbd, you'll need to set up authentication in those applications first, then use those credentials in Notifiarr.

## System Monitoring

Notifiarr includes system monitoring capabilities:
- **Drive Health**: Uses `smartctl` (enabled with privileged mode)
- **System Stats**: CPU, memory, disk usage
- **Process Monitoring**: Application health checks

## Features Enabled

- ✅ **System monitoring** with host filesystem access
- ✅ **Drive health monitoring** with smartctl
- ✅ **User session tracking** via /var/run/utmp
- ✅ **Privileged mode** for hardware access
- ✅ **Persistent config** via Longhorn storage

## Next Steps

1. Configure your applications in Notifiarr web interface
2. Set up Discord webhooks and notifications
3. Enable system monitoring features on the website
4. Test notifications and health checks