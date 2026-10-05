# ~/.config/MartOS/bash/10-history.sh
# Configuración del historial de comandos

HISTCONTROL=ignoreboth        # sin duplicados ni líneas que empiecen por espacio
shopt -s histappend           # añadir al historial en vez de sobrescribirlo
HISTSIZE=1000
HISTFILESIZE=2000
