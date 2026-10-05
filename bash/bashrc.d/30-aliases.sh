# ──────────────────────────────────────────────────────────────────
# MartOS
# Aliases: colores en ls/grep, ll/la/l, 'alert' (notificación al acabar
# un comando largo) y blanco-teclado/verde-teclado (RGB del OMEN).
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/30-aliases.sh
# Colores de ls y aliases

# Soporte de color en ls/grep
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Aliases de ls
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# "alert" para comandos largos.  Uso:  sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Aliases propios (RGB del teclado OMEN)
# OJO: revisa los colores, parecen intercambiados (ver nota del chat).
alias blanco-teclado='echo 00FF00 | sudo tee /sys/devices/platform/omen-rgb-keyboard/rgb_zones/all > /dev/null'
alias verde-teclado='echo FFFFFF | sudo tee /sys/devices/platform/omen-rgb-keyboard/rgb_zones/all > /dev/null'

# Aliases adicionales desde ~/.bash_aliases (si existe)
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
