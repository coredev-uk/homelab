# Authelia SSO & Authentication

Authelia provides Single Sign-On (SSO) and authentication for the homelab cluster. It integrates with LLDAP for user management and provides both OIDC and ForwardAuth capabilities.

## Architecture

- **Authelia**: Authentication and SSO service (OIDC provider + ForwardAuth)
- **LLDAP**: Lightweight LDAP directory for user/group management
- **Traefik**: Ingress controller with ForwardAuth middleware support

## Components

### LLDAP
- **URL**: https://lldap.home.coredev.uk
- **Port**: 3890 (LDAP), 17170 (Web UI)
- **Base DN**: dc=home,dc=coredev,dc=uk
- **Admin User**: admin
- **Storage**: 1Gi Longhorn PVC

### Authelia
- **URL**: https://auth.home.coredev.uk
- **Port**: 9091
- **Storage**: 1Gi Longhorn PVC (SQLite database)
- **Session Domain**: home.coredev.uk

## Setup Instructions

### 1. Generate Secrets

Use the provided script to generate all required secrets:

```bash
cd secrets/
./generate-authelia-secrets.sh
```

This will output all the values you need. Copy them to your `secrets.env` file.

Alternatively, generate manually:

```bash
# LLDAP Admin Password - create your own
LLDAP_ADMIN_PASSWORD="your_secure_password"

# LLDAP JWT Secret
LLDAP_JWT_SECRET=$(openssl rand -base64 32)

# Authelia Storage Encryption Key
AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)

# Authelia OIDC HMAC Secret
AUTHELIA_OIDC_HMAC_SECRET=$(openssl rand -hex 32)

# Authelia OIDC Private Key (RSA 4096)
openssl genrsa -out oidc-key.pem 4096
# Copy the entire contents of oidc-key.pem to AUTHELIA_OIDC_PRIVATE_KEY

# Grafana Client Secret
AUTHELIA_GRAFANA_CLIENT_SECRET=$(openssl rand -hex 32)

# ArgoCD Client Secret
AUTHELIA_ARGOCD_CLIENT_SECRET=$(openssl rand -hex 32)
```

### 2. Add Secrets to secrets.env

Edit `secrets/secrets.env` and add the generated values:

```bash
# Authelia & LLDAP
LLDAP_ADMIN_PASSWORD=your_lldap_admin_password_here
LLDAP_JWT_SECRET=generated_value
AUTHELIA_STORAGE_ENCRYPTION_KEY=generated_value
AUTHELIA_OIDC_HMAC_SECRET=generated_value
AUTHELIA_OIDC_PRIVATE_KEY="$(cat <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
... your RSA private key ...
-----END RSA PRIVATE KEY-----
EOF
)"
AUTHELIA_GRAFANA_CLIENT_SECRET=generated_value
AUTHELIA_ARGOCD_CLIENT_SECRET=generated_value
```

### 3. Generate SealedSecrets

Run the sealed secrets generation script:

```bash
cd secrets/
./generate-sealed-secrets.sh
```

This will create and apply SealedSecrets for:
- LLDAP (admin password, JWT secret)
- Authelia (LDAP password, encryption keys, OIDC secrets, client secrets)
- Grafana (OIDC client secret)
- ArgoCD (OIDC client secret)

### 4. Deploy via ArgoCD

The Authelia application is configured in `/apps/infrastructure/applications.yaml` and will be automatically deployed by ArgoCD.

Alternatively, deploy manually:

```bash
kubectl apply -k k8s/authelia
```

### 5. Configure LLDAP Users

1. Access LLDAP at https://lldap.home.coredev.uk
2. Login with admin credentials from your secrets.env
3. Create groups:
   - `grafana_admin` - Full Grafana admin access
   - `grafana_editor` - Grafana editor access
   - `argocd_admin` - Full ArgoCD admin access
   - `argocd_editor` - ArgoCD developer/editor access
4. Create users and assign to appropriate groups

## Integration Guide

### Services with OIDC (Native Integration)

#### Grafana (grafana.home.coredev.uk)
- **Configuration**: k8s/grafana/app/deployment.yaml:20
- **Client ID**: `grafana`
- **Groups**: `grafana_admin`, `grafana_editor`
- **Role Mapping**: Automatic via OIDC groups claim
- **Status**: ✅ Configured

#### ArgoCD (argocd.home.coredev.uk)
- **Configuration**: k8s/argocd/app/config.yaml:3
- **Client ID**: `argocd`
- **Groups**: `argocd_admin`, `argocd_editor`
- **RBAC**: Configured in argocd-rbac-cm ConfigMap
- **Status**: ✅ Configured

