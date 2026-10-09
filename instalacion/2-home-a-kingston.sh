#!/usr/bin/env bash
# 2-home-a-kingston.sh — PASO 2, en MINT recién instalado (en el Intel).
#
# BORRA el disco Kingston y lo convierte en tu /home:  LUKS2 → btrfs → subvolumen @home
# Se abre solo al arrancar con un archivo de clave guardado en la raíz cifrada (una sola
# contraseña en Plymouth: la del Intel). El LUKS del Kingston también acepta tu contraseña,
# para poder abrirlo desde un USB de rescate.
#
# Uso (desde una TTY: Ctrl+Alt+F3, entra con tu usuario; así el home no cambia mientras se copia):
#   sudo bash 2-home-a-kingston.sh             # SIMULACIÓN: muestra qué haría, no toca nada
#   sudo bash 2-home-a-kingston.sh --ejecutar  # lo hace (pide escribir BORRAR)
#   sudo reboot
#   sudo bash 2-home-a-kingston.sh --limpiar   # tras comprobar que /home ya es el Kingston:
#                                              # borra el @home viejo del Intel

set -euo pipefail

NOMBRE=kingston-home                                  # nombre en /dev/mapper y en crypttab
CLAVE=/etc/cryptsetup-keys.d/$NOMBRE.key
B=$'\e[1;34m'; Y=$'\e[33m'; R=$'\e[31m'; G=$'\e[32m'; N=$'\e[0m'
info() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "necesita root: sudo bash $0 ${1:-}"
MODO="${1:-simular}"

# Disco físico de un dispositivo (atraviesa LUKS/LVM/particiones)
disco_de() { lsblk -lnso NAME,TYPE "$1" 2>/dev/null | awk '$2=="disk"{print $1; exit}'; }

# ── --limpiar ────────────────────────────────────────────────────────────────
if [ "$MODO" = --limpiar ]; then
    findmnt -no SOURCE /home | grep -q "/dev/mapper/$NOMBRE" ||
        die "/home todavía no está montado desde el Kingston (findmnt /home). ¿Reiniciaste?"
    raiz="$(findmnt -no SOURCE / | sed 's/\[.*//')"
    mkdir -p /mnt/raiz-intel
    mount -o subvolid=5 "$raiz" /mnt/raiz-intel
    trap 'umount /mnt/raiz-intel; rmdir /mnt/raiz-intel' EXIT
    [ -d /mnt/raiz-intel/@home ] || die "no hay @home en el Intel (¿ya lo borraste?)"
    du -sh /mnt/raiz-intel/@home
    read -rp "¿Borrar el @home viejo del Intel? Escribe SI: " r
    [ "$r" = SI ] || die "cancelado"
    btrfs subvolume delete /mnt/raiz-intel/@home
    printf '%s✓ Listo.%s\n' "$G" "$N"
    exit 0
fi

[ "$MODO" = simular ] || [ "$MODO" = --ejecutar ] || die "uso: $0 [--ejecutar | --limpiar]"

# ── Comprobaciones de seguridad ──────────────────────────────────────────────
info "Buscando el Kingston"
ID="$(ls /dev/disk/by-id/nvme-KINGSTON_SNV2S1000G_* 2>/dev/null | grep -v -- '-part' | grep -v '_1$' | head -1 || true)"
[ -n "$ID" ] || die "no encuentro el Kingston SNV2S1000G en /dev/disk/by-id"
DISCO="$(readlink -f "$ID")"
echo "  $ID → $DISCO"

for punto in / /boot /boot/efi; do
    src="$(findmnt -no SOURCE "$punto" | sed 's/\[.*//')" || continue
    [ "/dev/$(disco_de "$src")" != "$DISCO" ] ||
        die "$punto está en el Kingston. Mint debe arrancar entero desde el Intel (efibootmgr -v)."
done
if lsblk -no MOUNTPOINTS "$DISCO" | grep -q .; then
    lsblk "$DISCO"; die "hay algo del Kingston montado: desmóntalo primero"
fi
if pgrep -x cinnamon >/dev/null; then
    echo "${Y}!!${N}  Hay una sesión de escritorio abierta: lo ideal es cerrarla y ejecutar esto desde una TTY (Ctrl+Alt+F3)."
