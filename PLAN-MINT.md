# Plan de migración Ubuntu → Linux Mint (OMEN 16)

Decidido el 2026-10-09. Solo Mint (sin Arch/Debian por ahora, pero sin cerrarles la puerta).

## Reparto de discos

```
Intel 477 G (QLC) — sistema + datos de poca escritura
 ├─ EFI de Windows (200M)       ← GRUB de Mint se instala aquí
 ├─ MSR · Windows 134G · Recuperación (sin tocar; NO tiene BitLocker: la partición es ntfs)
 ├─ /boot de Mint   2G  ext4, sin cifrar
 ├─ 5G sin particionar           ← reserva para el /boot de futuras distros
 └─ LUKS (~335G) → btrfs  @ → /     (incluye /opt/miniconda3, /srv/biodata, /var/lib/docker, /tmp)

Kingston 931 G (TLC) — datos personales
 └─ LUKS (disco entero) → btrfs  @home → /home
```

- Una sola contraseña (Plymouth): la del LUKS del Intel. El Kingston se abre con un archivo de clave
  guardado dentro de la raíz cifrada (`/etc/crypttab`).
- Desaparece la partición `/data` (nvme0n1p5): su espacio pasa a ser la raíz de Mint.
- Uso estimado del Intel: sistema ~25G + conda ~50G + biodata ~133G + docker ~7G ≈ 215G de ~335G.

## Rutas

| Qué | Antes | Después |
|---|---|---|
| Miniconda | `/opt/miniconda3` (Kingston) | `/opt/miniconda3` (Intel) — sin cambios |
| Bases de datos | `/srv/biodata` (Kingston) | `/srv/biodata` (Intel) — `50-env.sh` sin cambios |
| TFM | `/srv/TFM` | `~/Tricho-PGPT` (Kingston) — **rutas reescritas, sin enlace simbólico** |
| Docker | `/var/lib/docker` (Kingston) | `/var/lib/docker` (Intel), ruta por defecto |

`/srv/TFM` aparece escrito en 256 archivos de texto (scripts, `.pipeline_state`, configs de
pipeline-iteracion.06, resultados de sourmash…). Tras restaurar: reemplazar `/srv/TFM` →
`/home/nesus/Tricho-PGPT` en esos archivos y comprobar con `grep -rI /srv/TFM ~/Tricho-PGPT`
que no quede ninguno. Antes de respaldar: confirmar que no hay ninguna cepa corriendo (H10603).

## Pasos

Los scripts están en `instalacion/` (en GitHub **y** en el disco externo, dentro de la copia del home).

### Antes de formatear (en Ubuntu)

| # | Qué | Cómo |
|---|---|---|
| A | Confirmar que no corre ningún pipeline (H10603) | el script 1 lo comprueba |
| B | Subir MartOS a GitHub | `cd ~/.config/MartOS && git add -A && git commit && git push` |
| C | **Respaldo al disco externo** | `bash ~/.config/MartOS/instalacion/1-respaldo-previo.sh --sin-secretos` (datos, sin contraseñas) y luego `… --solo-secretos` (pide contraseñas) |
| D | Comprobar que el respaldo de secretos se abre | `gpg -d …/Migracion-Mint/secretos.tar.gpg \| tar -tzf - \| head` |
| E | Borrar la copia SIN cifrar de claves del disco | `rm /media/nesus/Respaldos/env` |

### Instalar Mint (USB, asistente "Algo más") — solo el Intel

1. Borrar `nvme0n1p5` (la antigua `/data`).
2. `/boot` 2G ext4 · 5G sin asignar · resto: "volumen físico para cifrado" → btrfs en `/`.
3. EFI del Intel (`nvme0n1p1`): "Partición del sistema EFI", **sin formatear**.
4. Cargador de arranque en `/dev/nvme0n1`. No tocar nada del Kingston.
5. Usuario: **nesus** (para que las rutas `/home/nesus/…` sigan valiendo).

### Después de instalar (en Mint), en este orden

