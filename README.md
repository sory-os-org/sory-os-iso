# SoryOS ISO (24.04 amd64)

Chaîne de construction de l’ISO live SoryOS, dérivée de Pop!_OS ISO, alimentée par les `.deb`
publiés sur **GitHub Releases** (`sory-os-org/sory-os-apt`) et le catalogue **GitHub Pages**.

## Prérequis

```bash
./deps.sh
gpg --recv-keys 204DD8AEC33A7AFF   # clé Pop archive (signatures ISO)
gpg --full-gen-key                 # clé locale pour signer l’ISO
```

## Build

```bash
cd /home/sory/Bureau/sory-os/sory-os/iso
make DISTRO_CODE=soryos iso
```

Sortie : `build/soryos/24.04/amd64/soryos_24.04_amd64.iso`

> **Important** : utiliser `DISTRO_CODE=soryos`, pas `CONFIG=soryos/24.04`.  
> Il n’existe pas de cible `make live` — `make iso` reconstruit `live` si nécessaire.

Tag Release des `.deb` (défaut dans `config/soryos/24.04.mk`) :

```bash
make DISTRO_CODE=soryos iso SORYOS_RELEASE_TAG='soryos-deb-test-2026.08.13'
```

## Rebuild après changement boot / casper / greeter

```bash
make DISTRO_CODE=soryos clean-live
sudo rm -rf build/soryos/24.04/amd64/iso \
           build/soryos/24.04/amd64/grub \
           build/soryos/24.04/amd64/iso_*.tag \
           build/soryos/24.04/amd64/*.iso \
           build/soryos/24.04/amd64/live.tag
make DISTRO_CODE=soryos iso
```

## Test QEMU

```bash
make DISTRO_CODE=soryos qemu          # UEFI (pflash OVMF 4M — Ubuntu 24.04)
make DISTRO_CODE=soryos efi=no qemu   # BIOS / ISOLINUX
```

Sur machine **faible RAM** (~4 Go), QEMU peut geler ; préférer le test USB réel.

## Test USB / disque externe

L’ISO est **hybrid** (BIOS + UEFI). Écriture sur clé USB :

```bash
lsblk   # confirmer le disque USB (ex. /dev/sdb) — NE PAS toucher /dev/sda
sudo umount /dev/sdb1 2>/dev/null || true
sudo dd if=build/soryos/24.04/amd64/soryos_24.04_amd64.iso of=/dev/sdb bs=4M status=progress conv=fsync
sudo sync
```

Boot : menu UEFI → clé USB.

## Boot live — correctifs appliqués

### Écran noir (cause)

`quiet splash` + absence de thème Plymouth + `cosmic-greeter` qui attend
`plymouth-quit-wait.service` → greeter jamais lancé.

### Correctifs

| Composant | Fix |
|-----------|-----|
| Kernel cmdline | `noplymouth` dans `config/soryos/24.04.mk` |
| systemd | retrait `plymouth-quit-wait` dans `cosmic-greeter.service` / `greetd.service` (`mk/chroot.mk`) |
| casper initramfs | `scripts/soryos-patch-casper-bottom.sh` (sans `41apt_cdrom`, chown, etc.) |
| QEMU | `virtio-vga`, OVMF pflash, `-smp 2` (`mk/qemu.mk`) |

Vérification :

```bash
grep append build/soryos/24.04/amd64/iso/isolinux/isolinux.cfg
# → noplymouth
```

## Configuration

| Fichier | Rôle |
|---------|------|
| `config/soryos/24.04.mk` | Paquets live, pool, Pages/Release URLs |
| `mk/chroot.mk` | chroot, live, patches casper/greeter |
| `mk/iso.mk` | squashfs, xorriso hybrid |
| `scripts/soryos-release-pool.sh` | Télécharge pool depuis Pages + Release |

## Nettoyage

```bash
make DISTRO_CODE=soryos clean-live   # live seulement
make DISTRO_CODE=soryos clean        # garde debootstrap/chroot
make DISTRO_CODE=soryos distclean    # tout
```

## Documentation liée

- Mémoire agent : `../.cursor/PROJECT_MEMORY.md`
- Modèle APT/Pages/ISO : `../sory-os-apt/docs/RELEASES-PAGES-ISO-MODEL.md`
- Plan boot détaillé : `../../docs-plans/SORYOS-ISO-LIVE-BOOT.md`
- **Revue complète (à relire un autre jour)** : `../../docs-plans/REVISION-COMPLETE-ISO-APT-2026-08-21.md`
