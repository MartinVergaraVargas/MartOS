# ──────────────────────────────────────────────────────────────────
# MartOS
# Opciones de la shell: checkwinsize, umask 002 (archivos nuevos
# editables por tu grupo) y lesspipe (less abre archivos no-texto).
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/00-shell-options.sh
# Opciones de shell y utilidades varias

shopt -s checkwinsize         # actualizar LINES/COLUMNS tras cada comando
#shopt -s globstar            # ** expande recursivamente (descomenta si lo quieres)

umask 002

# less más amigable con ficheros que no son texto
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
