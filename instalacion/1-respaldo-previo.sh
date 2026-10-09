#!/usr/bin/env bash
# 1-respaldo-previo.sh — PASO 1, en UBUNTU, antes de formatear.
#
# Copia al disco externo todo lo que no se puede reinstalar:
#   DEST/home/           tu carpeta personal (sin cachés, Papelera ni toolchains reinstalables)
#   DEST/Tricho-PGPT/    /srv/TFM  (ya con su nombre nuevo)
#   DEST/biodata/        /srv/biodata
#   DEST/secretos.tar.gpg   ~/.config/env, ~/.ssh, ~/.gnupg y /etc completo (contraseñas Wi-Fi…),
#                           cifrado con una contraseña que eliges al ejecutarlo
#
# Uso:  bash 1-respaldo-previo.sh [DEST]
#       (por defecto DEST=/media/nesus/Respaldos/Migracion-Mint)
# Se puede repetir: la segunda vez solo copia lo que haya cambiado.

set -euo pipefail

DEST="${1:-/media/nesus/Respaldos/Migracion-Mint}"
B=$'\e[1;34m'; Y=$'\e[33m'; R=$'\e[31m'; G=$'\e[32m'; N=$'\e[0m'
info() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
warn() { printf '%s!!%s  %s\n' "$Y" "$N" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "ejecútalo como tu usuario, sin sudo"
[ -d "$(dirname "$DEST")" ] || die "no encuentro $(dirname "$DEST"): ¿está conectado el disco externo?"

# No copiar un pipeline a medio escribir
if pgrep -af 'orchestrator.py|funannotate|spades|busco' >/dev/null; then
    pgrep -af 'orchestrator.py|funannotate|spades|busco'
    die "hay un pipeline en marcha: espera a que termine"
fi

info "Espacio necesario vs. disponible"
necesario=$(( $(du -sb --exclude=.cache "$HOME" | cut -f1) + $(du -sb /srv/TFM /srv/biodata 2>/dev/null | awk '{s+=$1} END{print s}') ))
mkdir -p "$DEST"
ya=$(du -sb "$DEST" | cut -f1)
libre=$(df -B1 --output=avail "$DEST" | tail -1)
printf '  necesario ~%s · ya copiado %s · libre %s\n' \
    "$(numfmt --to=iec "$necesario")" "$(numfmt --to=iec "$ya")" "$(numfmt --to=iec "$libre")"
[ $((necesario - ya)) -lt "$libre" ] || die "no cabe en $DEST"

RSYNC=(rsync -aHAX --info=progress2 --no-inc-recursive --delete)

info "1/4  Carpeta personal → $DEST/home"
"${RSYNC[@]}" \
    --exclude='/.cache/' --exclude='/.local/share/Trash/' \
    --exclude='/.rustup/' --exclude='/.cargo/' \
    --exclude='/Instaladores/*.iso' \
    --exclude='/.config/env' --exclude='/.ssh/' --exclude='/.gnupg/' \
    "$HOME/" "$DEST/home/"

info "2/4  /srv/TFM → $DEST/Tricho-PGPT"
"${RSYNC[@]}" /srv/TFM/ "$DEST/Tricho-PGPT/"

info "3/4  /srv/biodata → $DEST/biodata"
"${RSYNC[@]}" /srv/biodata/ "$DEST/biodata/"

info "4/4  Secretos cifrados → $DEST/secretos.tar.gpg"
sudo -v   # pide aquí la contraseña de sudo, para que no se cruce con la de gpg
echo "  Elige una contraseña para este archivo (guárdala en tu gestor de contraseñas)."
# tar devuelve 1 si algún archivo cambió mientras lo leía (normal en /etc): no es un error
( sudo tar -C / --warning=no-file-changed --warning=no-file-ignored -czf - \
      etc "${HOME#/}/.config/env" "${HOME#/}/.ssh" "${HOME#/}/.gnupg" 2>/dev/null; [ $? -le 1 ] ) |
    gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback -o "$DEST/secretos.tar.gpg.nuevo"
mv "$DEST/secretos.tar.gpg.nuevo" "$DEST/secretos.tar.gpg"

info "Comprobación: segunda pasada en seco (debería no quedar nada por copiar)"
pend=0
for par in "$HOME/|$DEST/home/" "/srv/TFM/|$DEST/Tricho-PGPT/" "/srv/biodata/|$DEST/biodata/"; do
    n=$(rsync -aHAXn --out-format='%n' --exclude='/.cache/' --exclude='/.local/share/Trash/' \
          --exclude='/.rustup/' --exclude='/.cargo/' --exclude='/Instaladores/*.iso' \
          --exclude='/.config/env' --exclude='/.ssh/' --exclude='/.gnupg/' \
          "${par%%|*}" "${par#*|}" | grep -v '/$' | wc -l)
    printf '  %-16s %s archivos pendientes\n' "${par%%|*}" "$n"
    pend=$((pend + n))
done

echo
if [ "$pend" -eq 0 ]; then printf '%s✓ Respaldo completo en %s%s\n' "$G" "$DEST" "$N"
else warn "quedan $pend archivos que cambiaron durante la copia (normal si usabas el navegador): vuelve a ejecutarlo"
fi
[ -f /media/nesus/Respaldos/env ] &&
    warn "Hay una copia SIN CIFRAR de tus claves en /media/nesus/Respaldos/env: bórrala cuando confirmes que secretos.tar.gpg se abre."
echo "Siguiente: comprueba que puedes abrirlo →  gpg -d $DEST/secretos.tar.gpg | tar -tzf - | head"
