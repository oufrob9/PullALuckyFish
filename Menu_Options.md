# 🎣 Pull A Lucky Fish — Spécification Complète des Options du Menu UI

> **Source d'analyse :** `luckyfish_ultra_debug.txt` (10 430 lignes, 268 Remotes, 83 modules de config, état client complet)  
> **Jeu :** Roblox — *Pull A Lucky Fish* (PlaceId: `112781315318195`, Version `UPDATEpet`)

---

## 📑 Sommaire des Onglets

1. [🎣 Auto-Fishing (Pêche Automatique)](#1--auto-fishing-pêche-automatique)
2. [💪 Auto-Train & Force (Entraînement)](#2--auto-train--force-entraînement)
3. [💰 Économie & Tycoon (Vente, Cash & Slots)](#3--économie--tycoon-vente-cash--slots)
4. [🔄 Rebirth & Progression](#4--rebirth--progression)
5. [🐾 Pets, Œufs & DNA Lab](#5--pets-œufs--dna-lab)
6. [🤿 The Deeps (Les Abysses)](#6--the-deeps-les-abysses)
7. [🚀 Événements & Mini-Jeux Spéciaux](#7--événements--mini-jeux-spéciaux)
8. [🎁 Récompenses, Freebies & Quêtes](#8--récompenses-freebies--quêtes)
9. [🎒 Gestion d'Inventaire, Coffre & Équipement](#9--gestion-dinventaire-coffre--équipement)
10. [🗺️ Téléportations & Mondes](#10-️-téléportations--mondes)
11. [⚡ Player & Visuals (Utilitaires & QoL)](#11--player--visuals-utilitaires--qol)
12. [⚙️ Profils & Presets Recommandés](#12-️-profils--presets-recommandés)

---

## 1. 🎣 Auto-Fishing (Pêche Automatique)

Le système de pêche repose sur une chaîne d'événements : `FishingCastBegin` ➔ `FishingRemoteCast` ➔ `FishingRemoteStage` ➔ `FishingStage` / `ThrowData`.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Fish** | `Toggle` | ON / OFF | `FishingRemoteCast`, `FishingStage` | Lance la ligne, valide instantanément les mini-jeux de lancer/moulinet et capture le poisson automatiquement. |
| **Mode de Lancer** | `Dropdown` | *Instantané*, *Legit / Temporisé*, *Perfect Timing* | `ThrowData` | Choix entre capture à la milliseconde ou simulation de timing naturel avec délai réglable. |
| **Délai de Lancer (Cast Delay)** | `Slider` | `0.0s` à `3.0s` (par pas de 0.1s) | Timing client | Délai d'attente entre deux lancers consécutifs. |
| **Distance Ciblée (Zone / Biome)** | `Dropdown` | *Max Possible*, *Biome Spécifique*, *Distance Fixe* | `BiomesConfig`, `SetThrowZoneState` | Permet de cibler un biome précis (ex: Candy, Dino, SCP, Backrooms, Celestial, Hacked) selon la force disponible. |
| **Distance Manuelle** | `Slider` | `10` à `10 000+` studs | `ThrowData.distance` | Ajuste manuellement la puissance du lancer de la canne. |
| **Auto-Bypass Mini-jeu** | `Toggle` | ON / OFF | `FishingRemoteStage` | Valide automatiquement les checks de réussite du ferrage sans interaction requise. |
| **Bypass Vitesse de Moulinet** | `Toggle` | ON / OFF | `RequestUpgradeRollSpeed` | Supprime l'animation de moulinage pour ramener le poisson instantanément. |
| **Auto Equip Best Rod** | `Toggle` | ON / OFF | `EquipFishRod`, `BuyFishRod` | Équipe automatiquement la meilleure canne possédée (ou achète la prochaine débloquée). |
| **Auto Equip Best Float (Bouchon)** | `Toggle` | ON / OFF | `EquipFishingFloat`, `FishingFloatsConfig` | Équipe le flotteur offrant les meilleurs multiplicateurs de chance et de mutation. |

---

## 2. 💪 Auto-Train & Force (Entraînement)

La force détermine jusqu'à quel biome la ligne peut être lancée et la rareté maximale atteignable.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Train** | `Toggle` | ON / OFF | `Train` | Déclenche l'entraînement en continu sans avoir à cliquer manuellement avec l'haltère en main. |
| **Vitesse de Clic (CPS / Delay)** | `Slider` | `1` à `50` CPS (`0.02s` à `1.0s`) | Fréquence d'appel de `Train` | Cadence des requêtes d'entraînement (permet d'éviter les ratés ou le rate-limit). |
| **Auto Equip Best Dumbbell** | `Toggle` | ON / OFF | `EquipTrainingTool` | Sélectionne l'haltère le plus puissant dans le sac dès qu'il est débloqué. |
| **Auto Buy Training Tools** | `Toggle` | ON / OFF | `BuyTrainingTool`, `TrainToolConfig` | Achète automatiquement les nouveaux haltères chez le vendeur dès que les fonds le permettent. |
| **Mode Hybride (Train ➔ Fish)** | `Toggle` | ON / OFF | Logique combinée | Alterne automatiquement entre entraînement et pêche selon des paliers définis ci-dessous. |
| **Seuil Min Force pour Pêcher** | `Slider` | `100` à `100 000 000 000` | Condition `strength` | Entraîne la force jusqu'au palier requis, puis passe en mode pêche. |
| **Entraînement Post-Rebirth** | `Slider` | `0s` à `180s` | Timer après `RequestRebirth` | Durée pendant laquelle le script se focalise 100% sur le train immédiatement après un rebirth. |

---

## 3. 💰 Économie & Tycoon (Vente, Cash & Slots)

Gère les slots de plot/tycoon où les poissons génèrent du cash passif et le cycle de vente automatique.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Collect Cash** | `Toggle` | ON / OFF | `RequestCollectCash`, `AutoCollectActivated` | Ramasse instantanément l'argent généré par tous les poissons posés sur la base. |
| **Intervalle de Collecte** | `Slider` | `0.1s` à `15s` | Boucle de collecte | Fréquence de ramassage du cash sur la base. |
| **Auto Sell Mode** | `Dropdown` | *Immédiat au catch*, *Inventaire Plein*, *Intervalle Réfléchi* | `SellFishBatch`, `SellAllFish` | Déclenche la vente des poissons non protégés. |
| **Filtre de Vente par Rareté** | `Multi-Dropdown` | Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Godly, Celestial, Hacked, Dino, SCP, Backroom, Secret, OG | `ToggleAutoSellRarity`, `rarityConfig` | Coche les raretés autorisées à la vente automatique. |
| **Protection des Mutations** | `Toggle` | ON / OFF | `ToggleAutoSellKeepMutation`, `MutationConfig` | Empêche la vente des poissons ayant des mutations (Shiny, Rainbow, Radioactive, etc.). |
| **Nb Min Mutations à Garder** | `Slider` | `0` à `5` | `SetAutoSellKeepMutationCount` | Ne vend pas les poissons possédant au moins X mutations. |
| **Seuil Min Cash pour Vente** | `Textbox / Slider` | `0` à `1e20+` | `SetAutoSellMinEarnings` | Ne vend que si la valeur du lot dépasse un montant configuré. |
| **Auto Equip Best Fish on Base** | `Toggle` | ON / OFF | `RequestEquipBest`, `RequestPlaceFish` | Place automatiquement les poissons au DPS/Cash le plus élevé sur les plots de la base. |
| **Auto Upgrade Base Fish** | `Toggle` | ON / OFF | `RequestUpgradeFish` | Améliore le niveau des poissons posés sur la base pour maximiser le revenu passif. |
| **Auto Buy Base Slots** | `Toggle` | ON / OFF | `BuyFishingSlot`, `RequestBuySlotUpgrade` | Débloque automatiquement les emplacements de poissons supplémentaires sur la base. |
| **Auto Upgrade Vitesses** | `Multi-Dropdown` | *Pull Speed*, *Roll Speed*, *Throw Speed* | `RequestUpgradePullSpeed`, `RequestUpgradeRollSpeed`, `RequestUpgradeThrowSpeed` | Investit les gains dans l'augmentation permanente des 3 vitesses clés. |

---

## 4. 🔄 Rebirth & Progression

Le Rebirth réinitialise la force mais accorde des multiplicateurs massifs de gains, de nouveaux biomes et de nouvelles fonctionnalités.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Rebirth** | `Toggle` | ON / OFF | `RequestRebirth`, `RebirthConfig` | Effectue automatiquement le Rebirth dès que les prérequis (Cash + Force) sont remplis. |
| **Niveau Rebirth Cible** | `Slider` | `1` à `50` (ou infini) | `RebirthConfig` | Arrête le Rebirth automatique une fois le palier souhaité atteint. |
| **Réserve d'Argent avant Rebirth** | `Slider / Textbox`| `0` à `1e20+` | Condition avant rebirth | Conserve un stock minimal de monnaie avant de déclencher le Rebirth. |
| **Auto Unlock Worlds** | `Toggle` | ON / OFF | `UnlockWorld`, `TravelToWorld` | Débloque automatiquement le Monde 2 et les zones supérieures dès l'éligibilité. |
| **Auto Unlock Fishing Village** | `Toggle` | ON / OFF | `UnlockFishingVillage` | Débloque le Village des Pêcheurs (requis pour le labo DNA, l'enchanteur et l'hôtel des ventes). |

---

## 5. 🐾 Pets, Œufs & DNA Lab (UPDATEpet)

Système majeur issu de la dernière mise à jour du jeu.

### A. Œufs & Familers (Pets)
| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Buy Eggs** | `Toggle` | ON / OFF | `BuyEgg`, `EggConfig` | Achète les œufs disponibles dans le shop (ForestEgg, FarmEgg, etc.). |
| **Auto Place Eggs** | `Toggle` | ON / OFF | `PlaceEgg` | Pose automatiquement les œufs dans les incubateurs de votre base. |
| **Auto Hatch Eggs** | `Toggle` | ON / OFF | `HatchEgg`, `EggHatched` | Fait éclore les œufs dès que leur incubation est terminée. |
| **Auto Skip Egg Timer** | `Toggle` | ON / OFF | `SkipEggTimer` | Tente de passer le délai d'incubation si éligible ou disponible. |
| **Auto Equip Best Pets** | `Toggle` | ON / OFF | `EquipPet`, `SelectPetLoadout` | Équipe la combinaison de familiers offrant les meilleurs bonus globaux. |
| **Auto Delete Low Tier Pets** | `Multi-Dropdown` | Liste des raretés de pets | `DeletePet` | Supprime automatiquement les pets indésirables pour libérer l'inventaire. |
| **Auto Buy Pet Slots** | `Toggle` | ON / OFF | `BuyPetSlot` | Augmente le nombre maximal de familiers équipables en simultané. |

### B. DNA Lab & Broyeur (Grinder)
| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Grind Fish for DNA** | `Toggle` | ON / OFF | `GrindFishForDna`, `DnaConfig` | Transforme les poissons en double ou de basse rareté en fioles d'ADN (`DnaVial`). |
| **Filtre Poissons à Broyer** | `Multi-Dropdown` | Raretés éligibles | `DnaConfig.KindsByRarity` | Sélectionne quelles catégories de poissons envoyer au broyeur. |
| **Auto Start DNA Leveling** | `Toggle` | ON / OFF | `StartDnaLeveling` | Démarre les recherches et montées de niveau d'ADN dans le labo. |
| **Auto Claim DNA Results** | `Toggle` | ON / OFF | `ClaimDnaLeveling` | Récupère l'ADN amélioré une fois le cycle terminé. |
| **Auto Buy DNA Lab Slots** | `Toggle` | ON / OFF | `BuyDnaLabSlot` | Débloque les cuves de laboratoire supplémentaires. |

---

## 6. 🤿 The Deeps (Les Abysses)

Zone sous-marine spéciale avec mécaniques de plongée, bouteille d'oxygène, palmes et poissons abyssaux.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Farm Deeps** | `Toggle` | ON / OFF | `DeepsCatchStart`, `DeepsCatchFinish` | Pêche en continu dans la zone des abysses. |
| **Auto Pickup Abyss Items** | `Toggle` | ON / OFF | `DeepsPickupItem` | Ramasse automatiquement tous les trésors et loots tombés au fond de l'eau. |
| **Auto Process Abyss Loot** | `Toggle` | ON / OFF | `DeepsProcessLoot` | Ouvre et valide le butin accumulé dans le filet abyssal (`BAG_Net`). |
| **Auto Equip Best Deeps Gear** | `Toggle` | ON / OFF | `EquipDeepsGear`, `BuyDeepsGear` | Équipe le meilleur matériel de plongée (Bouteille d'oxygène, Sac, Palmes Abyss). |
| **Bypass Échec / Sauvetage** | `Toggle` | ON / OFF | `DeepsForfeitRecovery`, `UseFreeRevive` | Empêche la perte de butin en cas de manque d'oxygène ou utilise le revive gratuit. |

---

## 7. 🚀 Événements & Mini-Jeux Spéciaux

Le jeu propose une grande variété d'événements et de machines spéciales identifiés dans le debug.

### A. Silo Nucléaire & Réacteur Radioactif
| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Feed Reactor** | `Toggle` | ON / OFF | `ReactorDeposit`, `NuclearReactorConfig` | Dépose les poissons radioactifs dans le réacteur nucléaire. |
| **Auto Claim Reactor** | `Toggle` | ON / OFF | `ReactorClaim` | Récupère les récompenses énergétiques du réacteur. |
| **Auto Upgrade Reactor** | `Toggle` | ON / OFF | `ReactorBuyUpgrade` | Améliore le rendement et la capacité du réacteur. |
| **Auto Launch Nuke (Silo)** | `Toggle / Bouton`| ON / OFF | `NuclearSiloSubmit`, `NuclearSiloDetonate` | Fournit les composants et déclenche le tir du missile nucléaire pour le boost serveur. |
| **Bypass Cinématique Nuke** | `Toggle` | ON / OFF | `NukeCutsceneConfig`, `PlayNukeCutscene` | Coupe l'animation de cutscene lors de l'explosion nucléaire. |

### B. Océan Extraterrestre (Alien Event)
| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Alien Catch** | `Toggle` | ON / OFF | `AlienCatchStart`, `AlienCatchFinish` | Pêche automatiquement les poissons aliens dans la zone OVNI. |
| **Auto Collect & Deposit Fuel**| `Toggle` | ON / OFF | `AlienCollectFuel`, `AlienDepositFuelTank` | Ramasse les bidons de carburant alien et les verse dans le vaisseau. |
| **Auto Alien Research** | `Toggle` | ON / OFF | `AlienResearchInsert`, `AlienResearchCollect` | Insère les poissons aliens dans le centre de recherche et récupère les technologies. |
| **Auto Alien Upgrades** | `Toggle` | ON / OFF | `AlienBuyUpgrade` | Débloque les améliorations exclusives du shop alien. |

### C. Alchimie, Cuisine, Jardin & Enchanteur
| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Alchemy Potions** | `Toggle` | ON / OFF | `RequestInsertAlchemyFish`, `RequestClaimAlchemyPotion` | Prépare en boucle des potions à la table d'alchimie avec vos poissons. |
| **Auto Kitchen / Cooking** | `Toggle` | ON / OFF | `CookingInsertFish`, `CookingStartCook`, `CookingClaim` | Cuisiner les poissons pour gagner des `cookingPoints` et bonus de stats. |
| **Auto Garden Harvest** | `Toggle` | ON / OFF | `RequestClaimGardenDrill`, `RequestUpgradeGardenSection` | Récolte la foreuse de jardin et achète les parcelles agricoles du domaine. |
| **Auto Enchant Rod** | `Toggle` | ON / OFF | `RequestEnchantRoll`, `EnchantStone` | Utilise les `EnchantStone` pour roll l'enchantement parfait sur votre canne. |
| **Filtre Enchantement Cible** | `Dropdown` | Liste des enchantements | `EnchantConfig` | S'arrête dès que l'enchantement choisi (ou supérieur) apparaît. |
| **Auto Recycle Floats** | `Toggle` | ON / OFF | `RequestRecycleFloats` | Recycle automatiquement les bouchons de pêche en surplus dans la machine. |

---

## 8. 🎁 Récompenses, Freebies & Quêtes

Automatisation de toutes les récompenses gratuites pour ne rater aucun bonus.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Claim Free Gifts** | `Toggle` | ON / OFF | `RequestFreeGiftClaim`, `FreeGiftConfig` | Récupère tous les cadeaux chronométrés au fur et à mesure de leur disponibilité. |
| **Auto Claim Daily Login** | `Toggle` | ON / OFF | `RequestClaimDailyLogin`, `DailyLoginConfig` | Valide la récompense de connexion journalière à minuit. |
| **Auto Claim Quests** | `Toggle` | ON / OFF | `RequestClaimQuest`, `RequestClaimQuestMilestone` | Valide et récupère automatiquement les quêtes quotidiennes terminées. |
| **Auto Claim Milestones** | `Toggle` | ON / OFF | `RequestClaimMilestone`, `MilestonesConfig` | Récupère les récompenses de progression de palier général. |
| **Auto Claim Index Rewards** | `Toggle` | ON / OFF | `RequestClaimIndexReward`, `RequestClaimIndexMilestone` | Récupère les récompenses pour chaque nouvelle espèce de poisson enregistrée dans l'index. |
| **Auto Click Bonus** | `Toggle` | ON / OFF | `ClaimClickBonus`, `ShowClickBonus` | Récupère instantanément les popups de bonus de clic aléatoires. |
| **Auto Redeem Codes** | `Bouton` | Clic unique | `RequestCodeRedeem` | Teste et active automatiquement une liste des codes promo actifs du jeu. |
| **Auto Open Luckyblocks** | `Toggle` | ON / OFF | `OpenLuckyblock`, `ClaimLuckyblockFish` | Ouvre instantanément les Luckyblocks placés ou ramassés (ex: Rainbow, Cat, Spiderman). |

---

## 9. 🎒 Gestion d'Inventaire, Coffre & Équipement

Gestion des stocks et maintien des potions actives.

| Option | Type UI | Valeurs / Plage | Remote / Mécanique associée | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Auto Use Potions** | `Multi-Dropdown` | *Luck*, *Speed*, *Training*, *Weather* | `RequestUsePotion`, `PotionConfig` | Boit automatiquement une nouvelle potion dès que le buff précédent expire. |
| **Auto Deposit Vault** | `Toggle` | ON / OFF | `RequestDepositVaultFish`, `RequestDepositAllVaultFish` | Dépose les poissons les plus rares ou favoris dans le coffre-fort sécurisé. |
| **Auto Withdraw Vault** | `Bouton` | Clic unique | `RequestWithdrawVaultFish` | Récupère les poissons du coffre-fort. |
| **Auto Mount Equip** | `Toggle` | ON / OFF | `RequestEquipMount`, `RequestToggleMount` | Monte automatiquement sur votre monture aquatique (Requin Primal, Espadon, Baudroie). |
| **Protection Anti-Vente (Favoris)**| `Toggle` | ON / OFF | `ToggleFavorite` | Marque automatiquement les poissons Mythic+ / Secret en favoris. |

---

## 10. 🗺️ Téléportations & Mondes

Téléportation instantanée vers tous les points d'intérêt clés repérés dans le jeu.

| Option | Type UI | Valeurs / Plage | Coordonnées / Mécanique | Description |
| :--- | :--- | :--- | :--- | :--- |
| **TP Base Plot** | `Bouton` | Téléport CFrame | Emplacement de votre base personnelle | Retour instantané à son plot. |
| **TP Zone de Pêche Principale**| `Bouton` | Téléport CFrame | `Workspace.ThrowZone` | Se place au bord du ponton de lancer optimal. |
| **TP Shop Central** | `Bouton` | Téléport CFrame | `Workspace.Shop` | Téléportation devant les marchands de cannes et d'haltères. |
| **TP Village des Pêcheurs** | `Bouton` | Téléport CFrame | `FishingVillage` | Accès direct aux PNJ d'enchères, de guilde et de quêtes. |
| **TP DNA Lab & Grinder** | `Bouton` | Téléport CFrame | `DnaLab` / `DnaGrinder` | Téléportation devant le combinat génétique. |
| **TP The Deeps (Abysses)** | `Bouton` | Téléport CFrame | Zone Abyss | Plonge directement dans la zone sous-marine. |
| **TP Silo & Réacteur Nucléaire**| `Bouton` | Téléport CFrame | `EventRadioactive` | Téléportation au réacteur pour déposer ses ressources. |
| **TP Océan Alien** | `Bouton` | Téléport CFrame | Zone Alien | Téléportation dans le biome extraterrestre. |
| **Voyager vers Monde 1 / 2** | `Dropdown + Bouton`| World 1, World 2 | `TravelToWorld` | Change de serveur / monde sans passer par les portails. |

---

## 11. ⚡ Player & Visuals (Utilitaires & QoL)

Amélioration des performances, sécurité et personnalisation du joueur.

| Option | Type UI | Valeurs / Plage | Mécanique | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Anti-AFK** | `Toggle` | ON / OFF | `Idled:Connect`, VirtualUser | Empêche la déconnexion Roblox après 20 minutes d'inactivité. |
| **Simulate Anti-Afk Rejoin** | `Toggle` | ON / OFF | `SimulateAntiAfkRejoin` | Utilise le système natif du jeu pour reconnecter le joueur en cas de déconnexion. |
| **WalkSpeed Modifier** | `Slider` | `16` à `150` | `Humanoid.WalkSpeed` | Augmente la vitesse de déplacement au sol. |
| **JumpPower / Infinite Jump** | `Toggle + Slider`| ON / OFF | `Humanoid.JumpPower` | Permet de sauter à l'infini dans les airs. |
| **Noclip** | `Toggle + Keybind`| ON / OFF | `CanCollide = false` | Permet de traverser les murs et structures. |
| **Désactiver les Cutscenes** | `Toggle` | ON / OFF | Module `Cutscene`, `NukeCutscene` | Supprime toutes les animations de cinématiques (vol de village, nuke, tutoriel). |
| **Désactiver Effets & Particules**| `Toggle` | ON / OFF | Module `VFX`, `ShowupEffects` | Réduit considérablement l'usage CPU/GPU en cachant les effets visuels de pêche. |
| **Cacher les Familiers (Pets)** | `Toggle` | ON / OFF | `SetPetsHidden` | Masque les modèles 3D des familiers pour éliminer les saccades. |
| **White Screen / GPU Saver** | `Toggle` | ON / OFF | `RunService:Set3dRenderingEnabled` | Désactive le rendu 3D de Roblox pour le farming nocturne AFK (gain FPS maximal). |

---

## 12. ⚙️ Profils & Presets Recommandés

| Profil | Configuration Activée | Cas d'utilisation |
| :--- | :--- | :--- |
| **🌟 AFK Fish & Sell (Nuit)** | Auto Fish (Instantané) + Auto Sell (Common à Rare) + Keep Mutations + Auto Collect Cash + Anti-AFK + GPU Saver | Farm intensif de cash et de poissons pendant la nuit sans risque de saturation d'inventaire. |
| **⚡ Rebirth Rusher** | Auto Train (50 CPS) + Auto Rebirth + Post-Rebirth Train (60s) + Auto Buy Dumbbell + Auto Upgrade Speeds | Monte les paliers de Rebirth à la vitesse maximale de manière 100% autonome. |
| **🧪 DNA & Pet Breeder** | Auto Buy Eggs + Auto Place & Hatch + Auto Grind Fish for DNA + Auto Start DNA Leveling + Auto Claim | Optimise l'arbre génétique et la collection de familiers sans micro-gestion. |
| **☢️ Event & Boss Grinder** | Auto Reactor Feed & Claim + Auto Alien Fuel & Research + Auto Deeps Pickup + Auto Potions | Maximise les monnaies d'événements et les récompenses rares d'événements limités. |

---

*Fichier généré automatiquement pour le projet `PullALuckyFishScript`.*
