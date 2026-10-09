# MartOS

Respaldo y guía de la configuración de mi portátil **HP OMEN 16** (Intel 11.ª gen + RTX 3060),
usado para bioinformática. Empezó en Ubuntu 24.04 + GNOME y está en migración a **Linux Mint**.

Los archivos viven y se editan **en su sitio** (`/etc/…`, `~/.bashrc.d/…`). Este repositorio guarda
una copia de cada uno, una guía de qué hace cada archivo y las herramientas para restaurarlo todo
tras formatear.

## Qué incluye

| Área | Qué hace |
|---|---|
| **Ventiladores** | Daemon propio (`omen-fand2`) que escribe directamente en el Embedded Controller, con curvas distintas para corriente y batería |
| **CPU** | Undervolt permanente (`intel-undervolt`), `auto-cpufreq` y `thermald` |
| **GPU NVIDIA** | Límite de consumo, suspensión en reposo (runtime PM) y PRIME bajo demanda |
| **Memoria** | zram comprimida y ajustes de swap |
| **Bash** | `.bashrc` modular en `bash/bashrc.d/` |
| **Escritorio** | Ajustes de GNOME (dconf), fondos y temas de Plymouth |
| **Reinstalación** | Script que reinstala todos los programas (apt, repos de terceros, Flatpak, conda, R…) y **avisa de lo que no consiguió instalar** |

## Estructura

```
martos              herramienta: estado · diff · respaldar · restaurar-sistema · restaurar-usuario · gnome · plymouth
sistema/            copia de los archivos de / (misma ruta: sistema/etc/x = /etc/x)
bash/               ~/.bashrc, ~/.profile y ~/.bashrc.d/
usuario/            otros archivos de $HOME
gnome/              volcados dconf
personalizacion/    fondos y temas de Plymouth
instalacion/        scripts de reinstalación, entornos conda (.yml) y paquetes de R
INFORME.md          qué hace cada archivo, conflictos revisados y cómo restaurar
PLAN-MINT.md        plan de migración a Linux Mint (discos, cifrado, pasos)
```

## Uso

```bash
martos estado                                  # ¿hay cambios en el sistema sin respaldar?
martos respaldar                               # copia los cambios al repo → git commit && git push
sudo martos restaurar-sistema                  # tras formatear (misma distro): repo → /etc…
sudo martos restaurar-sistema --solo-hardware  # en otra distro: solo lo del hardware
martos restaurar-usuario                       # repo → ~/.bashrc…
```

## ⚠ Aviso

Está hecho para **mi** equipo concreto. Las direcciones del Embedded Controller, los valores de
undervolt y los límites de la GPU dependen del modelo exacto y de cada unidad: aplicarlos en otro
equipo puede causar inestabilidad o sobrecalentamiento. Úsalo como referencia, no como instalador.

Las claves y los datos personales **no** están aquí: se respaldan aparte y cifrados.
