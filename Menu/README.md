# AutoCauldron Menu

Structure modulaire propre et sans appel distant (100% local, 0 requete GitHub, 0 commentaire).

## Execution

Dans votre executor (Solara, Wave, Delta, Celery, Fluxus, etc.) :

```lua
loadstring(readfile("Menu/Loader.luau"))()
```

Si votre dossier `Menu` est stocke dans un sous-dossier specifique :
```lua
_G.AutoCauldronPath = "scripts/Menu"
loadstring(readfile("scripts/Menu/Loader.luau"))()
```

## Organisation de l'Interface

### 1. Onglet Accueil (`flame`)
- **Statut en Direct** : Suivi de la position (dans/hors zone), etat de la plongee, solde de bonbons d'Halloween, detection du Mythic Egg, cible courante et statistiques globales.
- **Actions Rapides** :
  - *Lancer la Ligne (Cast Manuel)* : declenchement force du lancer.
  - *Debloquer la Ligne (Anti-Stuck)* : envoi de l'interruption / fin de plongee et recentrage au chaudron.
  - *Teleportation au Chaudron* : TP instantane sur la plateforme du chaudron.

### 2. Onglet Halloween (`ghost`)
- **Plongee du Chaudron** :
  - Auto-Cast Chaudron (activation automatique au bord du chaudron).
  - Auto-Pilote de Ligne (pilotage du hamecon vers les poissons et loots).
- **Priorite Mythic Egg** :
  - Priorite Absolue Mythic Egg (verrouille instantanement le hamecon des detection dans le puits).
  - Mode Strict (ignore tout autre objet si aucun Mythic Egg n'est present).
- **Pilotage & Esquive** :
  - Esquive Monstres & Mines (force repulsive dynamique selon la proximite).
  - Pre-Alignement en Descente.
  - Mode de Priorite (`MythicEggFirst`, `CandyMax`, `RarityMax`, `Balanced`).
  - Sliders de rayon de danger et marge verticale des monstres.
- **Magasin d'Halloween** :
  - Auto-Buy General Magasin.
  - Spooky Egg (25k Coins) & Cursed Egg (75k Coins).
  - Halloween Pet Egg (300k Coins - Stock 3).
  - Flotteur Divin Halloween (500k Coins).
  - Base Haunted Manor (1.5M Coins).
  - Monture Balai de Sorciere (5M Coins).
  - Canne Faux de la Mort (20M Coins).
- **Ameliorations du Chaudron** :
  - Machine, Chance (Luck), Capacite Hamecon, Poids des Poissons.
  - Reserve Minimum de Candy (pour preserver vos fonds).

### 3. Onglet Visuels (`eye`)
- **ESP Chaudron** :
  - Box 3D de la zone du chaudron.
  - Affichage des Poissons & Butins avec distance et nom.
  - Affichage des Monstres & Mines avec alerte DANGER.
  - Silhouettes Chams (Highlights colorees par rarete).
  - Filtre de rarete minimale (`Common`, `Uncommon`, `Rare`, `Epic`, `Legendary`, `Mythic`).

### 4. Onglet Misc (`settings`)
- **Boutique Decoration** :
  - Auto-Buy Caisses Deco (`FunctionalObjectsCrate` et stock dynamique via probe).
- **Securite & Continuite** :
  - Anti-AFK (prevention des deconnexions par inactivite 20 min).
  - Auto-Reconnexion Serveur (support serveur prive VIP et serveur public).
  - Teleportation au Chaudron automatique a chaque reaparition (Spawn).
- **Serveur Prive** :
  - Champ texte pour coller votre lien VIP Roblox.
- **Maintenance** :
  - Sauvegarder la configuration.
  - Reinitialiser les remotes appris.
  - Arreter & Decharger proprement le script (`Cleanup`).

## Arborescence du Code

```text
Menu/
├── Loader.luau
├── Config/
│   └── Settings.luau
├── Core/
│   ├── Cleanup.luau
│   ├── Executor.luau
│   ├── Logger.luau
│   └── State.luau
├── Features/
│   ├── Halloween/
│   │   ├── CauldronCast.luau
│   │   ├── CauldronSteer.luau
│   │   └── HalloweenShop.luau
│   ├── Misc/
│   │   ├── AntiAfk.luau
│   │   ├── AutoReconnect.luau
│   │   ├── AutoSpawnTp.luau
│   │   └── DecoCrates.luau
│   └── Visuals/
│       └── ESP.luau
├── Libs/
│   └── KyriLib.luau
├── UI/
│   └── Interface.luau
└── Utils/
    ├── GameModules.luau
    ├── Helpers.luau
    ├── Remotes.luau
    └── Services.luau
```

