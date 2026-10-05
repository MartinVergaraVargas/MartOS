# ──────────────────────────────────────────────────────────────────
# MartOS
# Prompt de dos líneas: '(entorno conda) - ~/ruta' y ' Nesus ❯'.
# Se reconstruye en cada comando (PROMPT_COMMAND).
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/60-prompt.sh
# Prompt personalizado (controla PS1 vía PROMPT_COMMAND)

__build_prompt() {
    # Entorno conda (solo si hay uno activo)
    local conda_part=""
    if [ -n "$CONDA_DEFAULT_ENV" ]; then
        conda_part="\[\e[1;37m\](${CONDA_DEFAULT_ENV})\[\e[0m\] - "
    fi

    # Primera letra del usuario en mayúscula
    local user_display="${USER^}"

    # Construcción del prompt
    PS1="\n"
    PS1+="${conda_part}"
    PS1+="\[\e[1;34m\]\w\[\e[0m\]\n"
    PS1+="\[\e[1;32;45m\] ${user_display} \[\e[0;35m\]❯\[\e[0m\] "
}

PROMPT_COMMAND=__build_prompt
