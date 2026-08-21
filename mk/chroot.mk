$(BUILD)/debootstrap:
	mkdir -p $(BUILD)

	# Remove old debootstrap
	sudo rm -rf "$@" "$@.partial"

	# Install using debootstrap
	if ! sudo debootstrap \
		--arch=$(DISTRO_ARCH) \
		"$(UBUNTU_CODE)" \
		"$@.partial" \
		"$(UBUNTU_MIRROR)"; \
	then \
		cat "$@.partial/debootstrap/debootstrap.log"; \
		false; \
	fi

	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"

$(BUILD)/chroot: $(BUILD)/debootstrap
	# Unmount chroot if mounted
	scripts/unmount.sh "$@.partial"

	# Remove old chroot
	sudo rm -rf "$@" "$@.partial"

	# Copy chroot
	sudo cp -a "$<" "$@.partial"

	# Make temp directory for modifications
	sudo rm -rf "$@.partial/iso"
	sudo mkdir -p "$@.partial/iso"

	# Copy chroot script
	sudo cp "scripts/chroot.sh" "$@.partial/iso/chroot.sh"
	sudo cp "scripts/repos.sh" "$@.partial/iso/repos.sh"

	# Mount chroot
	"scripts/mount.sh" "$@.partial"

	# Workaround for dracut issue on 26.04 when nvidia driver runs update-initramfs with host kernel
	sudo mkdir -p "$@.partial/lib/modules/$(shell uname -r)"

	# Install dependencies of chroot script
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"UPDATE=1 \
		UPGRADE=1 \
		INSTALL=\"--no-install-recommends gnupg software-properties-common\" \
		AUTOREMOVE=1 \
		CLEAN=1 \
		/iso/chroot.sh"

	# Copy GPG public key for Pop staging repositories
	gpg --batch --yes --export "204DD8AEC33A7AFF" | sudo tee "$@.partial/iso/pop-keyring-2017-archive.gpg" > /dev/null

	# Download SoryOS pool: catalogue Pages + binaires Release (never build .deb locally)
	if [ -n "${SORYOS_PAGES_BASE_URL}" ] || [ -n "${SORYOS_RELEASE_INDEX_URL}" ]; then \
		mkdir -p "$(SORYOS_APT_ROOT)"; \
		SORYOS_PAGES_BASE_URL="$(SORYOS_PAGES_BASE_URL)" \
		SORYOS_RELEASE_INDEX_URL="$(SORYOS_RELEASE_INDEX_URL)" \
			bash "scripts/soryos-release-pool.sh" "$(SORYOS_APT_ROOT)"; \
		bash "scripts/soryos-ensure-pool-extras.sh" "$(SORYOS_APT_ROOT)"; \
		bash "scripts/soryos-refresh-pool-metadata.sh" "$(SORYOS_APT_ROOT)"; \
		if ! ls "$(SORYOS_APT_ROOT)/pool/stable/"*.deb >/dev/null 2>&1; then \
			echo "SoryOS ISO build requires pre-built .deb from GitHub Release (CI), not local compilation" >&2; \
			echo "Publish a Release first: sory-os-apt/.github/workflows/build-deb-release.yml" >&2; \
			exit 1; \
		fi; \
		if [ -f "$(SORYOS_APT_ROOT)/keyrings/soryos-archive-keyring.gpg" ]; then \
			sudo cp "$(SORYOS_APT_ROOT)/keyrings/soryos-archive-keyring.gpg" \
				"$@.partial/iso/soryos-archive-keyring.gpg"; \
		fi; \
		if [ -n "$(SORYOS_APT_CHROOT_MOUNT)" ] && [ -d "$(SORYOS_APT_ROOT)" ]; then \
			sudo mkdir -p "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
			sudo mount --bind "$(CURDIR)/$(SORYOS_APT_ROOT)" "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
		fi; \
	fi

	# Clean APT sources
	sudo truncate --size=0 "$@.partial/etc/apt/sources.list"

	# Temporarily set apt preferences
	sudo cp "$(APT_PREFERENCES)" "$@.partial/etc/apt/preferences.d/pop-iso"

	# Copy kernelstub configuration
	sudo mkdir "$@.partial/etc/kernelstub"
	sudo cp "data/$(DISTRO_ARCH)/kernelstub" "$@.partial/etc/kernelstub/configuration"

	# Setup DEB822 format repos on 20.10 or later
	if [ -n "${DEB822}" ]; then \
		sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
			"FILENAME=\"/etc/apt/sources.list.d/system.sources\" \
			NAME=\"${DISTRO_NAME} System Sources\" \
			TYPES=\"deb deb-src\" \
			URIS=\"${UBUNTU_MIRROR}\" \
			SUITES=\"$(UBUNTU_CODE) $(UBUNTU_CODE)-security $(UBUNTU_CODE)-updates $(UBUNTU_CODE)-backports\" \
			COMPONENTS=\"main restricted universe multiverse\" \
			SIGNED_BY=\"${UBUNTU_KEY}\" \
			/iso/repos.sh"; \
	fi

	# Add release URIs
	if [ -n "${RELEASE_URI}" ]; then \
		sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
			"FILENAME=\"/etc/apt/sources.list.d/${DISTRO_CODE}-release.sources\" \
			NAME=\"${DISTRO_NAME} Release Sources\" \
			TYPES=\"deb\" \
			URIS=\"${RELEASE_URI}\" \
			SUITES=\"$(or $(RELEASE_SUITE),$(UBUNTU_CODE))\" \
			COMPONENTS=\"main\" \
			TRUSTED=\"${RELEASE_TRUSTED}\" \
			SIGNED_BY=\"${RELEASE_KEY}\" \
			/iso/repos.sh"; \
	fi

	# Run chroot script
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"KEY=\"/iso/pop-keyring-2017-archive.gpg\" \
		STAGING_BRANCHES=\"$(STAGING_BRANCHES)\" \
		UPDATE=1 \
		UPGRADE=1 \
		INSTALL=\"$(DISTRO_PKGS)\" \
		LANGUAGES=\"$(LANGUAGES)\" \
		PURGE=\"$(RM_PKGS)\" \
		AUTOREMOVE=1 \
		CLEAN=1 \
		/iso/chroot.sh \
		$(DISTRO_REPOS)"

	# Add extra URIS
	if [ -n "${APPS_URI}" ]; then \
		sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
			"FILENAME=\"/etc/apt/sources.list.d/${DISTRO_CODE}-apps.sources\" \
			NAME=\"${DISTRO_NAME} Applications\" \
			TYPES=\"deb\" \
			URIS=\"${APPS_URI}\" \
			SUITES=\"${UBUNTU_CODE}\" \
			COMPONENTS=\"main\" \
			SIGNED_BY=\"${APPS_KEY}\" \
			/iso/repos.sh"; \
	fi

	# Rerun chroot script to install POST_DISTRO_PKGS
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"INSTALL=\"$(POST_DISTRO_PKGS)\" \
		PURGE=\"$(RM_PKGS)\" \
		AUTOREMOVE=1 \
		CLEAN=1 \
		/iso/chroot.sh"

	# Remove apt preferences
	sudo rm "$@.partial/etc/apt/preferences.d/pop-iso"

	# Remove workaround for dracut issue on 26.04
	sudo rmdir --ignore-fail-on-non-empty "$@.partial/lib/modules/$(shell uname -r)"

	# Unmount chroot
	if [ -n "$(SORYOS_APT_CHROOT_MOUNT)" ] && mountpoint -q "$@.partial$(SORYOS_APT_CHROOT_MOUNT)" 2>/dev/null; then \
		sudo umount "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
	fi
	"scripts/unmount.sh" "$@.partial"

	sudo rm -rf "$@.partial"/root/.launchpadlib

	# Remove temp directory for modifications
	sudo rm -rf "$@.partial/iso"

	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"

