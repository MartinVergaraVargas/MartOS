#!/usr/bin/env bash
# 3-restaurar-datos.sh — PASO 3, en MINT, con /home ya en el Kingston.
#
# Trae del disco externo lo que guardó 1-respaldo-previo.sh:
#   home/          → ~            (sin los archivos de escritorio de Ubuntu que chocarían con Cinnamon)
#   Tricho-PGPT/   → ~/Tricho-PGPT  y reescribe dentro TODAS las rutas /srv/TFM → ~/Tricho-PGPT
#   biodata/       → /srv/biodata   (Intel; misma ruta que antes, 50-env.sh no cambia)
#
# Uso:  bash 3-restaurar-datos.sh [ORIGEN]   (por defecto /media/nesus/Respaldos/Migracion-Mint)
# Los secretos NO se restauran solos: ver el final.

set -euo pipefail

ORIGEN="${1:-/media/nesus/Respaldos/Migracion-Mint}"
TFM_VIEJO=/srv/TFM
TFM_NUEVO="$HOME/Tricho-PGPT"
B=$'\e[1;34m'; R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; N=$'\e[0m'
info() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
die()  { printf '%sERROR:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "ejecútalo como tu usuario, sin sudo"
[ -d "$ORIGEN/home" ] || die "no encuentro $ORIGEN/home: ¿está conectado el disco externo?"
if ! findmnt -no SOURCE /home | grep -q kingston-home; then
    echo "${Y}!!${N}  /home no está en el Kingston todavía (paso 2). Continúo igualmente en 10 s (Ctrl+C para parar)…"
    sleep 10
fi

sudo -v
info "1/3  Carpeta personal"
# Con sudo y --numeric-ids: hay archivos de otros usuarios (la base MySQL de Specify en Docker,
# uid 999) que tu usuario no puede leer y que deben conservar su dueño numérico.
# Fuera: lo que pertenece al escritorio GNOME de Ubuntu o lo gestiona martos restaurar-usuario
sudo rsync -aHAX --numeric-ids --info=progress2 \
    --exclude='/.config/dconf/' --exclude='/.config/autostart/' --exclude='/.config/monitors.xml' \
    --exclude='/.local/share/gnome-shell/' --exclude='/.config/gnome-session/' \
    --exclude='/.bashrc' --exclude='/.bashrc.d/' --exclude='/.profile' --exclude='/.bash_logout' \
    "$ORIGEN/home/" "$HOME/"

info "2/3  Tricho-PGPT"
rsync -aHAX --info=progress2 "$ORIGEN/Tricho-PGPT/" "$TFM_NUEVO/"
echo "  Reescribiendo $TFM_VIEJO → $TFM_NUEVO en los archivos de texto (puede tardar: lee todo el proyecto)…"
mkdir -p "$HOME/.local/state/martos"
lista="$HOME/.local/state/martos/rutas-tricho-pgpt-migradas-$(date +%F).txt"
grep -rlI --fixed-strings "$TFM_VIEJO" "$TFM_NUEVO" > "$lista" || true
tr '\n' '\0' < "$lista" | xargs -0 -r sed -i "s#$TFM_VIEJO#$TFM_NUEVO#g"
echo "  $(wc -l < "$lista") archivos modificados (lista en $lista)"
quedan="$(grep -rlI --fixed-strings "$TFM_VIEJO" "$TFM_NUEVO" | wc -l)"
if [ "$quedan" -eq 0 ]; then printf '  %s✓ ya no queda ninguna ruta %s%s\n' "$G" "$TFM_VIEJO" "$N"
else printf '  %s✗ quedan %s archivos con %s:%s grep -rlI %s %s\n' "$R" "$quedan" "$TFM_VIEJO" "$N" "$TFM_VIEJO" "$TFM_NUEVO"
fi
grep -rlI --fixed-strings "$TFM_VIEJO" "$HOME/.bashrc.d" "$HOME/Programacion" 2>/dev/null |
    sed 's/^/  ⚠ también fuera del proyecto: /' || true

info "3/3  Bases de datos → /srv/biodata"
sudo install -d -o "$USER" -g "$(id -gn)" /srv/biodata
rsync -aHAX --info=progress2 "$ORIGEN/biodata/" /srv/biodata/

echo
printf '%s✓ Datos restaurados.%s\n' "$G" "$N"
cat <<EOF
Secretos (a mano, cuando lo necesites):
  mkdir -p ~/secretos && gpg -d "$ORIGEN/secretos.tar.gpg" | tar -xzf - -C ~/secretos
  → mueve ~/secretos/home/$USER/.config/env, .ssh y .gnupg a su sitio (chmod 600 ~/.config/env, 700 ~/.ssh)
  → contraseñas Wi-Fi: ~/secretos/etc/NetworkManager/system-connections/
  → borra ~/secretos al terminar
Siguiente paso: bash ~/.config/MartOS/instalacion/reinstalar-en-mint.sh
EOF
