#!/usr/bin/env bash
set -euo pipefail
INV="inventory/hosts.yaml"
if [[ ! -f "$INV" ]]; then
  echo "[ssh-keyscan] inventory/hosts.yaml not found" >&2
  exit 1
fi
IPS=$(grep -Eo 'ansible_host:\s*[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$INV" | awk '{print $2}' | sort -u)
mkdir -p ~/.ssh
touch ~/.ssh/known_hosts
for ip in $IPS; do
  echo "[ssh-keyscan] refresh $ip"
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
  ssh-keyscan -T 5 -H "$ip" >> ~/.ssh/known_hosts 2>/dev/null || true
done
echo "[ssh-keyscan] done."
