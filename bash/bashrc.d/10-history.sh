# ──────────────────────────────────────────────────────────────────
# MartOS
# Historial: sin duplicados ni líneas que empiecen por espacio,
# se añade (no sobrescribe) y guarda 1000 en memoria / 2000 en archivo.
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/10-history.sh
# Configuración del historial de comandos

HISTCONTROL=ignoreboth        # sin duplicados ni líneas que empiecen por espacio
shopt -s histappend           # añadir al historial en vez de sobrescribirlo
HISTSIZE=1000
HISTFILESIZE=2000
