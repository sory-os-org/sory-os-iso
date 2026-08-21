#!/usr/bin/env bash
# Patch casper-bottom hooks for SoryOS live ISO (no pool on CD, minimal GNOME stack).
set -euo pipefail

CASPER_BOTTOM="${1:?casper-bottom directory}"

rm -f "$CASPER_BOTTOM/41apt_cdrom"

for script in 52gnome_initial_setup 59disable_mozc_autosetup; do
	if [ -f "$CASPER_BOTTOM/$script" ]; then
		sed -i 's/$USERNAME\.$USERNAME/$USERNAME:$USERNAME/g' "$CASPER_BOTTOM/$script"
	fi
done

if [ -f "$CASPER_BOTTOM/53disable_unattended_upgrades" ]; then
	sed -i \
		's|^if grep -q|if [ -f /root/etc/apt/apt.conf.d/50unattended-upgrades ] \&\& grep -q|' \
		"$CASPER_BOTTOM/53disable_unattended_upgrades"
fi

if [ -f "$CASPER_BOTTOM/31disable_update_notifier" ]; then
	sed -i \
		'/^log_begin_msg/a\
mkdir -p /root/usr/lib/update-notifier /root/usr/lib/ubuntu-release-upgrader' \
		"$CASPER_BOTTOM/31disable_update_notifier"
fi
