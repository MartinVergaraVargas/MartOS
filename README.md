# MartOS

Respaldo y guía de la configuración de mi HP OMEN 16 (Ubuntu 24.04, GNOME): ventiladores,
undervolt, GPU, energía, bash, GNOME y Plymouth. Los archivos viven en su sitio (`/etc`, `~/.bashrc.d`…),
cada uno con una cabecera que explica qué hace; aquí está su copia y la guía.

```bash
martos estado                  # ¿hay cambios sin respaldar?
martos respaldar               # copiar los cambios al respaldo → luego git commit/push
sudo martos restaurar-sistema  # tras formatear: respaldo → /etc…
martos restaurar-usuario       # tras formatear: respaldo → ~/.bashrc…
```

📄 **[INFORME.md](INFORME.md)**: qué hace cada archivo, cómo funciona, la revisión de conflictos y cómo restaurar todo tras formatear.
