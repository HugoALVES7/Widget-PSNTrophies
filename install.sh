#!/bin/bash
# Installe Trophées PSN (app + widget) sur ce Mac.
# Usage : bash install.sh            (détection automatique de ton compte Apple)
#         bash install.sh ABCDE12345 (pour forcer un Team ID précis)
set -euo pipefail
cd "$(dirname "$0")"

step() { printf "\n\033[1;34m▸ %s\033[0m\n" "$1"; }
ok()   { printf "  \033[1;32m✓\033[0m %s\n" "$1"; }
fail() { printf "\n\033[1;31m✖ %s\033[0m\n\n" "$1"; exit 1; }

APP_NAME="PSNTrophies.app"
LOCAL_CONFIG="Config/Local.xcconfig"

# 1. Xcode -------------------------------------------------------------------
step "Vérification de Xcode"
[ -d /Applications/Xcode.app ] || fail "Xcode n'est pas installé. Installe-le depuis l'App Store, ouvre-le une fois, puis relance ce script."
if [[ "$(xcode-select -p 2>/dev/null)" != *Xcode.app* ]]; then
  fail "Le Mac utilise les outils en ligne de commande au lieu de Xcode. Lance cette commande (mot de passe demandé), puis relance le script :
   sudo xcode-select -s /Applications/Xcode.app"
fi
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  fail "Xcode n'est pas encore configuré. Ouvre Xcode une fois, accepte la licence et laisse-le installer ses composants, puis relance ce script."
fi
ok "$(xcodebuild -version | head -1)"

# 2. Compte Apple (Team ID) --------------------------------------------------
step "Recherche de ton compte développeur Apple"
TEAM="${1:-}"
if [ -z "$TEAM" ] && [ -f "$LOCAL_CONFIG" ]; then
  TEAM="$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' "$LOCAL_CONFIG" | tr -d '[:space:]')"
fi
if [ -z "$TEAM" ]; then
  # Le Team ID est le champ OU du certificat « Apple Development » créé par Xcode.
  TEAMS=""
  pem=""
  while IFS= read -r line; do
    pem+="$line"$'\n'
    if [[ "$line" == *"END CERTIFICATE"* ]]; then
      ou="$(printf "%s" "$pem" | openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null \
            | tr ',' '\n' | sed -n 's/^OU=\([A-Z0-9]\{10\}\)$/\1/p' || true)"
      [ -n "$ou" ] && TEAMS+="$ou"$'\n'
      pem=""
    fi
  done < <(security find-certificate -a -c "Apple Development" -p 2>/dev/null || true)
  TEAMS="$(printf "%s" "$TEAMS" | sort -u | sed '/^$/d')"
  COUNT="$(printf "%s" "$TEAMS" | grep -c . || true)"
  if [ "$COUNT" = "0" ]; then
    fail "Aucun certificat de développeur trouvé. Dans Xcode : Réglages → Comptes → ajoute ton identifiant Apple,
   sélectionne ton équipe « (Personal Team) » → Gérer les certificats… → + → Apple Development.
   Puis relance ce script. (Détails dans le README, étape 3.)"
  fi
  TEAM="$(printf "%s" "$TEAMS" | head -1)"
  if [ "$COUNT" != "1" ]; then
    printf "  Plusieurs équipes trouvées :\n%s\n  J'utilise %s. Pour en choisir une autre : bash install.sh <TEAM_ID>\n" "$TEAMS" "$TEAM"
  fi
fi
ok "Team ID : $TEAM"

if [ ! -f "$LOCAL_CONFIG" ] || ! grep -q "DEVELOPMENT_TEAM *= *$TEAM" "$LOCAL_CONFIG"; then
  PREFIX="com.psntrophies.$(echo "$TEAM" | tr '[:upper:]' '[:lower:]')"
  cat > "$LOCAL_CONFIG" <<EOF
// Généré par install.sh — propre à ton Mac, ignoré par git.
DEVELOPMENT_TEAM = $TEAM
BUNDLE_ID_PREFIX = $PREFIX
EOF
  ok "Configuration enregistrée dans $LOCAL_CONFIG"
fi

# 3. Compilation -------------------------------------------------------------
step "Compilation (1 à 2 minutes la première fois)"
LOG="build/install.log"
mkdir -p build
if ! xcodebuild -project PSNTrophies.xcodeproj -scheme PSNTrophies -configuration Release \
      -derivedDataPath build -allowProvisioningUpdates build >"$LOG" 2>&1; then
  grep -E "error:" "$LOG" | sed 's/^.*error: /  • /' | sort -u | head -8
  fail "La compilation a échoué (journal complet : $LOG). Voir la section Dépannage du README."
fi
ok "Compilation réussie"

# 4. Installation ------------------------------------------------------------
step "Installation dans le dossier Applications"
osascript -e 'tell application "System Events" to if exists process "PSNTrophies" then tell application "PSNTrophies" to quit' >/dev/null 2>&1 || true
sleep 1
rm -rf "/Applications/$APP_NAME"
ditto "build/Build/Products/Release/$APP_NAME" "/Applications/$APP_NAME"
pkill -f PSNTrophiesWidget 2>/dev/null || true
ok "Installé : /Applications/$APP_NAME"

open "/Applications/$APP_NAME"
printf "\n\033[1;32m🏆 Terminé !\033[0m L'app Trophées PSN est ouverte : connecte ton compte PlayStation,\n"
printf "   puis clic droit sur le bureau → Modifier les widgets… → « Trophées PSN ».\n\n"
