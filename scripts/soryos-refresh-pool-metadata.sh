#!/usr/bin/env bash
# Rebuild dists/stable from pool/*.deb for the local ISO mirror.
# Pages dists/ can lag behind index.json; always refresh before apt in chroot.
set -euo pipefail

POOL="${1:?pool directory required}"
SUITE="${SORYOS_SUITE:-stable}"

command -v dpkg-scanpackages >/dev/null || {
  printf 'missing dpkg-scanpackages (install dpkg-dev)\n' >&2
  exit 1
}
command -v apt-ftparchive >/dev/null || {
  printf 'missing apt-ftparchive (install apt-utils)\n' >&2
  exit 1
}

cd "$POOL"
rm -f \
  "dists/$SUITE/Release" \
  "dists/$SUITE/Release.gpg" \
  "dists/$SUITE/InRelease"
dpkg-scanpackages -a amd64 "pool/$SUITE" /dev/null \
  > "dists/$SUITE/main/binary-amd64/Packages"
gzip -9cn "dists/$SUITE/main/binary-amd64/Packages" \
  > "dists/$SUITE/main/binary-amd64/Packages.gz"
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=SoryOS \
  -o APT::FTPArchive::Release::Label=SoryOS \
  -o APT::FTPArchive::Release::Suite="$SUITE" \
  -o APT::FTPArchive::Release::Codename="$SUITE" \
  -o APT::FTPArchive::Release::Architectures=amd64 \
  -o APT::FTPArchive::Release::Components=main \
  -o "APT::FTPArchive::Release::Description=SoryOS APT Repository" \
  release "dists/$SUITE" > "dists/$SUITE/Release"
count="$(grep -c '^Package:' "dists/$SUITE/main/binary-amd64/Packages")"
printf 'refreshed %s: %s package(s) in Packages\n' "$POOL" "$count"
