#!/usr/bin/env bash
# reinstalar-en-mint.sh — reinstala los programas de MartOS en un Linux Mint recién instalado
#                         (base Ubuntu 24.04 "noble"; inventario hecho el 2026-10-09)
#
# Ejecútalo como TU usuario (no con sudo); pedirá la contraseña cuando haga falta:
#     bash ~/.config/MartOS/instalacion/reinstalar-en-mint.sh            # todo
#     bash ~/.config/MartOS/instalacion/reinstalar-en-mint.sh conda r    # solo esas secciones
#
# Secciones (en este orden): apt repos nvidia flatpak debs compilados usuario conda r
#
# No se detiene si algo falla: lo apunta y sigue. Al final muestra (y guarda en
# ~/reinstalacion-mint-<fecha>-FALLOS.txt) la lista de lo que NO se instaló, con el
# motivo y cómo instalarlo a mano. El registro completo queda en ~/reinstalacion-mint-<fecha>.log
#
# Excluido a propósito: eww (y sus dependencias gtk-layer-shell/dbusmenu), los paquetes
# meta de Ubuntu (ubuntu-desktop…), kernel/grub/shim (Mint trae los suyos) y snap.
#
# Variables opcionales:
#     DEB_DIR=/ruta   carpeta con los .deb de RStudio y del Configurador FNMT (por defecto ~/Instaladores)
#     SRC_DIR=/ruta   dónde clonar los programas que se compilan (por defecto ~/Instaladores)

set -uo pipefail

INSTALACION="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
DEB_DIR="${DEB_DIR:-$HOME/Instaladores}"
SRC_DIR="${SRC_DIR:-$HOME/Instaladores}"
CONDA_DIR=/opt/miniconda3
FECHA="$(date +%Y%m%d-%H%M)"
LOG="$HOME/reinstalacion-mint-$FECHA.log"
INFORME="$HOME/reinstalacion-mint-$FECHA-FALLOS.txt"

