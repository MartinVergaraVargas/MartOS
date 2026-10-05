# MartOS — Informe de configuración

Equipo: **HP OMEN 16-b0xxx** (i7-11800H Tiger Lake + RTX 3060 Mobile), Ubuntu 24.04 LTS, GNOME.
Repositorio: `~/.config/MartOS` · Gestor: `./martos` (ver `./martos ayuda`).

---

## 1. Cómo funciona este repositorio

| Carpeta | Qué contiene | Cómo llega al sistema |
|---|---|---|
| `sistema/` | Réplica de `/` con **solo** los archivos que hemos tocado (`etc/…`, `usr/local/bin/…`) | `sudo ./martos sistema` los **copia** con dueño root, guardando antes lo que sobrescribe en `/var/backups/martos/<fecha>/` |
| `usuario/` | Réplica de `$HOME`: bash, git, autostart | `./martos usuario` crea **symlinks** `~/.bashrc → usuario/.bashrc`, etc. |
| `gnome/` | Volcados `dconf` (atajos, dock, extensiones…) | `./martos gnome` los carga; `./martos gnome-volcar` los actualiza |
| `personalizacion/` | Fondos y temas de Plymouth | `sudo ./martos plymouth instalar <tema>` |
| `instalacion/` | Script de instalación original (referencia) | manual |

**¿Por qué el sistema se copia y el usuario se enlaza?** Un symlink `/etc/… → ~/…` haría que
cualquier programa que corra con tu usuario pudiera editar un archivo que luego ejecuta root
(p. ej. `omen-fan.service`), es decir, escalar a root. Además, algunos archivos se leen en el
arranque temprano, cuando `/home` puede no estar montado.

### Flujo de trabajo diario
```bash
cd ~/.config/MartOS
nano sistema/etc/omen-fan/config.toml     # 1. editar en el repo
./martos diff omen-fan                    # 2. ver qué cambiaría
sudo ./martos sistema                     # 3. aplicar (reinicia lo necesario)
git commit -am "Curva AC más silenciosa"  # 4. guardar
git push                                  # 5. respaldar en GitHub
```
Si editaste algo directamente en `/etc`: `./martos importar` lo trae al repo.
Para bash no hace falta aplicar nada: `~/.bashrc` *es* el archivo del repo.

---

## 2. Inventario de configuraciones

### 2.1 Ventiladores (control propio del Embedded Controller)

El BIOS gestiona mal los ventiladores y el OMEN 16 no los expone a `lm-sensors`/`fancontrol`.
La solución escribe directamente en el **Embedded Controller (EC)** del portátil.

| Archivo | Función |
|---|---|
| `/usr/local/bin/omen-fand2` | Daemon Python (solo stdlib). Cada `poll_interval` s lee temperatura de CPU (EC `0x57`), GPU (EC `0xB7`) y SSD NVMe (hwmon), toma **la mayor**, interpola linealmente sobre la curva activa y escribe la velocidad en EC `0x34`/`0x35` (unidades de 100 RPM; máx. 55/57). Detecta AC/batería leyendo `/sys/class/power_supply/ADP1/online`. Pone EC `0x62=6` (modo manual) en cada ciclo. Notifica a systemd (`sd_notify` + watchdog). |
| `/usr/local/bin/omen-fan-restore` | Red de seguridad: escribe EC `0x62=0` → devuelve los ventiladores al BIOS. Se ejecuta al parar el servicio; puedes lanzarlo a mano si algo va mal. |
| `/etc/omen-fan/config.toml` | Curvas. `[ac]`: prioridad refrigeración (20 % en reposo, 100 % a 92 °C). `[battery]`: prioridad silencio (10 % en reposo, 55 % a 85 °C, 100 % a 96 °C). |
| `/etc/systemd/system/omen-fan.service` | `Type=notify`, `WatchdogSec=20`, `Restart=always`. Carga `ec_sys` antes de arrancar y ejecuta `omen-fan-restore` al parar. |
| `/etc/modprobe.d/omen-fan-ec.conf` | `options ec_sys write_support=1` → permite **escribir** en `/sys/kernel/debug/ec/ec0/io`. |
| `/etc/modules-load.d/omen-fan.conf` | Carga `ec_sys` en el arranque. |

