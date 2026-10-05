# ──────────────────────────────────────────────────────────────────
# MartOS
# Activa el autocompletado de bash (tabulador) del paquete bash-completion.
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/20-completion.sh
# Autocompletado programable

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
