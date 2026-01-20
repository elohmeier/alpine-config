#!/bin/sh
# Device enrollment script for Alpine Linux hosts
# Creates a PR to add this host to the fleet registry
set -eu

REPO="elohmeier/alpine-config"
SSH_PUBKEY_PATH="/etc/ssh/ssh_host_ed25519_key.pub"
SSH_PRIVKEY_PATH="/etc/ssh/ssh_host_ed25519_key"
AGE_KEY_PATH="/etc/sops/age/keys.txt"

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

# Check dependencies
for cmd in gh ssh-to-age yq; do
    command -v "$cmd" >/dev/null 2>&1 || die "missing: $cmd"
done

# Get hostname
HOSTNAME="${1:-$(hostname)}"
printf 'Enrolling: %s\n' "$HOSTNAME"

# Validate hostname format
echo "$HOSTNAME" | grep -qE '^[a-z0-9][a-z0-9-]*[a-z0-9]$' ||
    die "invalid hostname format: $HOSTNAME"

# Read SSH pubkey
[ -f "$SSH_PUBKEY_PATH" ] || die "missing: $SSH_PUBKEY_PATH"
SSH_PUBKEY=$(cat "$SSH_PUBKEY_PATH")
printf 'SSH key: %s\n' "${SSH_PUBKEY%% *}..."

# Derive age pubkey
AGE_PUBKEY=$(echo "$SSH_PUBKEY" | ssh-to-age)
printf 'Age key: %s\n' "$AGE_PUBKEY"

# Authenticate with GitHub
gh auth status >/dev/null 2>&1 || gh auth login --web

# Check if already enrolled
if gh api "repos/${REPO}/contents/hosts.yaml" --jq '.content' 2>/dev/null |
    base64 -d | yq -e ".hosts[] | select(.hostname == \"$HOSTNAME\")" >/dev/null 2>&1; then
    die "host already enrolled: $HOSTNAME"
fi

# Clone and create PR
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

gh repo clone "$REPO" "$TMPDIR" -- --depth 1
cd "$TMPDIR"

BRANCH="enroll/${HOSTNAME}"
git checkout -b "$BRANCH"

# Add host entry
yq -i ".hosts += [{
    \"hostname\": \"$HOSTNAME\",
    \"ssh_pubkey\": \"$SSH_PUBKEY\",
    \"age_pubkey\": \"$AGE_PUBKEY\"
}]" hosts.yaml

git add hosts.yaml
git commit -m "enroll: $HOSTNAME"
git push -u origin "$BRANCH"

gh pr create \
    --title "enroll: $HOSTNAME" \
    --body "Adds \`$HOSTNAME\` to the fleet registry.

**Age pubkey:** \`$AGE_PUBKEY\`

CI validates the age key derivation from SSH pubkey."

# Store age private key for later decryption
mkdir -p "$(dirname "$AGE_KEY_PATH")"
ssh-to-age -private-key -i "$SSH_PRIVKEY_PATH" -o "$AGE_KEY_PATH"
chmod 600 "$AGE_KEY_PATH"

printf 'PR created. Merge to complete enrollment.\n'
printf 'Age key stored at %s\n' "$AGE_KEY_PATH"
