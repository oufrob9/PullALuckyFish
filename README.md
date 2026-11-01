# 🎃 Pull A Lucky Fish — AutoCauldron Suite

Interface modulaire ultra-complète, haute performance et robuste pour l'événement Chaudron d'Halloween & l'automatisation du jeu (Pull A Lucky Fish).

---

## 🚀 Exécution Simple (1-Liner)

Dans n'importe quel executor Roblox (Solara, Wave, Delta, Celery, Fluxus, etc.) :

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/Loader.luau"))()
```

*Note : Si vous avez téléchargé le dossier `Menu/` localement dans votre dossier `workspace`, le loader le détecte automatiquement et charge les fichiers en local sans latence.*

```lua
loadstring(readfile("Menu/Loader.luau"))()
```

---

## 📋 Fonctionnalités par Onglet

### 1. 🏠 Accueil (`flame`)
- **Statut en Direct** : Surveillance de la position (dans/hors zone), état de la plongée, solde de Candy, présence du Mythic Egg, cible actuelle et statistiques de session (plongées effectuées, items achetés).
- **Actions Rapides** :
  - **Lancer la Ligne (Cast Manuel)** : déclenchement forcé du lancer.
  - **Débloquer la Ligne (Anti-Stuck)** : interruption/fin de plongée immédiate et recentrage au chaudron.
  - **Téléportation au Chaudron** : téléportation instantanée sur la plateforme.

### 2. 🎃 Halloween (`ghost`)
- **Plongée du Chaudron** :
  - **Auto-Cast Chaudron** : détection automatique du bouton et relance continue.
  - **Auto-Pilote de Ligne (Steer)** : guidage dynamique du hameçon vers les meilleurs loots.
- **Priorité Mythic Egg** :
  - **Priorité Absolue** : verrouille instantanément le hameçon dès détection d'un œuf mythique dans le puits.
  - **Mode Strict** : ignore tout autre objet tant qu'aucun œuf mythique n'est présent.
- **Pilotage & Esquive** :
  - **Esquive Monstres & Mines** : force répulsive dynamique selon la distance.
  - **Pré-Alignement en Descente** : positionne le fil avant la remontée.
  - **Mode de Priorité** (`MythicEggFirst`, `CandyMax`, `RarityMax`, `Balanced`).
  - **Sliders** de rayon de danger et de marge verticale.
- **Magasin d'Halloween** :
  - Auto-Buy Spooky Egg (25k Coins) & Cursed Egg (75k Coins).
  - Auto-Buy Halloween Pet Egg (300k Coins - Stock 3).
  - Auto-Buy Flotteur Divin Halloween (500k Coins).
  - Auto-Buy Base Haunted Manor (1.5M Coins).
  - Auto-Buy Monture Balai de Sorcière (5M Coins).
  - Auto-Buy Canne Faux de la Mort (20M Coins).
- **Améliorations du Chaudron** :
  - Auto-Upgrade Machine, Chance (Luck), Capacité Hameçon, Poids des poissons.
  - Réserve minimum de Candy réglable pour ne pas vider votre solde.

### 3. 👁️ Visuels (`eye`)
- **ESP Chaudron 3D** : Bounding Box délimitant la zone du chaudron.
- **Affichage des Loots & Poissons** : nom, rareté et distance en mètres.
- **Affichage des Monstres & Mines** : identification visuelle avec alerte DANGER.
- **Silhouettes Chams** : highlights colorées selon la rareté.
- **Filtre de Rareté Minimale** : de Common à Mythic.

### 4. ⚙️ Misc (`settings`)
- **Boutique Décoration** :
  - Auto-Buy des caisses de décoration (`FunctionalObjectsCrate` et détection de stock par apprentissage/probe).
- **Sécurité & Continuité** :
  - **Anti-AFK** : simulation d'activité pour empêcher les déconnexions (20 min).
  - **Auto-Reconnexion Serveur** : support des serveurs privés VIP (via lien) et serveurs publics.
  - **Téléportation au Chaudron au Spawn** : recentrage automatique après réapparition.
- **Maintenance** :
  - Sauvegarde et rechargement de la configuration.
  - Réinitialisation de la mémoire d'apprentissage des remotes.
  - Déchargement propre (`Cleanup`) arrêtant tous les threads et connexions.

---

## 📁 Arborescence du Code

```text
PullALuckyFish/
├── Loader.luau                         # Loader racine universel
├── README.md                           # Documentation
└── Menu/
    ├── Loader.luau                     # Loader modulaire
    ├── README.md
    ├── Config/
    │   └── Settings.luau               # Sauvegarde des paramètres
    ├── Core/
    │   ├── Cleanup.luau                # Gestionnaire de déchargement
    │   ├── Executor.luau               # Abstraction sUNC sécurisée
    │   ├── Logger.luau                 # Logs horodatés & notifications UI
    │   └── State.luau                  # État global réactif
    ├── Features/
    │   ├── Halloween/
    │   │   ├── CauldronCast.luau       # Lancer & déblocage
    │   │   ├── CauldronSteer.luau      # Pilote, esquive & ciblage
    │   │   └── HalloweenShop.luau      # Boutique & upgrades chaudron
    │   ├── Misc/
    │   │   ├── AntiAfk.luau            # Anti-déconnexion
    │   │   ├── AutoReconnect.luau      # Reconnexion VIP / public
    │   │   ├── AutoSpawnTp.luau        # TP au spawn
    │   │   └── DecoCrates.luau         # Achat caisses déco
    │   └── Visuals/
    │       └── ESP.luau                # ESP 3D, Chams & Billboards
    ├── Libs/
    │   └── KyriLib.luau                # UI Library KyriLib locale
    ├── UI/
    │   └── Interface.luau              # Structure des onglets & contrôles
    └── Utils/
        ├── GameModules.luau            # Modules & state du jeu
        ├── Helpers.luau                # Constantes & calculs
        ├── Remotes.luau                # Client remote & probe
        └── Services.luau               # Services Roblox protégés
```
