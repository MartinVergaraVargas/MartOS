#!/bin/bash

# Desvincular Win + Numero de la apertura de apps (Taskbar)
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-1 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-2 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-3 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-4 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-5 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-6 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-7 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-8 '[]'
gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-9 '[]'

# Configurar Win + Numero para cambiar al escritorio correspondiente
for i in {1..9}; do
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-$i "['<Super>$i']"
done

# Opcional: Win + Numero + Shift para mover la ventana actual al escritorio
for i in {1..9}; do
  gsettings set org.gnome.desktop.wm.keybindings move-to-workspace-$i "['<Super><Shift>$i']"
done

echo "Atajos Win+1..9 configurados para escritorios. ¡Listo!"
