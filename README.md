# 🌸 Pull A Lucky Fish — Script Suite (Luau / Roblox)

Suite de scripts Luau pour le jeu **Pull A Lucky Fish** sur Roblox (`PlaceId: 112781315318195`, version `UPDATEpet`).

Ce dépôt contient **2 scripts distincts** conçus spécifiquement pour une progression en deux étapes sécurisée :

1. **`debug_probe.luau`** : Outil de diagnostic et de test sécurisé pour votre compte principal (vérifie chaque Remote individuellement, simule l'Auto-Sell en Dry-Run sans rien vendre, inspecte le cash, les œufs, etc.).
2. **`ui_sakura.luau`** : Interface graphique magnifique sur le thème **Sakura / Fleur de cerisier**, avec de vraies icônes Roblox, animations fluides, navigation par onglets et structure de callbacks prête pour brancher le backend.

---

## 🚀 Comment Lancer les Scripts en Jeu

### Option 1 : Interface Sakura UI (Visuel & Structure complète)
Copiez-collez cette ligne dans votre exécuteur Roblox :
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/ui_sakura.luau"))()
```

### Option 2 : Diagnostic Probe (Tests sûrs pour Compte Principal)
Copiez-collez cette ligne dans votre exécuteur Roblox :
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/debug_probe.luau"))()
```

### Option 3 : Loader Unifié
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/loader.luau"))()
```

---

## 📑 Répartition des Fonctionnalités

### 🌸 1. Auto-Farm & Force
- **Auto Train** : Entraînement continu de la force avec cadence personnalisable (1 à 30 CPS).
- **Auto Equip Best Dumbbell** : Équipe automatiquement l'haltère le plus fort dans le sac.
- **Auto Collect Cash** : Ramasse instantanément l'argent généré par tous les plots de votre base.
- **Upgrade All Fish** : Améliore les poissons de votre base avec seuil de sécurité pour préserver votre solde.

### 📦 2. Boîtes & Œufs
- **Auto Open Placed Boxes** : Ouvre les boîtes de butin posées sur votre île.
- **Auto Hatch Eggs** : Fait éclore les œufs dès la fin de l'incubation.
- **Auto Skip Timer** : Tente de passer le chrono d'attente des œufs.
- **Auto Buy Eggs & Boxes** : Achète automatiquement les œufs (`ForestEgg`, `FarmEgg`) et caisses de flotteurs (`CommonFloatCrate`, `RareFloatCrate`).

### 🐟 3. Vente Avancée (Filtre Intelligent)
- **Auto Sell Master** : Vente automatique par lot (`SellFishBatch`).
- **Protection des Mutations** : Ne vend **JAMAIS** les poissons possédant des mutations rares (Shiny, Rainbow, Radioactive...).
- **Filtre de Raretés** : Cochez exactement quelles raretés vous autorisez à vendre (ex : Common et Uncommon uniquement).
- **Mode Dry-Run** : Permet de tester le filtre dans la console sans vendre un seul poisson.

### 🧬 4. DNA Lab
- **Auto Grind Fish for DNA** : Envoie au broyeur uniquement les doublons et poissons de basse rareté pour obtenir des fioles d'ADN (`DnaVial`).
- **Auto Start & Claim DNA** : Lance et récolte automatiquement les montées de niveau d'ADN dans le laboratoire.

### 📍 5. Téléportations Instantanées
- 🏠 Base Plot (Votre île)
- 🎣 Zone de Pêche Principale (`Workspace.ThrowZone`)
- 🏪 Magasin Central (`Workspace.Shop`)
- 🏘️ Fishing Village (Quêtes & PNJ)
- 🧬 DNA Lab & Grinder
- 🤿 The Deeps (Zone Abysses)
- ☢️ Silo & Réacteur Nucléaire
- 🛸 Biome Extraterrestre (Alien Ocean)

### ⚙️ 6. Sécurité & Utilitaires
- **Anti-AFK Doux** : Intercepte le signal `Idled` via `VirtualUser` pour empêcher la déconnexion des 20 minutes (**SANS auto-rejoin** pour respecter vos souhaits).
- **Modificateurs Joueur** : Vitesse de course personnalisable (WalkSpeed) et Noclip.
- **Boost FPS** : Possibilité de masquer les familiers 3D et de couper les cinématiques.

---

## 🛡️ Sécurité Compte Principal

Pour préserver votre compte :
1. Lancez d'abord `debug_probe.luau` pour inspecter vos données et tester les remotes de façon unitaire.
2. Utilisez le bouton **"Auto-Sell DRY-RUN"** pour vérifier ce que le filtre considérerait comme vendable avant d'activer toute vente réelle.
3. Aucune fonctionnalité risquée (suppression aveugle, perte de gemmes) n'est activée sans confirmation.
