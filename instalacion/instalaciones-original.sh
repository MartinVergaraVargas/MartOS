#!/bin/bash

# 1. Actualizar sistema e instalar herramientas base
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git lm-sensors imagemagick flatpak python3-pip

# 2. Instalar Brave Browser
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
sudo curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources https://brave-browser-apt-release.s3.brave.com/brave-browser.sources
sudo apt update && sudo apt install -y brave-browser

# 3. Instalar Fastfetch (vía PPA como hiciste)
sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
sudo apt update && sudo apt install -y fastfetch

# 4. Instalar auto-cpufreq
mkdir -p ~/Instaladores
cd ~/Instaladores
git clone https://github.com/AdnanHodzic/auto-cpufreq.git
cd auto-cpufreq
sudo ./auto-cpufreq-installer
sudo auto-cpufreq --install
# Deshabilitar el demonio por defecto de GNOME para evitar conflictos
sudo systemctl mask power-profiles-daemon.service

# 5. Configurar Flatpak y Stremio
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub com.stremio.Stremio

# 6. Instalar Miniconda
cd ~/Instaladores
curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
chmod +x Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p $HOME/miniconda3
source $HOME/miniconda3/bin/activate
conda init

# 7. Configurar Conda y Entornos
#conda config --set solver libmamba
#conda config --add channels defaults
#conda config --add channels bioconda
#conda config --add channels conda-forge

# Crear entorno Flye
#conda create -n flye -y flye

# Crear entorno SqueezeMeta
#conda create -n squeezemeta -c conda-forge -c bioconda -c fpusan squeezemeta --no-channel-priority --override-channels -y

echo "Reinstalación completada. Reinicia para aplicar todos los cambios."
