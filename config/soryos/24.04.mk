DISTRO_NAME=SoryOS
DISTRO_CODE=soryos

APT_PREFERENCES=data/apt-preferences-soryos

# Show splash screen
DISTRO_PARAMS+=quiet splash

# DEB822 format system repositories
DEB822:=1

# ── Modèle Pages + Releases (comme modules-sory-os/sory-os-apt) ─────────────
# GitHub Pages  : index.json signé + dists/ + clés (catalogue léger, pas de .deb)
# GitHub Release: .deb binaires référencés par l'index
#
# Pages = https://sory-os-org.github.io/sory-os-apt/
# Release = https://github.com/sory-os-org/sory-os-apt/releases/download/<tag>/

SORYOS_APT_REPO?=sory-os-org/sory-os-apt
SORYOS_PAGES_BASE_URL?=https://sory-os-org.github.io/sory-os-apt
SORYOS_RELEASE_TAG?=soryos-deb-test-2026.08.13
# Pages catalogue (optional). Fallback: index on the GitHub Release.
SORYOS_RELEASE_INDEX_URL?=https://github.com/sory-os-org/sory-os-apt/releases/download/$(SORYOS_RELEASE_TAG)/index.json

# Pendant le build ISO : pool local construit depuis Pages (catalogue) + Release (.deb)
SORYOS_APT_ROOT=$(BUILD)/soryos-apt
RELEASE_URI=file:$(SORYOS_APT_ROOT)
RELEASE_SUITE=stable
RELEASE_KEY=/iso/soryos-archive-keyring.gpg

# Sur le système installé : métadonnées APT depuis Pages (mises à jour via index)
SORYOS_APT_URI?=$(SORYOS_PAGES_BASE_URL)

# Packages to install into the installed system
DISTRO_PKGS=\
	systemd \
	cosmic-term \
	linux-generic \
	soryos-desktop

POST_DISTRO_PKGS=\
	rsync \
	systemd-boot

# Live ISO packages
LIVE_PKGS=\
	casper \
	cosmic-initial-setup-casper \
	distinst \
	expect \
	gparted

RM_PKGS=\
	snapd

MAIN_POOL=
RESTRICTED_POOL=
POOL_PKGS=

STAGING_BRANCHES=
