#!/usr/bin/env bash
# Local integration packages required by the ISO pool (no apt.pop-os.org).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APT_ROOT="${1:?pool directory required}"
POOL="${APT_ROOT}/pool/stable"
TEMPLATE="${ROOT_DIR}/../sory-os-apt/templates/soryos-pop-compat/control"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Built by CI on GitHub Release — never fetched from apt.pop-os.org.
REQUIRED_RELEASE_PKGS=(
  pop-launcher
  adw-gtk3
)

mkdir -p "$POOL"

build_compat() {
  local name="soryos-pop-compat"
  local version arch deb
  version="$(awk '/^Version: / {print $2}' "$TEMPLATE")"
  arch="$(awk '/^Architecture: / {print $2}' "$TEMPLATE")"
  deb="${POOL}/${name}_${version}_${arch}.deb"

  mkdir -p "$WORK/$name/DEBIAN" "$WORK/$name/usr/share/doc/$name"
  cp "$TEMPLATE" "$WORK/$name/DEBIAN/control"
  printf '%s compatibility metapackage\n' "$name" > "$WORK/$name/usr/share/doc/$name/README"
  dpkg-deb --build "$WORK/$name" "$deb" >/dev/null
  printf 'built %s\n' "$(basename "$deb")"
}

verify_release_pool() {
  local missing=()
  local package
  for package in "${REQUIRED_RELEASE_PKGS[@]}"; do
    if ! compgen -G "$POOL/${package}_"*.deb >/dev/null; then
      missing+=("$package")
    fi
  done
  if ((${#missing[@]} > 0)); then
    printf 'Missing from GitHub Release pool: %s\n' "${missing[*]}" >&2
    printf 'Build them with CI (sory-os-apt/.github/workflows/build-deb-release.yml).\n' >&2
    printf 'Do not use apt.pop-os.org — publish a new Release tag, then rebuild the ISO.\n' >&2
    exit 1
  fi
}

build_compat
verify_release_pool