if [ -t 1 ]; then
    R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1;34m'; N=$'\e[0m'
else
    R=; G=; Y=; B=; N=
fi

info() { printf '\n%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '%s  ✓%s %s\n' "$G" "$N" "$*"; }
mal()  { printf '%s  ✗%s %s\n' "$R" "$N" "$*"; }

[ "$(id -u)" -ne 0 ] || { echo "Ejecútalo como tu usuario, sin sudo." >&2; exit 1; }

# Todo lo que se imprime va también al log
exec > >(tee -a "$LOG") 2>&1

# ── Registro de fallos ────────────────────────────────────────────────────────
# Cada entrada: categoría | nombre | motivo | cómo instalarlo a mano
FALLOS=()
fallo() {
    FALLOS+=("$1|$2|$3|$4")
    mal "$2 — $3"
}
# Instalaciones que siempre son manuales (no se pueden automatizar)
MANUALES=()

# Ejecuta un comando; si falla, lo registra.  uso: intentar <cat> <nombre> <cómo-a-mano> -- cmd...
intentar() {
    local cat="$1" nombre="$2" manual="$3"; shift 4
    if "$@"; then ok "$nombre"; return 0; fi
    fallo "$cat" "$nombre" "el comando falló (ver $LOG)" "$manual"
    return 1
}

instalado() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }

# Instala paquetes apt; los que no existan o fallen quedan registrados.
apt_instalar() {
    local cat="$1"; shift
    local disponibles=() p
    for p in "$@"; do
        if instalado "$p"; then ok "$p (ya estaba)"; continue; fi
        if apt-cache show "$p" >/dev/null 2>&1; then
            disponibles+=("$p")
        else
            fallo "$cat" "$p" "no existe en los repositorios de este sistema" \
                  "buscar un nombre alternativo: apt search $p"
        fi
    done
    [ ${#disponibles[@]} -eq 0 ] && return 0
    # Primero todos juntos (rápido); si falla, uno a uno para aislar el culpable
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${disponibles[@]}" ||
        for p in "${disponibles[@]}"; do
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p"
        done
    for p in "${disponibles[@]}"; do
        if instalado "$p"; then ok "$p"
        else fallo "$cat" "$p" "apt no pudo instalarlo (ver $LOG)" "sudo apt install $p"
        fi
    done
}

# Codename de Ubuntu sobre el que está basado Mint (Mint 22.x → noble)
. /etc/os-release
BASE="${UBUNTU_CODENAME:-$VERSION_CODENAME}"

# ── Secciones ─────────────────────────────────────────────────────────────────

sec_apt() {
    info "Actualizando el sistema"
    sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

    info "Paquetes de los repositorios de Ubuntu/Mint"
    apt_instalar "apt" \
        build-essential cmake git curl wget ca-certificates gpg software-properties-common \
        tmux tree jq fd-find chafa jp2a imagemagick gparted testdisk \
        openssh-server mailutils ssmtp \
        lm-sensors s-tui stress-ng smartmontools nvme-cli msr-tools dmidecode glmark2-x11 \
        exfatprogs exfat-fuse ntfs-3g cryptsetup lvm2 efibootmgr dkms systemd-zram-generator \
        adb fastboot flatpak \
        python3 python3-pip python3-venv python3-dev python3-setuptools python3-click \
        python3-gi python3-gi-cairo python3-cairo python3-netifaces python3-pydbus python3-tomlkit \
        libgirepository-2.0-dev libclang-dev \
        neofetch cmatrix sl oneko

    info "Librerías de desarrollo que necesitan los paquetes de R"
    apt_instalar "apt" \
        libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libfreetype-dev \
        libharfbuzz-dev libfribidi-dev libpng-dev libjpeg-dev libtiff5-dev libcairo2-dev \
        libgdal-dev libgeos-dev libproj-dev libudunits2-dev libabsl-dev libnode-dev
}

# Añade un repositorio de terceros y luego instala sus paquetes.
# uso: repo <nombre> <cómo-a-mano> <función-que-añade-el-repo> paquetes...
repo() {
    local nombre="$1" manual="$2" anadir="$3"; shift 3
    info "$nombre"
    if ! "$anadir"; then
        fallo "repos" "$nombre" "no se pudo añadir el repositorio" "$manual"
        return
    fi
    sudo apt-get update
    apt_instalar "repos" "$@"
}

repo_brave() {
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg &&
    sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources \
        https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
}
repo_vscode() {
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor |
        sudo tee /usr/share/keyrings/microsoft.gpg >/dev/null &&
    printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64\nSigned-By: /usr/share/keyrings/microsoft.gpg\n' |
        sudo tee /etc/apt/sources.list.d/vscode.sources >/dev/null
}
repo_docker() {
    sudo install -m 0755 -d /etc/apt/keyrings &&
    sudo curl -fsSLo /etc/apt/keyrings/docker.asc https://download.docker.com/linux/ubuntu/gpg &&
    printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$BASE" |
        sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
}
repo_cran() {
    curl -fsSL https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | gpg --dearmor |
        sudo tee /usr/share/keyrings/r-project.gpg >/dev/null &&
    echo "deb [signed-by=/usr/share/keyrings/r-project.gpg] https://cloud.r-project.org/bin/linux/ubuntu $BASE-cran40/" |
        sudo tee /etc/apt/sources.list.d/r-project.list >/dev/null
}
repo_spotify() {
    # La URL de la clave cambia con los años: si falla, mira https://www.spotify.com/es/download/linux/
    curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | gpg --dearmor |
        sudo tee /usr/share/keyrings/spotify.gpg >/dev/null &&
    echo "deb [signed-by=/usr/share/keyrings/spotify.gpg] https://repository.spotify.com stable non-free" |
        sudo tee /etc/apt/sources.list.d/spotify.list >/dev/null
}
repo_tailscale() {
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$BASE.noarmor.gpg" |
        sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null &&
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/$BASE.tailscale-keyring.list" |
        sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
}
repo_fastfetch() { sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch; }
repo_gh() {
    sudo install -m 0755 -d /etc/apt/keyrings &&
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
        sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
        sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
}

sec_repos() {
    repo "Brave"        "https://brave.com/linux/"                         repo_brave     brave-browser
    repo "VS Code"      "https://code.visualstudio.com/docs/setup/linux"   repo_vscode    code
    repo "Docker"       "https://docs.docker.com/engine/install/ubuntu/"   repo_docker \
         docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    repo "R (CRAN)"     "https://cran.r-project.org/bin/linux/ubuntu/"     repo_cran      r-base r-base-dev
    repo "Spotify"      "https://www.spotify.com/es/download/linux/ (o: flatpak install flathub com.spotify.Client)" \
                                                                           repo_spotify   spotify-client
    repo "Tailscale"    "curl -fsSL https://tailscale.com/install.sh | sh" repo_tailscale tailscale
    repo "fastfetch"    "https://github.com/fastfetch-cli/fastfetch/releases (.deb)" \
                                                                           repo_fastfetch fastfetch
    repo "GitHub CLI"   "https://github.com/cli/cli/blob/trunk/docs/install_linux.md" \
                                                                           repo_gh        gh

    if instalado docker-ce && ! id -nG | grep -qw docker; then
        sudo usermod -aG docker "$USER" && ok "usuario añadido al grupo docker (efectivo al volver a iniciar sesión)"
    fi
}

sec_nvidia() {
    info "Driver NVIDIA 580 (open)"
    apt_instalar "nvidia" nvidia-driver-580-open
    instalado nvidia-driver-580-open ||
        MANUALES+=("Driver NVIDIA|si el paquete falló, usa Menú → Gestor de controladores y elige la versión 580 'open'")
}

sec_flatpak() {
    info "Flatpak (Flathub)"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    local app
    for app in com.discordapp.Discord com.stremio.Stremio org.mozilla.thunderbird_esr org.upscayl.Upscayl; do
        if flatpak info "$app" >/dev/null 2>&1; then ok "$app (ya estaba)"; continue; fi
        intentar "flatpak" "$app" "flatpak install flathub $app" -- \
            flatpak install -y --noninteractive flathub "$app"
    done
}

# Instala el .deb más reciente que coincida con el patrón dentro de DEB_DIR
deb_local() {
    local nombre="$1" patron="$2" paquete="$3" manual="$4" deb
    info "$nombre"
    if instalado "$paquete"; then ok "$nombre (ya estaba)"; return; fi
    deb="$(ls -1 "$DEB_DIR"/$patron 2>/dev/null | sort -V | tail -1)"
    if [ -z "$deb" ]; then
        fallo "debs" "$nombre" "no hay ningún $patron en $DEB_DIR" "$manual"
        return
    fi
    sudo apt-get install -y "$deb"
    instalado "$paquete" && ok "$nombre ($(basename "$deb"))" ||
        fallo "debs" "$nombre" "falló la instalación de $(basename "$deb")" "$manual"
}

sec_debs() {
    deb_local "RStudio"            "rstudio-*-amd64.deb"         rstudio \
              "descarga el .deb para Ubuntu 24 en https://posit.co/download/rstudio-desktop/"
    deb_local "Configurador FNMT"  "configuradorfnmt_*amd64.deb" configuradorfnmt \
              "https://www.sede.fnmt.gob.es/descargas/descarga-software/instalacion-software-generacion-de-claves"
    MANUALES+=("AutoFirma|descomprime Autofirma_Linux_Debian.zip (en ~/Instaladores) e instala el .deb: sudo apt install ./autofirma*.deb — o descárgalo de https://firmaelectronica.gob.es/Home/Descargas.html")
}

# Clona (o actualiza) un repositorio en SRC_DIR y ejecuta la instalación dentro
compilar() {
    local nombre="$1" url="$2" manual="$3"; shift 3
    local dir="$SRC_DIR/$(basename "$url" .git)"
    info "$nombre"
    mkdir -p "$SRC_DIR"
    if [ -d "$dir/.git" ]; then git -C "$dir" pull --ff-only
    elif ! git clone "$url" "$dir"; then
        fallo "compilados" "$nombre" "no se pudo clonar $url" "$manual"; return
    fi
    if (cd "$dir" && "$@"); then ok "$nombre"
    else fallo "compilados" "$nombre" "falló la instalación (ver $LOG)" "$manual"
    fi
}

sec_compilados() {
    compilar "auto-cpufreq" https://github.com/AdnanHodzic/auto-cpufreq.git \
        "cd $SRC_DIR/auto-cpufreq && sudo ./auto-cpufreq-installer && sudo auto-cpufreq --install" \
        bash -c 'sudo ./auto-cpufreq-installer --install && sudo auto-cpufreq --install'
    # Evita conflictos con auto-cpufreq (en Mint puede no existir: no es un error)
    sudo systemctl mask power-profiles-daemon.service 2>/dev/null || true

    compilar "intel-undervolt" https://github.com/kitsunyan/intel-undervolt.git \
        "cd $SRC_DIR/intel-undervolt && ./configure --enable-systemd && make && sudo make install" \
        bash -c './configure --enable-systemd && make && sudo make install && sudo systemctl enable intel-undervolt.service'

    compilar "omen-rgb-keyboard (DKMS)" https://github.com/OmenLinux/omen-rgb-keyboard.git \
        "cd $SRC_DIR/omen-rgb-keyboard && sudo ./install.sh" \
        sudo ./install.sh

    # omen-fand2 y omen-fan-restore NO se compilan: los copia `sudo martos restaurar-sistema`
}

sec_usuario() {
    info "Rust (rustup)"
    if [ -x "$HOME/.cargo/bin/rustup" ]; then ok "rustup (ya estaba)"
    else
        intentar "usuario" "Rust (rustup)" "curl --proto '=https' -sSf https://sh.rustup.rs | sh" -- \
            bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
    fi

    info "Claude Code"
    if [ -x "$HOME/.local/bin/claude" ]; then ok "claude (ya estaba)"
    else
        intentar "usuario" "Claude Code" "curl -fsSL https://claude.ai/install.sh | bash" -- \
            bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
    fi

    info "Miniconda en $CONDA_DIR"
    if [ -x "$CONDA_DIR/bin/conda" ]; then ok "Miniconda (ya estaba)"
    else
        local sh="$SRC_DIR/Miniconda3-latest-Linux-x86_64.sh"
        mkdir -p "$SRC_DIR"
        intentar "usuario" "Miniconda" \
            "descarga https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh y: sudo bash Miniconda3-latest-Linux-x86_64.sh -b -p $CONDA_DIR && sudo chown -R $USER: $CONDA_DIR" -- \
            bash -c "curl -fsSLo '$sh' https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh &&
                     sudo mkdir -p '$CONDA_DIR' && sudo chown '$USER:' '$CONDA_DIR' &&
                     bash '$sh' -b -u -p '$CONDA_DIR'"
    fi
    # .bashrc de MartOS ya inicializa conda desde /opt/miniconda3 (martos restaurar-usuario)
}

sec_conda() {
    info "Entornos conda (desde $INSTALACION/conda)"
    local conda="$CONDA_DIR/bin/conda"
    if [ ! -x "$conda" ]; then
        local yml
        for yml in "$INSTALACION"/conda/*.yml; do
            case "$yml" in *.completo.yml) continue ;; esac
            fallo "conda" "$(basename "$yml" .yml)" "Miniconda no está instalado" \
                  "instala Miniconda y luego: conda env create -f $yml"
        done
        return
    fi
    # Conda nuevo exige aceptar los términos de los canales de Anaconda
    "$conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main >/dev/null 2>&1
    "$conda" tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r    >/dev/null 2>&1

    local yml env completo pipreq
    for yml in "$INSTALACION"/conda/*.yml; do
        case "$yml" in *.completo.yml) continue ;; esac
        env="$(basename "$yml" .yml)"
        completo="$INSTALACION/conda/$env.completo.yml"
        if "$conda" env list | awk '{print $1}' | grep -qx "$env"; then ok "$env (ya estaba)"; continue; fi

        printf '  … creando %s\n' "$env"
        # 1º: lo que pediste explícitamente (versiones nuevas compatibles)
        # 2º: si no resuelve, la copia exacta de versiones que tenías
        if "$conda" env create -y -f "$yml"; then
            ok "$env"
        elif "$conda" env remove -y -n "$env" >/dev/null 2>&1; "$conda" env create -y -f "$completo"; then
            ok "$env (con las versiones exactas de $env.completo.yml)"
            continue   # la copia exacta ya incluye los paquetes pip
        else
            "$conda" env remove -y -n "$env" >/dev/null 2>&1
            fallo "conda" "$env" "conda no pudo resolver el entorno (ni el mínimo ni el exacto)" \
                  "conda env create -f $yml   (o $completo); revisa el error en $LOG"
            continue
        fi

        # Paquetes pip (el export mínimo no los recoge): se instalan desde la copia exacta
        if grep -q -- '- pip:' "$completo"; then
            pipreq="$(mktemp)"
            awk '/- pip:/{p=1;next} p&&/^      - /{sub(/^      - /,"");print;next} p{p=0}' "$completo" > "$pipreq"
            if "$conda" run -n "$env" python -m pip install -r "$pipreq" \
                   --extra-index-url https://download.pytorch.org/whl/cu128; then
                ok "$env: paquetes pip"
            else
                fallo "conda" "$env (pip)" "fallaron los paquetes pip" \
                      "conda activate $env && pip install <paquetes de la sección pip: de $completo>"
            fi
            rm -f "$pipreq"
        fi
    done
}

sec_r() {
    info "Paquetes de R (desde $INSTALACION/R-paquetes.txt)"
    if ! command -v Rscript >/dev/null; then
        fallo "r" "paquetes de R" "R no está instalado" "instala r-base y vuelve a ejecutar: $0 r"
        return
    fi
    local faltan
    faltan="$(mktemp)"
    # CRAN primero; lo que quede, por Bioconductor; escribe los que siguen faltando
    Rscript --vanilla - "$INSTALACION/R-paquetes.txt" "$faltan" <<'EOF'
args <- commandArgs(trailingOnly = TRUE)
lib <- Sys.getenv("R_LIBS_USER"); lib <- path.expand(lib)
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
options(repos = c(CRAN = "https://cloud.r-project.org"), Ncpus = parallel::detectCores())
quieres <- readLines(args[1])
pendientes <- function() setdiff(quieres, rownames(installed.packages()))
p <- pendientes()
if (length(p)) try(install.packages(p, lib = lib))
p <- pendientes()
if (length(p)) {
  if (!requireNamespace("BiocManager", quietly = TRUE)) try(install.packages("BiocManager", lib = lib))
  if (requireNamespace("BiocManager", quietly = TRUE))
    try(BiocManager::install(p, lib = lib, update = FALSE, ask = FALSE))
}
writeLines(pendientes(), args[2])
EOF
    local n p
    n="$(grep -c . "$faltan")"
    if [ "$n" -eq 0 ]; then ok "todos los paquetes de R ($(wc -l < "$INSTALACION/R-paquetes.txt"))"
    else
        while read -r p; do
            [ -n "$p" ] && fallo "r" "$p" "no está en CRAN ni Bioconductor, o falló al compilar" \
                "en R: install.packages('$p')  — si es de GitHub: remotes::install_github('autor/$p')"
        done < "$faltan"
    fi
    rm -f "$faltan"
}

# ── Informe final ─────────────────────────────────────────────────────────────

informe() {
    {
        echo "Reinstalación MartOS en $(. /etc/os-release; echo "$PRETTY_NAME") — $(date '+%F %R')"
        echo "Registro completo: $LOG"
        echo
        if [ ${#FALLOS[@]} -eq 0 ]; then
            echo "✓ Todo lo automatizable se instaló correctamente."
        else
            echo "✗ NO SE INSTALARON (${#FALLOS[@]}) — instálalos a mano:"
            local cat_ant="" e cat nombre motivo manual
            for e in "${FALLOS[@]}"; do
                IFS='|' read -r cat nombre motivo manual <<<"$e"
                [ "$cat" != "$cat_ant" ] && { echo; echo "[$cat]"; cat_ant="$cat"; }
                echo "  • $nombre"
                echo "      motivo:  $motivo"
                echo "      a mano:  $manual"
            done
        fi
        if [ ${#MANUALES[@]} -gt 0 ]; then
            echo
            echo "SIEMPRE MANUALES (no se pueden automatizar):"
            local e nombre como
            for e in "${MANUALES[@]}"; do
                IFS='|' read -r nombre como <<<"$e"
                echo "  • $nombre: $como"
            done
        fi
        echo
        echo "SIGUIENTES PASOS:"
        echo "  1. sudo martos restaurar-sistema   (ventiladores, undervolt, NVIDIA, zram…)"
        echo "  2. martos restaurar-usuario         (bash)"
        echo "  3. Recupera ~/.config/env (claves) desde tu gestor de contraseñas"
        echo "  4. Añade /data a /etc/fstab (ver INFORME.md §4) y reinicia"
    } | tee "$INFORME"
    echo
    echo "Informe guardado en: $INFORME"
}

# ── Principal ─────────────────────────────────────────────────────────────────

TODAS=(apt repos nvidia flatpak debs compilados usuario conda r)
SECCIONES=("$@")
[ ${#SECCIONES[@]} -eq 0 ] && SECCIONES=("${TODAS[@]}")

for s in "${SECCIONES[@]}"; do
    declare -F "sec_$s" >/dev/null || { echo "Sección desconocida: $s (válidas: ${TODAS[*]})" >&2; exit 1; }
done

echo "MartOS → $PRETTY_NAME (base Ubuntu: $BASE) — secciones: ${SECCIONES[*]}"
sudo -v || exit 1
# Mantiene sudo vivo mientras dura el script (conda y R pueden tardar mucho)
while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &

for s in "${SECCIONES[@]}"; do "sec_$s"; done
informe
