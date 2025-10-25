#!/usr/bin/env bash
set -euo pipefail

GALAXY_BIN=${1:-}
REQUIREMENTS_FILE=${2:-}
DEST_DIR=${3:-}
MAX_ATTEMPTS=${ANSIBLE_GALAXY_MAX_ATTEMPTS:-5}
TIMEOUT_SECONDS=${ANSIBLE_GALAXY_TIMEOUT_SECONDS:-300}
SLEEP_SECONDS=${ANSIBLE_GALAXY_RETRY_SLEEP_SECONDS:-5}

if [[ -z "$GALAXY_BIN" || -z "$REQUIREMENTS_FILE" || -z "$DEST_DIR" ]]; then
  echo "Usage: $0 <ansible-galaxy-bin> <requirements-file> <collections-dir>" >&2
  exit 2
fi

mkdir -p "$DEST_DIR"

for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  echo "--- ansible-galaxy install attempt ${attempt}/${MAX_ATTEMPTS} (timeout ${TIMEOUT_SECONDS}s) ---"
  if timeout "${TIMEOUT_SECONDS}" "$GALAXY_BIN" collection install -r "$REQUIREMENTS_FILE" -p "$DEST_DIR" --force; then
    echo "--- ansible-galaxy install completed successfully on attempt ${attempt} ---"
    exit 0
  fi

  status=$?
  if [[ $attempt -lt $MAX_ATTEMPTS ]]; then
    echo "ansible-galaxy install failed with exit code ${status}; retrying in ${SLEEP_SECONDS}s..." >&2
    sleep "$SLEEP_SECONDS"
  else
    echo "ansible-galaxy install failed after ${MAX_ATTEMPTS} attempts (last exit code ${status})." >&2
    exit "$status"
  fi

done
