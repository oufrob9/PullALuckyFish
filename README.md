# 🌸 Pull A Lucky Fish — Script Suite

Sleek, high-performance Luau scripts for Roblox.

---

## 🎃 1. AutoCauldron Suite (Interface KyriLib)

Interface modulaire ultra-complète, haute performance et robuste pour l'événement Chaudron d'Halloween & l'automatisation du jeu.

### 🚀 Exécution Simple (1-Liner)

Dans n'importe quel executor Roblox (Solara, Wave, Delta, Celery, Fluxus, etc.) :

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/Loader.luau"))()
```

*Note : Si vous avez téléchargé le script localement dans votre dossier `workspace`, le loader le détecte automatiquement et charge les fichiers en local sans latence.*

```lua
loadstring(readfile("Menu/Loader.luau"))()
```

### 📋 Fonctionnalités par Onglet

- **Accueil (`flame`)** :
  - Statut en direct (position, état plongée, Candy, Mythic Egg, cible, compteurs).
  - Actions rapides : Lancer manuel, Déblocage anti-stuck immédiat, Téléportation au chaudron.
- **Halloween (`ghost`)** :
  - Plongée du Chaudron : Auto-Cast et Auto-Pilote (Steer) haute précision.
  - Priorité absolue Mythic Egg (verrouillage instantané dès apparition) + Mode strict optionnel.
  - Pilotage & Esquive : Répulsion dynamique des Monstres & Mines, pré-alignement en descente, réglage de la marge de sécurité.
  - Magasin d'Halloween : Auto-Buy Spooky Egg, Cursed Egg, Pet Egg (stock 3), Flotteur Divin, Base Haunted Manor, Balai de Sorcière, Canne Faux de la Mort.
  - Améliorations du Chaudron : Machine, Chance (Luck), Capacité, Poids des poissons avec réserve de sécurité de Candy.
- **Visuels (`eye`)** :
  - ESP Chaudron 3D (Bounding Box de zone).
  - Affichage des loots & poissons avec distance et nom.
  - Affichage des monstres avec alerte DANGER.
  - Silhouettes Chams colorées et filtre de rareté minimale.
- **Misc (`settings`)** :
  - Boutique Décoration : Auto-Buy des caisses déco (`FunctionalObjectsCrate` et détection dynamique de stock par probe).
  - Sécurité : Anti-AFK (protection 20 min), Auto-Reconnexion (serveur privé VIP ou serveur public), TP au chaudron à chaque réapparition.
  - Maintenance : Sauvegarde des configurations, réinitialisation des remotes, déchargement propre du script (`Cleanup`).

---

## ⚡ 2. Sakura Automation Suite

Complete automation for **Pull A Lucky Fish** (Auto-Collect Cash, Auto-Buy Eggs & Boxes, Auction House Direct-Buy, Smart Auto-Place & Open, Soft Anti-AFK, Config Persistence).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/main.luau"))()
```

> **UI Toggle Key:** `RightShift` or floating 🌸 button.

---

## 📊 3. Universal Full Game Dumper (Export to TXT)

Full game introspection dumper: scans all native & custom Remotes (Red, Knit, etc.), ModuleScripts & configs, real-time client state / inventory, Workspace entities, ProximityPrompts, and interfaces.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/dumper.luau"))()
```

> **Automatic Export:**
> - Runs immediately upon execution.
> - Saves directly to your executor workspace as `game_dump.txt`.
> - Automatically copies the full dump to your clipboard.
