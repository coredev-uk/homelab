# Homebridge

HomeKit bridge for smart home devices.

## Important Notes

### Network Requirements

**CRITICAL**: Homebridge requires `hostNetwork: true` to function properly with HomeKit. This is because:

- HomeKit uses mDNS (Bonjour) for device discovery
- mDNS requires multicast DNS packets on the local network
- Standard Kubernetes networking cannot support mDNS multicast

**Implications**:
- The pod runs directly on the host network namespace
- Port 8581 (UI) and 51826 (HomeKit) are exposed directly on the host
- Only ONE pod can run per node (cannot scale replicas)
- Standard Kubernetes Service abstraction doesn't apply to HomeKit traffic (port 51826)
- Consider using `nodeSelector` to pin to a specific node

### Replica Count

**MUST BE 1** - Do not increase replicas. Multiple instances will:
- Conflict on port binding (with hostNetwork)
- Create mDNS conflicts
- Break HomeKit pairing state

### Storage

The `/homebridge` directory contains critical data:
- `config.json` - Main configuration
- `persist/` - **CRITICAL** - Contains HomeKit pairing credentials

**WARNING**: Loss of the `persist/` directory will break your HomeKit Home and require re-pairing all devices.

### Accessing the UI

**Internal Access** (from within cluster):
```
http://homebridge.homebridge.svc.cluster.local:8581
```

**External Access** (via Ingress):
```
https://homebridge.home.coredev.uk
```

**Direct Host Access**:
```
http://<node-ip>:8581
```

Default credentials:
- Username: `admin`
- Password: `admin`

**Change these immediately after first login!**

### HomeKit Pairing

iOS devices must be able to reach the host node's IP on port 51826. Ensure:
- Your iOS device is on the same network as the Kubernetes node
- Firewall allows traffic to port 51826/TCP
- mDNS traffic is not blocked (port 5353/UDP)

### Configuration

The initial `config.json` will be created automatically on first run. You can:
1. Use the Web UI at port 8581 to configure (recommended)
2. Manually edit `/opt/homebridge/config.json` on the host
3. Use `kubectl exec` to edit in the pod

### Plugins

Install plugins via the Web UI:
1. Navigate to the Plugins tab
2. Search for desired plugin
3. Click Install

Plugins are stored in the persistent volume and survive pod restarts.

### Troubleshooting

**Check logs**:
```bash
kubectl logs -f deployment/homebridge -n homebridge
```

**Common Issues**:

1. **HomeKit device not found**:
   - Ensure iOS device is on same network as node
   - Check mDNS is working: `avahi-browse -rt _hap._tcp`
   - Verify hostNetwork is enabled

2. **UI not accessible**:
   - Check pod is running: `kubectl get pods -n homebridge`
   - Verify port 8581 is not blocked by firewall
   - Check readiness probe: `kubectl describe pod -n homebridge`

3. **Plugins not working**:
   - Check plugin logs in UI
   - Some plugins may need additional system packages
   - Consider using startup.sh for custom dependencies

### Backup

**CRITICAL FILES TO BACKUP**:
```bash
/opt/homebridge/config.json
/opt/homebridge/persist/
```

To backup:
```bash
kubectl exec -n homebridge deployment/homebridge -- tar czf - /homebridge/persist /homebridge/config.json > homebridge-backup.tar.gz
```

To restore:
```bash
kubectl exec -n homebridge deployment/homebridge -i -- tar xzf - -C / < homebridge-backup.tar.gz
kubectl rollout restart deployment/homebridge -n homebridge
```

### Security Considerations

- The container runs with host networking (reduced isolation)
- Default UI credentials should be changed immediately
- Consider using `nodeSelector` to isolate to a specific node
- Web UI has no built-in authentication beyond basic auth
- Consider placing behind VPN or additional authentication layer

### Resources

- Official Documentation: https://github.com/homebridge/homebridge/wiki
- Docker Image: https://github.com/homebridge/docker-homebridge
- Plugin Directory: https://www.npmjs.com/search?q=homebridge-plugin
- Community Discord: https://discord.gg/homebridge

## Deployment

**Pre-requisites**:
1. Create the host directory:
   ```bash
   sudo mkdir -p /opt/homebridge
   sudo chown -R 1000:1000 /opt/homebridge  # Adjust if needed
   ```

2. (Optional) Label a specific node for Homebridge:
   ```bash
   kubectl label node <node-name> homebridge=true
   ```
   Then uncomment the `nodeSelector` in deployment.yaml

**Deploy**:
```bash
kubectl apply -k k8s/homebridge/
```

**Verify**:
```bash
kubectl get pods -n homebridge
kubectl logs -f deployment/homebridge -n homebridge
```

**Access UI**:
Open https://homebridge.home.coredev.uk (or http://<node-ip>:8581)

## Maintenance

**View logs**:
```bash
kubectl logs -f deployment/homebridge -n homebridge
```

**Restart Homebridge**:
```bash
kubectl rollout restart deployment/homebridge -n homebridge
```

**Update to latest version**:
```bash
kubectl set image deployment/homebridge homebridge=homebridge/homebridge:latest -n homebridge
```

Or edit deployment.yaml and update the image tag, then:
```bash
kubectl apply -k k8s/homebridge/
```

**Shell access**:
```bash
kubectl exec -it deployment/homebridge -n homebridge -- /bin/bash
```

## Uninstall

```bash
kubectl delete -k k8s/homebridge/
```

**WARNING**: This will delete the namespace but the PersistentVolume will be retained (Retain policy). To fully remove:
```bash
kubectl delete pv homebridge-pv
sudo rm -rf /opt/homebridge  # CAUTION: This will delete all HomeKit pairing data!
```
