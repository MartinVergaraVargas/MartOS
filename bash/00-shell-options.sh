# ~/.config/MartOS/bash/00-shell-options.sh
# Opciones de shell y utilidades varias

shopt -s checkwinsize         # actualizar LINES/COLUMNS tras cada comando
#shopt -s globstar            # ** expande recursivamente (descomenta si lo quieres)

umask 002

# less más amigable con ficheros que no son texto
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