### Services with ForwardAuth (Traefik Middleware)

All services below are protected by Authelia ForwardAuth with appropriate API route exclusions.

#### Infrastructure Services

**Longhorn** (longhorn.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: None
- **Status**: ✅ Configured

**Prometheus** (prometheus.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: None
- **Status**: ✅ Configured

**Pi-hole** (pihole.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: `/admin/api.php`, `/api/*`
- **Status**: ✅ Configured

**Glance** (glance.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: None (dashboard only)
- **Status**: ✅ Configured

#### Download Clients

**qBittorrent/Flood** (qbittorrent.home.coredev.uk)
- **Priority**: Medium
- **API Exclusions**: `/api/v2/*`
- **Status**: ✅ Configured

**SABnzbd** (sabnzbd.home.coredev.uk)
- **Priority**: Medium
- **API Exclusions**: `/api`, `/sabnzbd/api`
- **Status**: ✅ Configured

#### Media Management (*arr Stack)

**Sonarr** (sonarr.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: `/api/*`, `/ping`, `/health`
- **Notes**: Mobile app access via API keys preserved
- **Status**: ✅ Configured

**Radarr** (radarr.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: `/api/*`, `/ping`, `/health`
- **Notes**: Mobile app access via API keys preserved
- **Status**: ✅ Configured

**Prowlarr** (prowlarr.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: `/api/*`, `/ping`, `/health`
- **Notes**: Indexer sync via API preserved
- **Status**: ✅ Configured

**Bazarr** (bazarr.home.coredev.uk)
- **Priority**: High
- **API Exclusions**: `/api/*`
- **Notes**: Subtitle automation via API preserved
- **Status**: ✅ Configured

#### Surveillance & Security

**Frigate** (frigate.home.coredev.uk)
- **Priority**: Medium
- **API Exclusions**: `/api/*`, `/vod/*`, `/clips/*`, `/recordings/*`
- **Notes**: Camera streams and recordings accessible via API
- **Status**: ✅ Configured

#### Notifications & Utilities

**Notifiarr** (notifiarr.home.coredev.uk)
- **Priority**: Medium
- **API Exclusions**: `/api/*`, `/webhook`
- **Notes**: Webhook receiver endpoints preserved
- **Status**: ✅ Configured

**Cleanuparr** (cleanuparr.home.coredev.uk)
- **Priority**: Low
- **API Exclusions**: None
- **Status**: ✅ Configured

**Huntarr** (huntarr.home.coredev.uk)
- **Priority**: Low
- **API Exclusions**: None
- **Status**: ✅ Configured

#### Media Services

**Jellyfin** (jellyfin.home.coredev.uk)
- **Priority**: Medium
- **Integration**: LDAP plugin (https://github.com/jellyfin/jellyfin-plugin-ldapauth)
- **Notes**: Use native LDAP authentication plugin instead of ForwardAuth
- **Status**: ⏸️ Manual configuration required

**Jellyseerr** (jellyseerr.home.coredev.uk)
- **Priority**: Medium
- **Integration**: Jellyfin authentication (inherits from Jellyfin)
- **Notes**: Authenticates via Jellyfin - no separate auth needed
- **Status**: ⏸️ Configure after Jellyfin LDAP setup

### Services Not Requiring Authentication

Add this annotation to the Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: authelia-authelia-forwardauth@kubernetescrd
```

Or for IngressRoute (Traefik CRD):

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: my-service
spec:
  routes:
    - match: Host(`service.home.coredev.uk`)
      kind: Rule
      middlewares:
        - name: authelia-forwardauth
          namespace: authelia
      services:
        - name: my-service
          port: 80
```

## Access Control Policies

Current policy in `/k8s/authelia/app/deployment.yaml`:

```yaml
access_control:
  default_policy: deny
  rules:
    # Authelia portal - bypass auth
    - domain: auth.home.coredev.uk
      policy: bypass
    # All other services - require authentication
    - domain: "*.home.coredev.uk"
      policy: one_factor
```

### Policy Options:
- `bypass`: No authentication required
- `one_factor`: Username/password required
- `two_factor`: Username/password + TOTP required

### Example Multi-Factor Policy:

```yaml
# Require 2FA for critical services
- domain:
    - argocd.home.coredev.uk
    - longhorn.home.coredev.uk
  policy: two_factor

# Regular auth for other services
- domain: "*.home.coredev.uk"
  policy: one_factor
```

## Adding New OIDC Clients

To add a new service with OIDC support:

1. Add client configuration to Authelia config in `/k8s/authelia/app/deployment.yaml`:

```yaml
- id: new-service
  description: New Service Name
  secret: CHANGE_THIS_NEW_SERVICE_SECRET
  public: false
  authorization_policy: one_factor
  redirect_uris:
    - https://newservice.home.coredev.uk/oauth/callback
  scopes:
    - openid
    - profile
    - email
    - groups
  grant_types:
    - authorization_code
  response_types:
    - code
```

2. Configure the service to use Authelia OIDC:
   - **Issuer URL**: https://auth.home.coredev.uk
   - **Client ID**: `new-service`
   - **Client Secret**: (generated secret)
   - **Discovery URL**: https://auth.home.coredev.uk/.well-known/openid-configuration

## Monitoring & Troubleshooting

### Check Service Status

```bash
# Authelia
kubectl get pods -n authelia
kubectl logs -n authelia -l app=authelia

# LLDAP
kubectl logs -n authelia -l app=lldap
```

### Common Issues

#### 1. LDAP Connection Failures
- Verify LLDAP is running: `kubectl get pods -n authelia`
- Check LDAP password in secret: `kubectl get secret authelia-secrets -n authelia -o yaml`
- Test LDAP connection from Authelia pod

#### 2. OIDC Login Failures
- Check client secrets match between Authelia config and service config
- Verify redirect URIs are correct
- Check Authelia logs for detailed error messages

#### 3. ForwardAuth Not Working
- Verify middleware is correctly referenced in ingress annotations
- Check Traefik can reach Authelia service: `http://authelia.authelia.svc.cluster.local:9091`
- Review Traefik logs for middleware errors

### Health Checks

- **Authelia Health**: https://auth.home.coredev.uk/api/health
- **LLDAP UI**: https://lldap.home.coredev.uk

## Security Considerations

1. **Secrets Management**: All secrets are managed via SealedSecrets and the secrets generation script
2. **Enable 2FA**: Consider requiring two-factor authentication for critical services
3. **Regular Backups**: Backup Authelia and LLDAP PVCs regularly
4. **Session Management**: Review session duration settings based on security requirements
5. **Network Policies**: Consider implementing network policies to restrict LDAP access

## Next Steps

### Optional: Jellyfin LDAP Integration

Jellyfin has its own LDAP authentication plugin. Once configured, Jellyseerr will automatically use Jellyfin's authentication.

#### Configure Jellyfin LDAP:

1. Install the LDAP Authentication Plugin in Jellyfin
   - Dashboard → Plugins → Catalog
   - Install "LDAP Authentication Plugin"
   - Restart Jellyfin

2. Configure LDAP settings:
   - **LDAP Server**: `lldap.authelia.svc.cluster.local:3890`
   - **LDAP Port**: `3890`
   - **Secure LDAP**: Disabled (internal cluster communication)
   - **LDAP Bind User**: `uid=admin,ou=people,dc=home,dc=coredev,dc=uk`
   - **LDAP Bind Password**: Your LLDAP admin password
   - **LDAP Base DN**: `dc=home,dc=coredev,dc=uk`
   - **LDAP Search Filter**: `(uid={0})`
   - **LDAP User Filter**: `(objectClass=person)`

3. Test authentication with an LLDAP user

#### Configure Jellyseerr:

1. Access Jellyseerr at https://jellyseerr.home.coredev.uk
2. Go to Settings → Jellyfin
3. Configure Jellyfin server connection
4. Enable "Use Jellyfin Auth"
5. Users will authenticate via Jellyfin (which uses LDAP)

Reference: https://github.com/jellyfin/jellyfin-plugin-ldapauth

### Optional Enhancements

#### Enable Two-Factor Authentication

Update access control policy in k8s/authelia/app/deployment.yaml:54 for critical services:

```yaml
access_control:
  rules:
    # Require 2FA for critical infrastructure
    - domain:
        - argocd.home.coredev.uk
        - longhorn.home.coredev.uk
        - prometheus.home.coredev.uk
      policy: two_factor
    
    # Regular auth for other services
    - domain: "*.home.coredev.uk"
      policy: one_factor
```

#### Add New Services

To protect additional services with ForwardAuth, add to IngressRoute:

```yaml
routes:
  # API routes without auth (if applicable)
  - match: Host(`service.home.coredev.uk`) && PathPrefix(`/api`)
    kind: Rule
    services:
      - name: service
        port: 8080
  
  # Web UI with auth
  - match: Host(`service.home.coredev.uk`)
    kind: Rule
    middlewares:
      - name: authelia-forwardauth
        namespace: authelia
    services:
      - name: service
        port: 8080
```

## References

- [Authelia Documentation](https://www.authelia.com/)
- [LLDAP Documentation](https://github.com/lldap/lldap)
- [Traefik ForwardAuth](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
