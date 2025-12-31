# Example: Creating Encrypted Secrets for Pi-hole

# This directory contains SOPS-encrypted secrets for Pi-hole
# To create/edit secrets:

# 1. Create the secret YAML (unencrypted first)
apiVersion: v1
kind: Secret
metadata:
  name: pihole-password
  namespace: pihole
type: Opaque
stringData:
  password: "changeme"  # Replace with actual password

# 2. Encrypt with SOPS
# sops --encrypt --in-place pihole-password.yaml

# 3. The file will now contain encrypted data like:
# stringData:
#   password: ENC[AES256_GCM,data:xxx...,iv:yyy...,tag:zzz...,type:str]

# 4. Commit to Git
# git add k8s/pihole/secrets/pihole-password.yaml
# git commit -m "feat: add pihole password secret"