fi
findmnt -no SOURCE /home >/dev/null || die "/home no es un punto de montaje (se esperaba el @home del instalador)"

info "Contenido actual del Kingston (SE BORRARÁ TODO)"
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DISCO"
echo
echo "Plan:"
echo "  1. Borrar $DISCO y crear una partición única (${DISCO}p1)"
echo "  2. LUKS2 en ${DISCO}p1 con tu contraseña + archivo de clave $CLAVE"
echo "  3. btrfs (etiqueta 'home') con subvolumen @home"
echo "  4. Copiar /home actual ($(du -sh /home 2>/dev/null | cut -f1)) al nuevo @home"
echo "  5. /etc/crypttab: añadir $NOMBRE  ·  /etc/fstab: /home → Kingston (copias en *.antes-kingston)"
[ "$MODO" = simular ] && { echo; echo "Simulación: nada cambiado. Para hacerlo: sudo bash $0 --ejecutar"; exit 0; }

read -rp "Escribe BORRAR para borrar el Kingston: " r
[ "$r" = BORRAR ] || die "cancelado"

# ── 1. Particionar ──────────────────────────────────────────────────────────
info "1/5  Particionando"
wipefs -a "$DISCO"p* 2>/dev/null || true
sgdisk --zap-all "$DISCO"
sgdisk -n1:0:0 -t1:8309 -c1:home-cifrado "$DISCO"
partprobe "$DISCO"; udevadm settle
PART="${DISCO}p1"

# ── 2. LUKS + archivo de clave ──────────────────────────────────────────────
info "2/5  Cifrando (usa la MISMA contraseña que en el Intel: es la de rescate)"
cryptsetup luksFormat --type luks2 "$PART"
install -d -m 700 /etc/cryptsetup-keys.d
dd if=/dev/urandom of="$CLAVE" bs=512 count=8 status=none
chmod 400 "$CLAVE"
echo "  Ahora vuelve a escribir la contraseña para autorizar el archivo de clave:"
cryptsetup luksAddKey "$PART" "$CLAVE"
cryptsetup open --key-file "$CLAVE" "$PART" "$NOMBRE"

# ── 3. btrfs ────────────────────────────────────────────────────────────────
info "3/5  Creando btrfs y @home"
mkfs.btrfs -L home "/dev/mapper/$NOMBRE"
mkdir -p /mnt/kingston
mount "/dev/mapper/$NOMBRE" /mnt/kingston
btrfs subvolume create /mnt/kingston/@home

# ── 4. Copiar el home ───────────────────────────────────────────────────────
info "4/5  Copiando /home"
rsync -aHAXx --info=progress2 /home/ /mnt/kingston/@home/
umount /mnt/kingston; rmdir /mnt/kingston

# ── 5. crypttab + fstab ─────────────────────────────────────────────────────
info "5/5  crypttab y fstab"
LUKS_UUID="$(blkid -s UUID -o value "$PART")"
FS_UUID="$(blkid -s UUID -o value "/dev/mapper/$NOMBRE")"
cp -a /etc/crypttab /etc/crypttab.antes-kingston 2>/dev/null || touch /etc/crypttab
cp -a /etc/fstab /etc/fstab.antes-kingston
echo "$NOMBRE UUID=$LUKS_UUID $CLAVE luks,discard" >> /etc/crypttab
# Comenta la línea /home del instalador (el @home del Intel) y añade la del Kingston
awk '!/^[[:space:]]*#/ && $2=="/home" {print "# (antes del Kingston) " $0; next} {print}' \
    /etc/fstab.antes-kingston > /etc/fstab
echo "UUID=$FS_UUID /home btrfs defaults,noatime,compress=zstd:1,subvol=@home 0 0" >> /etc/fstab
systemctl daemon-reload
findmnt --verify --tab-file /etc/fstab || die "fstab con errores: restaura con  cp /etc/fstab.antes-kingston /etc/fstab"
update-initramfs -u

echo
printf '%s✓ Hecho.%s Reinicia (sudo reboot). Solo debería pedirte UNA contraseña.\n' "$G" "$N"
echo "  Después comprueba:  findmnt /home   (debe salir /dev/mapper/$NOMBRE[/@home])"
echo "  y libera el home viejo del Intel:  sudo bash $0 --limpiar"
