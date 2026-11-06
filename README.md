# 🏆 Trophées PSN — widget macOS

Un widget natif pour ton bureau Mac qui affiche tes **trophées PlayStation** dans le style Apple : niveau, platine / or / argent / bronze, nombre de jeux, jeux terminés à 100 %, complétion moyenne et tes derniers jeux joués.

<p align="center">
  <img src="docs/widgets-dark.png" alt="Widget en mode sombre" width="820">
</p>

<p align="center">
  <img src="docs/widgets-light.png" alt="Widget en mode clair" width="820">
</p>

<sub>Captures réalisées avec des données fictives.</sub>

- **3 tailles** : petit, moyen, grand
- **Suit l'apparence du Mac** : clair, sombre, teinté, transparent
- **Mise à jour automatique** environ toutes les 30 minutes
- **Données officielles** de PlayStation Network (les mêmes que PSNprofiles)
- **Aucun serveur tiers** : ton Mac parle directement à Sony, rien n'est envoyé ailleurs

> 🇬🇧 *English: a native macOS desktop widget showing your PlayStation trophies. Install steps below: Xcode + free Apple ID → `bash install.sh` → paste your NPSSO token in the app → add the widget.*

---

## Ce qu'il te faut

| | |
|---|---|
| 💻 Un Mac sous **macOS 14 Sonoma** ou plus récent | |
| 🛠️ **Xcode** (gratuit) | [App Store](https://apps.apple.com/app/xcode/id497799835) |
| 🍎 Un **identifiant Apple** (gratuit, celui de l'App Store suffit) | aucun abonnement développeur nécessaire |
| 🎮 Un **compte PlayStation Network** | |

Compte environ **10 minutes** la première fois (hors téléchargement de Xcode).

---

## Installation de A à Z

### 1. Installer Xcode

1. Installe **Xcode** depuis l'[App Store](https://apps.apple.com/app/xcode/id497799835). C'est gros (plusieurs Go), prévois du temps.
2. **Ouvre Xcode une première fois.** Accepte la licence et laisse-le installer ses composants. Une fois l'écran d'accueil affiché, tu peux passer à la suite.

### 2. Ajouter ton identifiant Apple dans Xcode

Il sert à « signer » l'app : sans ça, macOS refuse d'afficher le widget.

1. Dans la barre de menus : **Xcode → Réglages…** (raccourci `⌘ ,`).
2. Onglet **Comptes** (*Accounts*).
3. Clique sur **+** en bas à gauche → **Apple ID** → **Continuer**, puis connecte-toi.

### 3. Créer ton certificat de développeur

Toujours dans **Réglages → Comptes** :

1. Sélectionne ton identifiant Apple à gauche, puis ton équipe **« Ton Nom (Personal Team) »** à droite.
2. Clique sur **Gérer les certificats…** (*Manage Certificates…*).
3. Clique sur **+** en bas à gauche → **Apple Development**.
4. Un certificat apparaît dans la liste : clique sur **Terminé**. Tu peux fermer Xcode.

### 4. Télécharger le projet

Sur cette page GitHub : bouton vert **Code** → **Download ZIP**. Ouvre le ZIP téléchargé pour obtenir le dossier du projet.

<sub>Ou, si tu connais git : `git clone` ce dépôt.</sub>

### 5. Lancer l'installation

**Option facile :** dans le dossier du projet, fais un **clic droit sur `Installer.command` → Ouvrir**, puis confirme **Ouvrir**. La première fois, macOS demande une confirmation : c'est normal, le fichier vient d'Internet.

**Option Terminal :** ouvre l'app **Terminal**, tape `bash ` (avec un espace), glisse le fichier `install.sh` dans la fenêtre, puis appuie sur **Entrée**.

Le script fait tout seul :

```
▸ Vérification de Xcode                          ✓
▸ Recherche de ton compte développeur Apple      ✓ Team ID : XXXXXXXXXX
▸ Compilation (1 à 2 minutes la première fois)   ✓
▸ Installation dans le dossier Applications      ✓
🏆 Terminé !
```

À la fin, l'app **Trophées PSN** s'ouvre.

<sub>Si macOS demande l'accès au trousseau pendant la compilation, entre le mot de passe de ta session Mac et clique sur **Toujours autoriser**.</sub>

### 6. Connecter ton compte PlayStation

L'app a besoin d'un jeton appelé **NPSSO** pour lire tes trophées. Il ne se récupère qu'une fois, et l'app reste ensuite connectée environ 2 mois.

1. Dans ton navigateur, connecte-toi sur **[playstation.com](https://www.playstation.com/)**.
2. Dans le **même navigateur**, ouvre **[ca.account.sony.com/api/v1/ssocookie](https://ca.account.sony.com/api/v1/ssocookie)**.
3. Tu vois une ligne du type `{"npsso":"aBcD1234…"}`. Copie **toute la ligne** ou seulement la valeur.
4. Colle-la dans l'app **Trophées PSN** et clique sur **Connecter**.

L'aperçu de tes stats apparaît dans l'app. Si macOS demande si l'app peut *accéder aux données d'autres apps*, clique sur **Autoriser** : c'est ce qui permet au widget de lire tes stats.

> ⚠️ **Ne partage jamais ton jeton NPSSO** : il donne accès à ton compte PlayStation.

### 7. Ajouter le widget au bureau

1. **Clic droit sur le bureau** → **Modifier les widgets…**
2. Cherche **« Trophées PSN »**.
3. Choisis une taille et glisse-la sur le bureau (tu peux en mettre plusieurs).

C'est fini ! 🎉

---

## Questions fréquentes et dépannage

<details>
<summary><b>Le widget s'affiche sans couleurs (gris / blanc)</b></summary>

C'est macOS qui décide, pas l'app :

- **Réglages Système → Bureau et Dock → Widgets → Style des widgets** : en mode **Monochrome**, tous les widgets restent toujours gris. En mode **Automatique**, ils deviennent monochromes dès qu'une fenêtre est au premier plan et reprennent leurs couleurs quand tu cliques sur le bureau. Choisis **Couleur** pour qu'ils restent toujours en couleur.
- **Réglages Système → Apparence → Style des icônes et widgets** : en mode **Transparent** ou **Teinté**, tous les widgets, y compris celui-ci, suivent ce style, comme les icônes du Dock.
</details>

<details>
<summary><b>« Aucun certificat de développeur trouvé »</b></summary>

Refais l'[étape 3](#3-créer-ton-certificat-de-développeur), puis relance le script. Si tu as plusieurs comptes, tu peux choisir l'équipe à utiliser : `bash install.sh TONTEAMID`.
</details>

<details>
<summary><b>« Xcode n'est pas encore configuré » ou « outils en ligne de commande »</b></summary>

Ouvre Xcode une fois et laisse-le terminer son installation. Si le script te le demande, lance aussi dans le Terminal :

```bash
sudo xcode-select -s /Applications/Xcode.app
```
</details>

<details>
<summary><b>« Jeton NPSSO invalide ou expiré »</b></summary>

Le jeton change chaque fois que tu te reconnectes sur playstation.com. Recommence l'[étape 6](#6-connecter-ton-compte-playstation) avec un jeton tout frais.
</details>

<details>
<summary><b>« Session PlayStation expirée »</b></summary>

La connexion dure environ 2 mois. Ouvre l'app et recolle un nouveau jeton NPSSO (étape 6).
</details>

<details>
<summary><b>Le widget n'apparaît pas dans la liste, ou affiche une ancienne version</b></summary>

Ouvre l'app Trophées PSN une fois, attends quelques secondes, puis réessaie. Au besoin, retire le widget du bureau et remets-le, ou redémarre le Mac.
</details>

<details>
<summary><b>L'app s'arrête de fonctionner au bout de quelques jours</b></summary>

Avec un identifiant Apple gratuit, Apple limite la durée de validité des apps que tu compiles toi-même. Il suffit de relancer `Installer.command` : ta connexion PSN est conservée.
</details>

<details>
<summary><b>Mettre à jour ou désinstaller</b></summary>

- **Mettre à jour :** télécharge la nouvelle version du projet et relance `Installer.command`.
- **Désinstaller :** retire le widget du bureau, clique sur **Se déconnecter** dans l'app, puis mets `/Applications/PSNTrophies.app` à la corbeille.
</details>

---

## Confidentialité

- Le code **ne contient aucune donnée personnelle**. Chacun compile l'app avec son propre compte Apple et se connecte avec son propre compte PSN.
- Ton jeton NPSSO n'est envoyé **qu'aux serveurs de Sony**. L'app ne le garde pas : elle conserve seulement un jeton de rafraîchissement et tes dernières stats, **uniquement sur ton Mac**, dans un espace partagé entre l'app et son widget.
- `install.sh` enregistre ton Team ID Apple dans `Config/Local.xcconfig`. Ce fichier est ignoré par git, il ne sera donc jamais publié par erreur.

## Avertissement

Ce projet n'est **ni affilié à Sony Interactive Entertainment, ni approuvé par elle**. « PlayStation » et « PSN » sont des marques de Sony. Il utilise l'API de PlayStation Network de façon non officielle, comme d'autres outils communautaires : Sony peut la modifier à tout moment.

---

## Pour les développeurs

```
App/       App de connexion (SwiftUI) + rendu des captures
Widget/    Extension WidgetKit (timeline, rafraîchissement)
Shared/    Client API PSN, modèles, stockage partagé, vues des widgets
Config/    Signing.xcconfig (+ Local.xcconfig, généré, ignoré)
```

- Le projet Xcode est généré avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) depuis `project.yml` (`xcodegen generate`). Le `.xcodeproj` est versionné, donc XcodeGen n'est pas nécessaire pour installer.
- Pour ouvrir le projet dans Xcode, lance d'abord `install.sh` une fois : il crée `Config/Local.xcconfig` avec ton Team ID.
- Régénérer les captures du README : compiler en Debug, puis `PSNTrophies.app/Contents/MacOS/PSNTrophies --render-preview docs`.

Licence [MIT](LICENSE).