Origen: basado en [alou-S/omen-fan](https://github.com/alou-S/omen-fan).
Ajustar: editar `config.toml` → `sudo ./martos sistema` (reinicia el servicio solo).
Diagnóstico: `journalctl -u omen-fan -f` (solo registra cuando cambia la velocidad).

### 2.2 Undervolt de CPU

| Archivo | Función |
|---|---|
| `/etc/intel-undervolt.conf` | CPU −50 mV, GPU integrada −10 mV, caché −50 mV; System Agent y Analog I/O a 0. Se leen como −49,80/−9,77/−49,80 mV (cuantización del MSR). Las líneas `daemon …` solo las usa `intel-undervolt-loop`, que está deshabilitado a propósito. |
| `/etc/modules-load.d/msr.conf` | Carga el módulo `msr`: intel-undervolt escribe el registro MSR `0x150` por `/dev/cpu/*/msr`. |
| `intel-undervolt.service` (lo instala el programa) | `oneshot` que aplica al arrancar **y al volver de suspensión**. Aparece `inactive (dead)` tras ejecutarse: es normal. |

`intel-undervolt` **no es un paquete**: se compila desde [kitsunyan/intel-undervolt](https://github.com/kitsunyan/intel-undervolt) (`make && sudo make install`).
Verificar: `sudo intel-undervolt read`. Probado estable (stress test, 10-sep-2026).

### 2.3 GPU NVIDIA

| Archivo | Función |
|---|---|
| `/usr/local/bin/nvidia-power-limit.sh` | Lee si hay corriente (`power_supply` tipo `Mains`), elige límite, lo ajusta al rango que admite la GPU y lo aplica con `nvidia-smi -pl`. Registra en el journal (`journalctl -t nvidia-power-limit`). |
| `/etc/nvidia-power-limit.conf` | `AC_LIMIT=100` W, `BATT_LIMIT=40` W (se sube al mínimo de la tarjeta si es menor). |
| `/etc/systemd/system/nvidia-power-limit.service` | `oneshot` que ejecuta el script al arrancar. |
| `/etc/udev/rules.d/90-nvidia-power-limit.rules` | Al enchufar/desenchufar el cargador relanza el servicio. |
| `/etc/modprobe.d/nvidia-graphics-drivers.conf` | `nvidia-drm modeset=1` (necesario para Wayland y para Plymouth con NVIDIA). |
| `/etc/initramfs-tools/modules` | Mete los módulos NVIDIA en el initramfs (pantalla correcta desde el arranque / Plymouth). |
| `/etc/prime-discrete` | `on-demand`: la iGPU Intel dibuja el escritorio y la NVIDIA solo se usa cuando una app lo pide (ahorro de batería). |
| `/etc/default/grub` | `GRUB_TIMEOUT=0` oculto, `quiet splash nvidia-drm.modeset=1`, os-prober desactivado. |

Driver: `nvidia-driver-580-open` (instalar con `sudo ubuntu-drivers install`).

### 2.4 Energía y temperatura de CPU

| Archivo | Función |
|---|---|
| `/etc/auto-cpufreq.conf` | **Cargador**: governor `performance`, turbo auto. **Batería**: `powersave`, `balance_power`, **máx. 1,1 GHz y sin turbo** (muy ahorrador). |
| `power-profiles-daemon` | **Enmascarado** (chocaría con auto-cpufreq). `martos sistema` lo vuelve a enmascarar. |
| `/etc/thermald/thermal-conf.xml` | Techo térmico del paquete CPU: a 85 °C recorta potencia (RAPL) suavemente; a 90 °C recorta potencia y frecuencia al máximo. auto-cpufreq decide perfiles; thermald solo pone el techo. |

auto-cpufreq se instala desde [AdnanHodzic/auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) (`sudo ./auto-cpufreq-installer && sudo auto-cpufreq --install`).

### 2.5 Memoria, swap y temporales

| Archivo | Función |
|---|---|
| `/etc/systemd/zram-generator.conf` | Swap comprimido en RAM de 6 GiB (zstd), prioridad 100. Paquete `systemd-zram-generator`. |
| `/etc/sysctl.d/99-zram-tmp.conf` | `vm.swappiness=100` y `vm.page-cluster=0`: valores recomendados cuando la swap es zram. |
| `/etc/systemd/system/tmp.mount` | `/tmp` en RAM (tmpfs) limitado a 4 GiB. |
| `/etc/environment` | `TMPDIR=/data/scratch`: los temporales grandes (bioinformática) van al disco de datos, no a `/tmp` en RAM. |
| `/etc/fstab` (*no versionado*, ver §5) | Monta el disco `LABEL=Respaldo` en `/data` con `nofail`; además existe `/swap.img` de 8 GiB (prioridad −1, solo se usa si zram se llena). |

### 2.6 Hardware OMEN y sistema

| Archivo | Función |
|---|---|
| `/etc/modules` | Carga `omen_rgb_keyboard` (driver DKMS de [OmenLinux/omen-rgb-keyboard](https://github.com/OmenLinux/omen-rgb-keyboard)) → `/sys/devices/platform/omen-rgb-keyboard/`. |
| `/etc/hp-manager/rgb.json` | Estado RGB guardado por OmenCommandCenterforLinux. Ese programa **no está instalado** (sus servicios `hpm-*` no existen): probablemente es un archivo huérfano. |
| `/etc/systemd/logind.conf` | `HandleLidSwitch=ignore` (con y sin cargador): cerrar la tapa **no suspende**. |
| `/etc/gdm3/custom.conf` | Inicio de sesión automático para `nesus`. |
| `/etc/bluetooth/main.conf` | `AutoEnable=false`: Bluetooth apagado al arrancar. |
| `/etc/smartd.conf` + `/etc/default/smartmontools` | Vigila los SSD cada 10 min. Avisos de temperatura: nvme0 a 83/90 °C, nvme1 a 75/80 °C. |
| `/etc/modprobe.d/disable-algif_aead.conf` | Desactiva el módulo `algif_aead` (mitigación de seguridad del kernel). |

### 2.7 Terminal (bash)

Estructura modular: `~/.bashrc` solo contiene el bloque de conda (que `conda init` exige ahí) y
después carga **en orden** cada `~/.bashrc.d/*.sh`.

| Archivo | Función |
|---|---|
| `usuario/.profile` | Shell de login: carga `.bashrc`, añade `~/bin` y `~/.local/bin` al PATH (sin duplicar) y Rust. |
| `usuario/.bashrc` | Sale si la shell no es interactiva; inicializa conda (`/opt/miniconda3`); carga `.bashrc.d/`. |
| `.bashrc.d/00-shell-options.sh` | `checkwinsize`, `umask 002`, `lesspipe`. |
| `.bashrc.d/10-history.sh` | Historial sin duplicados, en modo añadir, 1000/2000 líneas. |
| `.bashrc.d/20-completion.sh` | Autocompletado de bash. |
| `.bashrc.d/30-aliases.sh` | Colores en `ls`/`grep`, `ll`/`la`/`l`, `alert`, y `blanco-teclado`/`verde-teclado` (RGB). |
| `.bashrc.d/50-env.sh` | Carga `~/.config/env` (API keys, **fuera de git**); variables de bioinformática (`FUNANNOTATE_DB`, `GENEMARK_PATH`, `EGGNOG_DATA_DIR`, `BUSCO_LINEAGES_PATH`, InterProScan en PATH); `~/.local/bin`; Rust. |
| `.bashrc.d/60-prompt.sh` | Prompt de dos líneas: `(entorno conda) - ~/ruta` y ` Nesus ❯` en verde sobre magenta. |
| `.bashrc.d/90-welcome.sh` | `fastfetch` con el logo ASCII `Geno-snap-50-1.txt`. |

Para añadir algo nuevo: crea `usuario/.bashrc.d/NN-nombre.sh`; se carga en la próxima terminal.

### 2.8 Escritorio GNOME

| Archivo | Función |
|---|---|
| `gnome/dconf-*.ini` | Volcados de `/org/gnome/{desktop/wm/keybindings, settings-daemon/plugins/media-keys, shell, desktop/interface, mutter, desktop/peripherals, desktop/background, terminal}`. |
| `gnome/atajos-escritorios.sh` | (antes `personalizacion/scripts/modificacion-gsettings.sh`) Quita `Super+1..9` al dock y los asigna a cambiar de escritorio; `Super+Shift+1..9` mueve la ventana. Ya está incluido en el volcado dconf; se conserva como documentación. |
| `usuario/.config/autostart/eww-todo-daemon.desktop` | Arranca el widget de tareas eww (`~/Omentu/ToDo_EWW`) al iniciar sesión. |
| `personalizacion/fondos/` | `horizon_upscayl_2x_digital-art-4x.png` es el fondo actual (`~/.config/background`); `horizon.jpg` es el original. |

### 2.9 Plymouth (animación de arranque)

- Temas de [adi1090x/plymouth-themes](https://github.com/adi1090x/plymouth-themes) (GPL-3.0).
- **Activo: `cubes`**. Instalados en `/usr/share/plymouth/themes/`: `cubes` y `dna`. Ambos se guardan en `personalizacion/plymouth/temas/`.
- Los 4 packs completos (~280 MB, 80 temas) están en `personalizacion/plymouth/packs/`, pero **fuera de git** porque se descargan otra vez con `./martos plymouth descargar`.
- `./martos plymouth listar` · `sudo ./martos plymouth instalar <tema>` (copia el tema, lo registra en `update-alternatives` y regenera el initramfs) · `sudo ./martos plymouth probar 6` (vista previa sin reiniciar; mejor desde una TTY).

---

## 3. Revisión: redundancias, conflictos y riesgos

### Corregido en el repo (pendiente de aplicar con `sudo ./martos sistema`)
1. **`systemd-modules-load.service` fallaba en CADA arranque.** `/etc/modules-load.d/omen-fan.conf`
   pedía cargar `hp-wmi`, que en este modelo da `Input/output error` (el driver
   `omen_rgb_keyboard` ya usa la interfaz WMI). Los demás módulos se cargaban igualmente, pero el
   servicio quedaba en rojo. omen-fand2 no usa hp-wmi (lee el EC directamente). Se ha quitado
   `hp-wmi` de ese archivo y de `ExecStartPre` en `omen-fan.service`.

### Corregido en bash (ya activo)
2. `~/.local/bin` se añadía al PATH dos veces (`.profile` + `50-env.sh`) → ahora se comprueba antes de añadir.
3. `~/.cargo/env` se cargaba en `.profile` y al final de `.bashrc`, sin comprobar que existiera
   (en un sistema recién formateado daría error) → ahora con `[ -f … ]`, dentro de `50-env.sh`.
4. `TMPDIR=/data/scratch` estaba en `/etc/environment` **y** en `.bashrc` → queda solo en `/etc/environment`.
5. `~/.bashrc.d/bashrc` era una copia antigua de `.bashrc` → no se ha llevado al repo (está en la copia de seguridad).

### Redundancias inofensivas (se dejan)
6. `nvidia-drm.modeset=1` aparece en GRUB **y** en `modprobe.d`. Es lo mismo dos veces y no daña.
7. `ec_sys write_support=1` aparece en `modprobe.d`, `modules-load.d` y el `ExecStartPre` del servicio. Así se garantiza el orden de arranque.
8. Las líneas `daemon power/tjoffset` de `intel-undervolt.conf` no hacen nada (el *loop* está deshabilitado).
9. Swap doble: zram 6 GiB (prioridad 100) + `/swap.img` 8 GiB (prioridad −1). Funciona bien (el archivo solo se usa si zram se llena). Si nunca usas hibernación y 30 GiB de RAM te sobran, se puede eliminar `/swap.img`.

### Interacciones revisadas: compatibles
- **auto-cpufreq + thermald + undervolt + curvas de ventilador** funcionan juntos. Con batería,
  la curva silenciosa (55 % a 85 °C) y thermald (empieza a recortar a 85 °C) se combinan: se
  prioriza el silencio sobre el rendimiento. Con corriente, a 85 °C los ventiladores ya van al 90 %.
- `power-profiles-daemon` está enmascarado: correcto con auto-cpufreq.

### Decisiones tuyas que conviene conocer
10. **Tapa cerrada = no suspende** + **inicio de sesión automático**. Si metes el portátil cerrado en la mochila, sigue
    encendido y calentándose; y quien lo abra entra sin contraseña. Si es intencionado (lo usas con pantalla externa), ok.
11. Alias `blanco-teclado`/`verde-teclado`: tienen los colores cruzados (`00FF00` es verde en RGB y lo
    usa el alias "blanco"). Tu propio comentario ya lo apuntaba; revisa cuál es el correcto y corrígelo en `30-aliases.sh`.
12. `/etc/hp-manager/rgb.json` probablemente es un resto de OmenCommandCenterforLinux.
13. `/usr/local/bin/omen-fan` y `omen-fand` (versión 1) siguen instalados pero **no se usan**. Para borrarlos:
    `sudo rm /usr/local/bin/omen-fan /usr/local/bin/omen-fand`.
14. `/data` tiene `nofail`. Si el disco no está, `TMPDIR` apunta a una carpeta que no existe y algunos
    programas fallarán al crear temporales.
15. `~/Instaladores/instalaciones.sh` instala Miniconda en `~/miniconda3`, pero tu instalación real
    está en `/opt/miniconda3` (es lo que usa `.bashrc`). Copia en `instalacion/instalaciones-original.sh`.
16. `GITHUB_TOKEN` en `~/.config/env` está **caducado/inválido**: hace que `gh` falle aunque tengas
    sesión iniciada. Renuévalo o comenta esa línea.

---

## 4. Restaurar después de formatear

```bash
# 0. Ubuntu 24.04 recién instalado, con el disco de datos con etiqueta "Respaldo"
sudo apt install -y git gh
gh auth login
git clone https://github.com/<usuario>/MartOS ~/.config/MartOS
cd ~/.config/MartOS

# 1. Programas de los que dependen las configuraciones
sudo ubuntu-drivers install                       # driver NVIDIA (580-open)
sudo apt install -y thermald smartmontools systemd-zram-generator lm-sensors \
                    build-essential dkms fastfetch
#    · auto-cpufreq      → github.com/AdnanHodzic/auto-cpufreq
#    · intel-undervolt   → github.com/kitsunyan/intel-undervolt (make && sudo make install)
#    · omen-rgb-keyboard → github.com/OmenLinux/omen-rgb-keyboard (sudo ./install.sh, DKMS)
#    · Miniconda en /opt/miniconda3, Rust (rustup), eww en ~/.local/bin, Brave
#    (ver instalacion/instalaciones-original.sh)

# 2. Configuración
sudo ./martos sistema            # /etc + /usr/local/bin, habilita servicios
./martos usuario                 # bash, git, autostart
./martos gnome                   # atajos, dock, fondo
./martos plymouth descargar      # opcional: los 80 temas
sudo ./martos plymouth instalar cubes

# 3. Secretos (no están en git): recupera ~/.config/env desde tu gestor de contraseñas
# 4. Mira /etc/fstab: añade la línea de /data  (LABEL=Respaldo /data ext4 noatime,nodiratime,nofail 0 2)
sudo reboot
```
Después: `./martos estado` debería decir que todo coincide. Comprueba `sudo intel-undervolt read`,
`systemctl status omen-fan` y `systemctl --failed`.

---

## 5. Qué NO está en el repo, y por qué

| Elemento | Motivo |
|---|---|
| `~/.config/env` | Contiene API keys (`GITHUB_TOKEN`, `WOS_API_KEY`). Guárdalo en un gestor de contraseñas. |
| `/etc/fstab`, `/etc/netplan/*` | Dependen de los UUID de cada instalación; copiarlos tal cual podría impedir el arranque. La línea de `/data` está en §4. |
| Claves SSH del host, `sudoers` | Seguridad / se regeneran solas. |
| Packs de Plymouth | 280 MB que se pueden volver a descargar. |
| Datos y entornos conda | No son configuración (ver plan de almacenamiento en `~/optimizacion-de-almacenamiento.md`). |
