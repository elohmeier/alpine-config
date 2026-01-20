# alpine-config

Fleet configuration for Alpine Linux hosts using sops/age encryption.

## Enrollment

```sh
# Add repos and keys
echo "https://elohmeier.github.io/alpine-config" >> /etc/apk/repositories
wget -qO /etc/apk/keys/config@elohmeier.rsa.pub https://elohmeier.github.io/alpine-config/keys/config@elohmeier.rsa.pub

# Install and enroll
apk update && apk add alpine-enroll
alpine-enroll

# Remove enrollment package (optional)
apk del alpine-enroll
```

This creates a PR adding the host's SSH pubkey and derived age key to `hosts.yaml`.

## After Merge

```sh
apk update && apk add host-config
/etc/alpine-config/decrypt.sh
```

## Secrets

Required GitHub secrets:

- `SOPS_AGE_KEY`: Admin age private key for reencryption
- `MELANGE_KEY`: Base64-encoded melange signing key

## Adding Secrets

```sh
# Create/edit encrypted secrets
sops secrets/fleet.sops.yaml
```