| # | Qué | Cómo |
|---|---|---|
| 1 | Comprobar que Mint arranca solo desde el Intel | `efibootmgr -v`, `lsblk` (ni `/boot` ni `/boot/efi` en `nvme…` del Kingston) |
| 2 | **Home al Kingston** (borra el Kingston) | Desde una TTY (Ctrl+Alt+F3): `sudo bash /media/nesus/Respaldos/Migracion-Mint/home/.config/MartOS/instalacion/2-home-a-kingston.sh` (simula) → `… --ejecutar` → `sudo reboot` → `… --limpiar` |
| 3 | **Datos** (home, Tricho-PGPT con rutas reescritas, biodata) | `bash /media/nesus/Respaldos/Migracion-Mint/home/.config/MartOS/instalacion/3-restaurar-datos.sh` |
| 4 | Actualizar MartOS desde GitHub | `gh auth login && git -C ~/.config/MartOS pull` (si `gh` aún no está: tras el paso 5) |
| 5 | **Programas** | `bash ~/.config/MartOS/instalacion/reinstalar-en-mint.sh` → revisa `~/reinstalacion-mint-*-FALLOS.txt` |
| 6 | **Configuración de hardware** | `sudo martos restaurar-sistema --solo-hardware` (lista al final lo que hay que hacer a mano) |
| 7 | **Configuración de bash** | `martos restaurar-usuario` y borrar `~/.config/autostart/eww-todo-daemon.desktop` |
| 8 | A mano | grub (`nvidia-drm.modeset=1`, menú oculto) · inicio automático en LightDM · NVIDIA PRIME on-demand · secretos (ver final del paso 3) · `sudo martos plymouth instalar <tema>` · atajos/dock de Cinnamon |
| 9 | Reiniciar y comprobar | `martos estado` · `sudo intel-undervolt read` · `systemctl status omen-fan` · `systemctl --failed` · `conda env list` |

### Qué queda en cada sitio

| GitHub (repo MartOS) | Disco externo (`Respaldos/Migracion-Mint/`) |
|---|---|
| Scripts: `martos`, `instalacion/*.sh` | `home/` — tu carpeta personal completa (incluye una copia de MartOS) |
| Configuración: `sistema/`, `bash/`, `usuario/`, `gnome/` | `Tricho-PGPT/` — el TFM (379G) |
| Listas: `instalacion/conda/*.yml`, `R-paquetes.txt` | `biodata/` — bases de datos (133G) |
| Documentación: `INFORME.md`, `PLAN-MINT.md` | `secretos.tar.gpg` — `env`, `.ssh`, `.gnupg`, `/etc` (cifrado) |
| **Nunca**: claves, datos, entornos conda | `.deb` de RStudio/FNMT/AutoFirma (en `home/Instaladores`) |

## Pendientes

- [ ] Docker: los volúmenes de Specify (`specify7-docker_*`) no se respaldan; si los necesitas, expórtalos antes.
- [ ] **Temporales**: dejar los de Mint por defecto (`/tmp` = carpeta en la raíz → Intel, se vacía al
      arrancar; sin `TMPDIR`). Decidir más adelante si los temporales de bioinformática van a otro sitio.
      ⚠ `martos restaurar-sistema` restauraría la configuración de Ubuntu (`/tmp` en RAM de 4G
      vía `tmp.mount`, y `TMPDIR=/var/tmp` en `/etc/environment`, más `sysctl.d/99-zram-tmp.conf`):
      excluirlos al restaurar hasta tomar la decisión.
- [ ] `/etc/fstab` de Ubuntu: no restaurar (UUIDs nuevos, y la línea de `/data` ya no existe).
- [ ] `martos gnome` no aplica en Cinnamon: rehacer atajos/dock/fondo a mano.
- [ ] Autostart de eww (`usuario/.config/autostart/eww-todo-daemon.desktop`): no restaurar.
- [ ] Opcional: subvolúmenes `@conda` y `@biodata` en el Intel (para excluirlos de las instantáneas de Timeshift).

### Después de restaurar Mint: privacidad del correo en GitHub

- [ ] Correo privado de GitHub como autor por defecto:
      `git config --global user.email 38733889+MartinVergaraVargas@users.noreply.github.com`
      (y quitar el `user.email` local de MartOS: `git -C ~/.config/MartOS config --unset user.email`)
- [ ] GitHub → Settings → Emails: activar "Keep my email addresses private" y
      "Block command line pushes that expose my email".
- [ ] Verificación en dos pasos activa en GitHub y en Gmail (es lo que de verdad protege la cuenta).
- [ ] Opcional: reescribir MartOS con el correo privado (`git filter-branch --env-filter` + `git push --force`).
      No reescribir Glooba ni Mycrotal: tienen colaboradores.
      Contexto: `vergaravargas.martin@gmail.com` ya es público en Mycrotal (31 commits), Glooba (14) y
      Genome-Assembly-Annotation (2); no es un riesgo de acceso, pero sí de spam/phishing.
