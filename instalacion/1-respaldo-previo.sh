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
# Uso:  bash 1-respaldo-previo.sh [--sin-secretos | --solo-secretos] [DEST]
#       (por defecto DEST=/media/nesus/Respaldos/Migracion-Mint)
#       --sin-secretos   solo las copias grandes (no pide contraseñas: se puede dejar corriendo)
#       --solo-secretos  solo secretos.tar.gpg (pide la contraseña de sudo y la del cifrado)
# Se puede repetir: la segunda vez solo copia lo que haya cambiado.

set -euo pipefail

PARTE=todo
case "${1:-}" in
    --sin-secretos)  PARTE=datos;    shift ;;
    --solo-secretos) PARTE=secretos; shift ;;
esac
DEST="${1:-/media/nesus/Respaldos/Migracion-Mint}"
B=$'\e[1;34m'; Y=$'\e[33m'; R=$'\e[31m'; G=$'\e[32m'; N=$'\e[0m'
info() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
warn() { printf '%s!!%s  %s\n' "$Y" "$N" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "ejecútalo como tu usuario, sin sudo"
[ -d "$(dirname "$DEST")" ] || die "no encuentro $(dirname "$DEST"): ¿está conectado el disco externo?"

RSYNC=(rsync -aHAX --info=progress2 --no-inc-recursive --delete)
EXCL_HOME=(--exclude='/.cache/' --exclude='/.local/share/Trash/'
           --exclude='/.rustup/' --exclude='/.cargo/' --exclude='/Instaladores/*.iso'
           --exclude='/.config/env' --exclude='/.ssh/' --exclude='/.gnupg/')
SIN_PERMISO=0
# rsync: 23 = algún archivo no se pudo leer (permisos), 24 = archivos que desaparecieron
# durante la copia. Ninguno de los dos detiene el respaldo; cualquier otro código sí.
copiar() {
    local rc=0
    "${RSYNC[@]}" "$@" || rc=$?
    case $rc in
        0)  ;;
        23) SIN_PERMISO=1 ;;
        24) warn "algunos archivos desaparecieron mientras se copiaban (normal si estaban en uso)" ;;
        *)  die "rsync falló (código $rc) copiando $*" ;;
    esac
}

if [ "$PARTE" != secretos ]; then
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

info "1/4  Carpeta personal → $DEST/home"
copiar "${EXCL_HOME[@]}" "$HOME/" "$DEST/home/"

info "2/4  /srv/TFM → $DEST/Tricho-PGPT"
copiar /srv/TFM/ "$DEST/Tricho-PGPT/"

info "3/4  /srv/biodata → $DEST/biodata"
copiar /srv/biodata/ "$DEST/biodata/"

if [ "$SIN_PERMISO" -eq 1 ]; then
    warn "Algunos archivos no se pudieron leer sin sudo (p. ej. la base MySQL de Specify en Docker)."
    warn "Se copian en el paso de secretos:  bash $0 --solo-secretos"
fi

fi

if [ "$PARTE" != datos ]; then
info "4/4  Secretos cifrados → $DEST/secretos.tar.gpg"
sudo -v   # pide aquí la contraseña de sudo, para que no se cruce con la de gpg
echo "  Primero, con sudo, los archivos del home que tu usuario no puede leer (MySQL de Docker…):"
sudo "${RSYNC[@]}" "${EXCL_HOME[@]}" "$HOME/" "$DEST/home/" || [ $? -eq 24 ]
echo "  Elige una contraseña para este archivo (guárdala en tu gestor de contraseñas)."
# tar devuelve 1 si algún archivo cambió mientras lo leía (normal en /etc): no es un error
( sudo tar -C / --warning=no-file-changed --warning=no-file-ignored -czf - \
      etc "${HOME#/}/.config/env" "${HOME#/}/.ssh" "${HOME#/}/.gnupg" 2>/dev/null; [ $? -le 1 ] ) |
    gpg --symmetric --cipher-algo AES256 --pinentry-mode loopback -o "$DEST/secretos.tar.gpg.nuevo"
mv "$DEST/secretos.tar.gpg.nuevo" "$DEST/secretos.tar.gpg"

fi
[ "$PARTE" = secretos ] && { printf '%s✓ secretos.tar.gpg creado%s\n' "$G" "$N"; exit 0; }

info "Comprobación: segunda pasada en seco (debería no quedar nada por copiar)"
pend=0
for par in "$HOME/|$DEST/home/" "/srv/TFM/|$DEST/Tricho-PGPT/" "/srv/biodata/|$DEST/biodata/"; do
    n=$(rsync -aHAXn --out-format='%n' "${EXCL_HOME[@]}" \
          "${par%%|*}" "${par#*|}" 2>/dev/null | grep -v '/$' | wc -l || true)
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