$(BUILD)/chroot.tag: $(BUILD)/chroot
	sudo $(CHROOT) "$<" /bin/bash -e -c "dpkg-query -W --showformat='\$${Package}\t\$${Version}\n'" > "$@"

$(BUILD)/live: $(BUILD)/chroot
	# Unmount chroot if mounted
	scripts/unmount.sh "$@.partial"

	# Remove old chroot
	sudo rm -rf "$@" "$@.partial"

	# Copy chroot
	sudo cp -a "$<" "$@.partial"

	# Make temp directory for modifications
	sudo rm -rf "$@.partial/iso"
	sudo mkdir -p "$@.partial/iso"

	# Copy chroot script
	sudo cp "scripts/chroot.sh" "$@.partial/iso/chroot.sh"

	# Copy console-setup script
	sudo cp "scripts/console-setup.sh" "$@.partial/iso/console-setup.sh"

	# Mount chroot
	"scripts/mount.sh" "$@.partial"

	# SoryOS pool for live-only packages (cosmic-initial-setup-casper, distinst, …)
	if [ -n "$(SORYOS_APT_CHROOT_MOUNT)" ] && [ -d "$(SORYOS_APT_ROOT)" ]; then \
		sudo mkdir -p "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
		sudo mount --bind "$(CURDIR)/$(SORYOS_APT_ROOT)" "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
	fi

	# Copy GPG public key for APT CDROM
	gpg --batch --yes --export "$(GPG_NAME)" | sudo tee "$@.partial/iso/apt-cdrom.gpg" > /dev/null

	# Copy system76-power default modprobe.d configuration
	sudo cp "data/system76-power.conf" "$@.partial/etc/modprobe.d/system76-power.conf"

	# Copy ubuntu-drivers-common default prime-discrete configuration
	sudo cp "data/prime-discrete" "$@.partial/etc/prime-discrete"

	# Run chroot script
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"KEY=\"/iso/apt-cdrom.gpg\" \
		STAGING_BRANCHES=\"$(STAGING_BRANCHES)\" \
		INSTALL=\"$(LIVE_PKGS)\" \
		PURGE=\"$(RM_PKGS)\" \
		AUTOREMOVE=1 \
		CLEAN=1 \
		/iso/chroot.sh"

	# Remove undesired casper script
	if [ -e "$@.partial/usr/share/initramfs-tools/scripts/casper-bottom/01integrity_check" ]; then \
		sudo rm -f "$@.partial/usr/share/initramfs-tools/scripts/casper-bottom/01integrity_check"; \
	fi

	# SoryOS: no dists/ on the ISO — skip apt-cdrom, fix chown/ln/grep casper hooks
	if [ -d "$@.partial/usr/share/initramfs-tools/scripts/casper-bottom" ]; then \
		bash "scripts/soryos-patch-casper-bottom.sh" \
			"$@.partial/usr/share/initramfs-tools/scripts/casper-bottom"; \
		sudo $(CHROOT) "$@.partial" /usr/sbin/update-initramfs -u -k all; \
	fi

	# SoryOS live: cosmic-greeter waits on plymouth-quit-wait, but we ship no Plymouth
	# theme — with `splash` on the kernel cmdline the greeter never starts (black screen).
	for svc in \
		"$@.partial/usr/lib/systemd/system/cosmic-greeter.service" \
		"$@.partial/lib/systemd/system/cosmic-greeter.service" \
		"$@.partial/usr/lib/systemd/system/greetd.service" \
		"$@.partial/lib/systemd/system/greetd.service"; do \
		if [ -f "$$svc" ]; then \
			sudo sed -i 's/ plymouth-quit-wait\.service//g' "$$svc"; \
		fi; \
	done

	# Make casper script for initial setup set the version
	if [ -n "$(GNOME_INITIAL_SETUP_STAMP)" ]; then \
		sudo sed -i \
		's|touch /root/home/$$USERNAME/.config/gnome-initial-setup-done|echo -n "$(GNOME_INITIAL_SETUP_STAMP)" > /root/home/$$USERNAME/.config/gnome-initial-setup-done|' \
		"$@.partial/usr/share/initramfs-tools/scripts/casper-bottom/52gnome_initial_setup"; \
	fi

	# Update apt cache
	sudo $(CHROOT) "$@.partial" /usr/bin/apt-get update

	# Update appstream cache
	if [ -e "$@.partial/usr/bin/appstreamcli" ]; then \
		sudo $(CHROOT) "$@.partial" /usr/bin/appstreamcli refresh-cache --force; \
	fi

	# Update fwupd cache (best-effort: chroot may be offline during ISO build)
	if [ -e "$@.partial/usr/bin/fwupdtool" ]; then \
		sudo $(CHROOT) "$@.partial" /usr/bin/fwupdtool refresh --force || true; \
	fi

	# Run console-setup script
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"/iso/console-setup.sh"

	# Create missing network-manager file
	if [ -e "$@.partial/etc/NetworkManager/conf.d" ]; then \
		sudo touch "$@.partial/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"; \
	fi

	# Unmount chroot
	if [ -n "$(SORYOS_APT_CHROOT_MOUNT)" ] && mountpoint -q "$@.partial$(SORYOS_APT_CHROOT_MOUNT)" 2>/dev/null; then \
		sudo umount "$@.partial$(SORYOS_APT_CHROOT_MOUNT)"; \
	fi
	"scripts/unmount.sh" "$@.partial"

	sudo rm -rf "$@.partial"/root/.launchpadlib

	# Remove temp directory for modifications
	sudo rm -rf "$@.partial/iso"

	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"

