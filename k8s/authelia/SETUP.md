# Authelia Setup Quick Reference

## 1. Generate Secrets

```bash
cd secrets/
./generate-authelia-secrets.sh > authelia-secrets-output.txt
```

Copy the output values to your `secrets.env` file.

## 2. Generate SealedSecrets

```bash
cd secrets/
./generate-sealed-secrets.sh
```

This creates and applies the following SealedSecrets:
- `lldap-secret` (authelia namespace)
- `authelia-secrets` (authelia namespace)
- `grafana-secrets` (grafana namespace)
- `argocd-secret` (argocd namespace)

## 3. Verify Deployment

```bash
# Check pods
kubectl get pods -n authelia

# Check secrets
kubectl get sealedsecrets -n authelia
kubectl get secrets -n authelia

# Check logs
kubectl logs -n authelia -l app=lldap
kubectl logs -n authelia -l app=authelia
```

## 4. Access Services

- **Authelia Portal**: https://auth.home.coredev.uk
- **LLDAP Admin**: https://lldap.home.coredev.uk

## 5. Create LLDAP Groups

Login to LLDAP and create these groups:
- `grafana_admin`
- `grafana_editor`
- `argocd_admin`
- `argocd_editor`

## 6. Test Authentication

1. Visit https://grafana.home.coredev.uk
2. Click "Sign in with Authelia"
3. Login with LLDAP credentials
4. Should redirect back to Grafana authenticated

## Troubleshooting

### Check Authelia Config
```bash
kubectl exec -n authelia deployment/authelia -- cat /config/configuration.yml
```

### Check Secrets
```bash
kubectl get secret authelia-secrets -n authelia -o yaml
kubectl get secret lldap-secret -n authelia -o yaml
```

### View Logs
```bash
kubectl logs -n authelia -l app=authelia --tail=100 -f
kubectl logs -n authelia -l app=lldap --tail=100 -f
```

### Test LDAP Connection
```bash
kubectl exec -n authelia deployment/authelia -- \
  ldapsearch -x -H ldap://lldap:3890 \
  -D "uid=admin,ou=people,dc=home,dc=coredev,dc=uk" \
  -w "$LLDAP_PASSWORD" \
  -b "dc=home,dc=coredev,dc=uk"
```
