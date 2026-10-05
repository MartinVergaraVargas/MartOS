#!/bin/bash
# ──────────────────────────────────────────────────────────────────
# MartOS
# Fija el límite de potencia de la GPU NVIDIA según haya cargador o no,
# con los valores de /etc/nvidia-power-limit.conf (nvidia-smi -pl).
# Logs: journalctl -t nvidia-power-limit
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
set -u

CONF=/etc/nvidia-power-limit.conf
AC_LIMIT=100
BATT_LIMIT=40
[ -r "$CONF" ] && . "$CONF"

on_ac() {
    for ps in /sys/class/power_supply/*; do
        [ "$(cat "$ps/type" 2>/dev/null)" = "Mains" ] || continue
        [ "$(cat "$ps/online" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

if on_ac; then
    LIMIT="$AC_LIMIT"
    SRC="AC"
else
    LIMIT="$BATT_LIMIT"
    SRC="bateria"
fi

# Ajusta el limite al rango que permite el driver
read -r MINW MAXW < <(nvidia-smi --query-gpu=power.min_limit,power.max_limit \
    --format=csv,noheader,nounits 2>/dev/null | tr -d ' ' | tr ',' ' ')
MINW=${MINW%.*}; MAXW=${MAXW%.*}
[ -n "${MINW:-}" ] && [ "$LIMIT" -lt "$MINW" ] && LIMIT="$MINW"
[ -n "${MAXW:-}" ] && [ "$LIMIT" -gt "$MAXW" ] && LIMIT="$MAXW"

if nvidia-smi -pl "$LIMIT" >/dev/null 2>&1; then
    logger -t nvidia-power-limit "Fuente: $SRC -> limite ${LIMIT} W"
else
    logger -t nvidia-power-limit "No se pudo fijar el limite (GPU apagada?)"
fi
