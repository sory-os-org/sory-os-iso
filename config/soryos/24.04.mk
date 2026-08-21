DISTRO_NAME=SoryOS
DISTRO_CODE=soryos

# Base Ubuntu packages (noble) — use archive.ubuntu.com (apt.pop-os.org often unavailable)
UBUNTU_MIRROR:=http://archive.ubuntu.com/ubuntu

APT_PREFERENCES=data/apt-preferences-soryos

# Live ISO kernel cmdline (grub/isolinux). No `splash` until a plymouth theme is
# packaged — otherwise cosmic-greeter waits forever on plymouth-quit-wait (black screen).
DISTRO_PARAMS+=noplymouth

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
# Monté dans le chroot via bind (voir mk/chroot.mk) — chemin visible par apt dans le chroot
SORYOS_APT_CHROOT_MOUNT=/mnt/soryos-apt
RELEASE_URI=file:$(SORYOS_APT_CHROOT_MOUNT)
RELEASE_SUITE=stable
# Pool local file:// : métadonnées régénérées sans signature (index vérifié en amont)
RELEASE_TRUSTED=1
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
	expect \
	gparted
# distinst: installateur graphique — sources sur sory-os-org/distinst via CI.

RM_PKGS=\
	snapd \
	unattended-upgrades

MAIN_POOL=
RESTRICTED_POOL=
POOL_PKGS=

STAGING_BRANCHES=
