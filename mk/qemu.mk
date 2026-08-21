# Common flags
QEMUFLAGS=-m 4G -smp 2

# Flags per arch
ifeq ($(DISTRO_ARCH),amd64)
QEMU=qemu-system-x86_64
# virtio-vga works better than qxl for COSMIC/Wayland in QEMU
QEMUFLAGS+=-device virtio-vga
ifeq ($(efi),no)
BOOTLOADER=BIOS
else
BOOTLOADER=UEFI
OVMF_CODE_4M?=$(wildcard /usr/share/OVMF/OVMF_CODE_4M.fd)
OVMF_VARS_4M?=$(wildcard /usr/share/OVMF/OVMF_VARS_4M.fd)
OVMF_BIOS?=$(firstword $(wildcard \
	/usr/share/qemu/OVMF.fd \
	/usr/share/ovmf/OVMF.fd \
	/usr/share/OVMF/OVMF_CODE.fd))
ifneq ($(strip $(OVMF_CODE_4M) $(OVMF_VARS_4M)),)
QEMU_OVMF=$(BUILD)/OVMF_VARS.fd
QEMUFLAGS+=\
	-drive if=pflash,format=raw,unit=0,readonly=on,file=$(OVMF_CODE_4M) \
	-drive if=pflash,format=raw,unit=1,file=$(QEMU_OVMF)
else ifneq ($(strip $(OVMF_BIOS)),)
QEMUFLAGS+=-bios $(OVMF_BIOS)
else
$(error OVMF firmware not found; install the ovmf package)
endif
endif
else ifeq ($(DISTRO_ARCH),arm64)
QEMU=qemu-system-aarch64
QEMUFLAGS+=\
	-M virt \
	-vga none \
	-device virtio-gpu-pci \
	-device qemu-xhci -device usb-kbd -device usb-tablet \
	-device ich9-intel-hda -device hda-output \
	-netdev user,id=net0 -device e1000,netdev=net0
BOOTLOADER=UEFI
AAVMF_CODE?=$(firstword $(wildcard \
	/usr/share/AAVMF/AAVMF_CODE.fd \
	/usr/share/AAVMF/AAVMF_CODE_4M.fd))
ifeq ($(strip $(AAVMF_CODE)),)
$(error AAVMF firmware not found; install the ovmf package)
endif
QEMUFLAGS+=-bios $(AAVMF_CODE)
else
$(error unknown DISTRO_ARCH $(DISTRO_ARCH))
endif

# Enable KVM if host arch matches distro arch
ifeq ($(DISTRO_ARCH),$(shell dpkg --print-architecture))
	QEMUFLAGS+=-enable-kvm -cpu host
else
	QEMUFLAGS+=-cpu max
endif

$(BUILD)/%.img:
	mkdir -p $(BUILD)
	qemu-img create -f qcow2 "$@.partial" 64G
	mv "$@.partial" "$@"

$(BUILD)/OVMF_VARS.fd:
	@test -n "$(OVMF_VARS_4M)" || (echo "OVMF_VARS template not found" >&2; exit 1)
	cp "$(OVMF_VARS_4M)" "$@"

qemu: $(ISO) $(BUILD)/qemu.img $(QEMU_OVMF)
	$(QEMU) $(QEMUFLAGS) \
		-name "$(DISTRO_NAME) $(DISTRO_VERSION) $(DISTRO_ARCH) $(BOOTLOADER) ISO" \
		-hda $(BUILD)/qemu.img \
		-boot d -cdrom "$<"

qemu_hd: $(BUILD)/qemu.img $(QEMU_OVMF)
	$(QEMU) $(QEMUFLAGS) \
		-name "$(DISTRO_NAME) $(DISTRO_VERSION) $(DISTRO_ARCH) $(BOOTLOADER) HD" \
		-hda $(BUILD)/qemu.img

qemu_usb: $(ISO) $(BUILD)/qemu.img $(QEMU_OVMF)
	$(QEMU) $(QEMUFLAGS) \
		-name "$(DISTRO_NAME) $(DISTRO_VERSION) $(DISTRO_ARCH) $(BOOTLOADER) USB" \
		-hda $(BUILD)/qemu.img \
		-boot d -drive if=none,id=img,file="$<" \
		-device nec-usb-xhci,id=xhci \
		-device usb-storage,bus=xhci.0,drive=img