$(BUILD)/live.tag: $(BUILD)/live
	sudo $(CHROOT) "$<" /bin/bash -e -c "dpkg-query -W --showformat='\$${Package}\t\$${Version}\n'" > "$@"

ifeq ($(strip $(MAIN_POOL) $(RESTRICTED_POOL) $(POOL_PKGS)),)
$(BUILD)/pool: $(BUILD)/chroot
	mkdir -p "$@/pool"
	touch "$@"
else
$(BUILD)/pool: $(BUILD)/chroot
	# Unmount chroot if mounted
	scripts/unmount.sh "$@.partial"

	# Remove old chroot
	sudo rm -rf "$@" "$@.partial"

	# Copy chroot
	sudo cp -a "$<" "$@.partial"

	# Make temp directory for modifications
	sudo rm -rf "$@.partial/iso"
	sudo mkdir -p "$@.partial/iso"

	# Create pool directory
	sudo mkdir -p "$@.partial/iso/pool"

	# Copy chroot script
	sudo cp "scripts/chroot.sh" "$@.partial/iso/chroot.sh"

	# Mount chroot
	"scripts/mount.sh" "$@.partial"

	# Run chroot script
	sudo $(CHROOT) "$@.partial" /bin/bash -e -c \
		"MAIN_POOL=\"$(MAIN_POOL)\" \
		RESTRICTED_POOL=\"$(RESTRICTED_POOL)\" \
		INSTALL=\"$(POOL_PKGS)\" \
		CLEAN=1 \
		/iso/chroot.sh"

	# Unmount chroot
	"scripts/unmount.sh" "$@.partial"

	sudo rm -rf "$@.partial"/root/.launchpadlib

	# Save package pool
	sudo mv "$@.partial/iso/pool" "$@.partial/pool"

	# Remove temp directory for modifications
	sudo rm -rf "$@.partial/iso"

	sudo touch "$@.partial"
	sudo mv "$@.partial" "$@"

endif
