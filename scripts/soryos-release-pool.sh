#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APT_SCRIPT="${ROOT_DIR}/sory-os-apt/scripts/download-release-pool.sh"
OUTPUT_DIR="${1:-}"

if [[ ! -x "$APT_SCRIPT" ]]; then
  printf 'missing SoryOS APT download script: %s\n' "$APT_SCRIPT" >&2
  exit 1
fi

export SORYOS_PAGES_BASE_URL="${SORYOS_PAGES_BASE_URL:-}"
export SORYOS_RELEASE_INDEX_URL="${SORYOS_RELEASE_INDEX_URL:-}"

if [[ -z "$SORYOS_PAGES_BASE_URL" && -z "$SORYOS_RELEASE_INDEX_URL" ]]; then
  printf 'SORYOS_PAGES_BASE_URL or SORYOS_RELEASE_INDEX_URL is required\n' >&2
  exit 2
fi

if [[ -n "$OUTPUT_DIR" ]]; then
  exec "$APT_SCRIPT" "$OUTPUT_DIR"
fi

exec "$APT_SCRIPT"
