# Talos Configuration for Logging to Vector

## Vector Service Details
- **LoadBalancer IP**: 192.168.20.21
- **Kernel logs**: UDP port 6001
- **Service logs**: UDP port 6002

## Talos Configuration

You need to patch your Talos node configuration to send logs to Vector. Here's how:

### Option 1: Using talosctl patch (Temporary)

```bash
# Get the Vector LoadBalancer IP
VECTOR_IP=$(kubectl get svc -n vector vector -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Patch the node to enable logging
talosctl -n <node-ip> patch machineconfig --patch '
machine:
  logging:
    destinations:
      - endpoint: "udp://'${VECTOR_IP}':6001/"
        format: json_lines
      - endpoint: "udp://'${VECTOR_IP}':6002/"
        format: json_lines
'
```

### Option 2: Update Talos Machine Config (Permanent)

Add this to your Talos machine config YAML:

```yaml
machine:
  logging:
    destinations:
      - endpoint: "udp://192.168.20.21:6001/"
        format: json_lines
      - endpoint: "udp://192.168.20.21:6002/"
        format: json_lines
```

Then apply the config:

```bash
talosctl -n <node-ip> apply-config --file <your-config>.yaml
```

## Verification

After configuring Talos:

1. **Check Vector logs to see if it's receiving data**:
   ```bash
   kubectl logs -n vector -l app=vector --tail=50
   ```

2. **Query Loki for Talos logs in Grafana**:
   ```
   {job="talos-kernel"}
   {job="talos-service"}
   {node="hyperion-1"}
   ```

3. **Check Flux metrics in Prometheus**:
   - Go to Prometheus UI
   - Query: `gotk_reconcile_duration_seconds_count`
   - Should see metrics from source-controller, kustomize-controller, helm-controller, notification-controller

## Logs You'll See

- **talos-kernel**: Kernel messages, hardware events, system-level logs
- **talos-service**: Kubelet, containerd, etcd, and other Talos services
- All logs will have labels: `job`, `node`, `facility`
