#!/bin/bash
# Double-clic pour installer Trophées PSN (clic droit → Ouvrir la première fois).
cd "$(dirname "$0")" && bash install.sh
echo
read -n 1 -s -r -p "Appuie sur une touche pour fermer cette fenêtre…"
