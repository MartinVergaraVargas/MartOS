# ──────────────────────────────────────────────────────────────────
# MartOS
# Variables de entorno: carga ~/.config/env (API keys, fuera de git),
# rutas de bioinformática (funannotate, GeneMark, eggNOG, BUSCO,
# InterProScan) y añade ~/.local/bin y Rust al PATH.
# Guía de todos los archivos: ~/.config/MartOS/INFORME.md
# ──────────────────────────────────────────────────────────────────
# ~/.bashrc.d/50-env.sh
# Variables de entorno y PATH

# Cargar variables extra si existen
[ -f ~/.config/env ] && source ~/.config/env

# Colores para warnings/errores de GCC (descomenta si lo quieres)
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# --- Bioinformática / funannotate ---
export FUNANNOTATE_DB=/srv/biodata/funannotate_db
export GENEMARK_PATH=/opt/miniconda3/envs/funannotate/bin/gmes_linux_64_4
export EGGNOG_DATA_DIR=/srv/biodata/eggnog_db
export BUSCO_LINEAGES_PATH=/srv/biodata/busco_downloads/lineages
export PATH="/srv/biodata/interproscan_db/interproscan-5.77-108.0:$PATH"
export PATH="/opt/miniconda3/envs/funannotate/bin/gmes_linux_64_4:$PATH"
#export PASAHOME=/opt/miniconda3/envs/funannotate/opt/pasa-2.5.3

# Claude Code y otros binarios locales (sin duplicar si ~/.profile ya lo añadió)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Rust (rustup). El script ya evita duplicados en PATH.
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# TMPDIR=/var/tmp se define a nivel de sistema en /etc/environment
# (ver sistema/etc/environment); no hace falta repetirlo aquí.
