BUILD=build/$(DISTRO_CODE)/$(DISTRO_VERSION)/$(DISTRO_ARCH)

ISO=$(BUILD)/$(ISO_NAME).iso
TAR=$(BUILD)/$(ISO_NAME).tar
USB=$(BUILD)/$(ISO_NAME).img

CASPER_PATH=casper_$(ISO_NAME)

SED=\
	s|CASPER_PATH|$(CASPER_PATH)|g; \
	s|DISTRO_NAME|$(DISTRO_NAME)|g; \
	s|DISTRO_CODE|$(DISTRO_CODE)|g; \
	s|DISTRO_VERSION|$(DISTRO_VERSION)|g; \
	s|DISTRO_ARCH|$(DISTRO_ARCH)|g; \
	s|DISTRO_DATE|$(DISTRO_DATE)|g; \
	s|DISTRO_EPOCH|$(DISTRO_EPOCH)|g; \
	s|DISTRO_PARAMS|$(DISTRO_PARAMS)|g; \
	s|DISTRO_REPOS|$(DISTRO_REPOS)|g; \
	s|DISTRO_PKGS|$(DISTRO_PKGS)|g; \
	s|UBUNTU_CODE|$(UBUNTU_CODE)|g; \
	s|UBUNTU_NAME|$(UBUNTU_NAME)|g

CHROOT=env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin chroot

# Avoid redirecting to /dev/null here: a broken /dev/null breaks $(shell ...) on some hosts.
XORRISO := $(shell command -v xorriso)
ZSYNC := $(shell command -v zsync)
SQUASHFS := $(shell command -v mksquashfs)

ifeq (,$(XORRISO))
$(error xorriso not found! Run deps.sh first.)
endif
ifeq (,$(SQUASHFS))
$(error squashfs-tools not found! Run deps.sh first.)
endif
