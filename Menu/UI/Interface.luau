local Interface = {}
function Interface.init(
    KyriLib,
    Services,
    State,
    Executor,
    Settings,
    Helpers,
    RemotesUtils,
    CauldronCast,
    DecoCrates,
    Logger,
    Cleanup
)
    if not KyriLib then
        Logger.warn("KyriLib est introuvable.")
        return
    end
    local window = KyriLib.new("AutoCauldron", {
        GameName = "PullALuckyFish",
        AutoLoad = "default",
    })
    Logger.setNotifyHandler(function(title, message, duration)
        pcall(function()
            window:notify(title, message, duration or 3)
        end)
    end)
    Cleanup.onCleanup(function()
        pcall(function()
            if window and typeof(window.destroy) == "function" then
                window:destroy()
            end
        end)
    end)
    local tabHome = window:tab("Accueil", "flame")
    local statusParagraph = tabHome:paragraph("Statut en Direct", "Initialisation en cours...")
    tabHome:section("Actions Rapides")
    tabHome:button("Lancer la Ligne (Cast Manuel)", function()
        local btn = CauldronCast.findCastButton(Services)
        if btn then
            Executor.activateGuiButton(btn)
            Logger.notify("Cast", "Lancement force effectue.", 2)
        else
            Logger.notify("Cast", "Bouton de lancer introuvable.", 2)
        end
    end)
    tabHome:button("Debloquer la Ligne (Anti-Stuck)", function()
        CauldronCast.unblockStuckDive()
        Logger.notify("Anti-Stuck", "Deblocage active.", 2)
    end)
    tabHome:button("Teleportation au Chaudron", function()
        Helpers.teleportToCauldron(Services)
        Logger.notify("Teleportation", "Arrivee sur la plateforme du chaudron.", 2)
    end)
    local tabHalloween = window:tab("Halloween", "ghost")
    tabHalloween:section("Plongee du Chaudron")
    tabHalloween:toggle("Auto-Cast Chaudron", State.AutoCast, function(val)
        State.AutoCast = val
    end, "AutoCast")
    tabHalloween:toggle("Auto-Pilote de Ligne", State.AutoSteer, function(val)
        State.AutoSteer = val
        if not val then
            State.CurrentTargetScreenPos = nil
            Cleanup.releaseSteerKeys()
        end
    end, "AutoSteer")
    tabHalloween:section("Priorite Mythic Egg")
    tabHalloween:toggle("Priorite Absolue Mythic Egg", State.MythicEggMaxPriority, function(val)
        State.MythicEggMaxPriority = val
    end, "MythicEggMaxPriority")
    tabHalloween:toggle("Mode Strict (Uniquement Mythic Egg)", State.MythicEggFocusOnly, function(val)
        State.MythicEggFocusOnly = val
    end, "MythicEggFocusOnly")
    tabHalloween:section("Pilotage & Esquive")
    tabHalloween:toggle("Esquive Monstres & Mines", State.AvoidMonsters, function(val)
        State.AvoidMonsters = val
    end, "AvoidMonsters")
    tabHalloween:toggle("Pre-Alignement en Descente", State.DescentPreAlign, function(val)
        State.DescentPreAlign = val
    end, "DescentPreAlign")
    tabHalloween:dropdown("Mode de Priorite", { "MythicEggFirst", "CandyMax", "RarityMax", "Balanced" }, State.SteerPriorityMode, function(selected)
        State.SteerPriorityMode = selected
    end, "SteerPriorityMode")
    tabHalloween:slider("Rayon Danger Monstres", 2, 20, State.MonsterDangerRadius, function(val)
        State.MonsterDangerRadius = val
    end, "MonsterDangerRadius", 0.5)
    tabHalloween:slider("Marge Verticale Monstres", 1, 15, State.MonsterVerticalGrace, function(val)
        State.MonsterVerticalGrace = val
    end, "MonsterVerticalGrace", 0.5)
    tabHalloween:section("Magasin d'Halloween")
    tabHalloween:toggle("Auto-Buy General Magasin", State.AutoBuyHalloweenShop, function(val)
        State.AutoBuyHalloweenShop = val
    end, "AutoBuyHalloweenShop")
    tabHalloween:toggle("Spooky Egg (25k Coins)", State.AutoBuyEggA, function(val)
        State.AutoBuyEggA = val
    end, "AutoBuyEggA")
    tabHalloween:toggle("Cursed Egg (75k Coins)", State.AutoBuyEggB, function(val)
        State.AutoBuyEggB = val
    end, "AutoBuyEggB")
    tabHalloween:toggle("Halloween Pet Egg (300k Coins - Stock 3)", State.AutoBuyPetEgg, function(val)
        State.AutoBuyPetEgg = val
    end, "AutoBuyPetEgg")
    tabHalloween:toggle("Flotteur Divin Halloween (500k Coins)", State.AutoBuyGodlyFloat, function(val)
        State.AutoBuyGodlyFloat = val
    end, "AutoBuyGodlyFloat")
    tabHalloween:toggle("Base Haunted Manor (1.5M Coins)", State.AutoBuyHauntedBase, function(val)
        State.AutoBuyHauntedBase = val
    end, "AutoBuyHauntedBase")
    tabHalloween:toggle("Monture Balai de Sorciere (5M Coins)", State.AutoBuyWitchBroom, function(val)
        State.AutoBuyWitchBroom = val
    end, "AutoBuyWitchBroom")
    tabHalloween:toggle("Canne Faux de la Mort (20M Coins)", State.AutoBuyDeathScythe, function(val)
        State.AutoBuyDeathScythe = val
    end, "AutoBuyDeathScythe")
    tabHalloween:section("Ameliorations du Chaudron")
    tabHalloween:toggle("Upgrade Machine Chaudron", State.AutoUpgradeMachine, function(val)
        State.AutoUpgradeMachine = val
    end, "AutoUpgradeMachine")
    tabHalloween:toggle("Upgrade Chance (Luck)", State.AutoUpgradeLuck, function(val)
        State.AutoUpgradeLuck = val
    end, "AutoUpgradeLuck")
    tabHalloween:toggle("Upgrade Capacite Hamecon", State.AutoUpgradeCapacity, function(val)
        State.AutoUpgradeCapacity = val
    end, "AutoUpgradeCapacity")
    tabHalloween:toggle("Upgrade Poids Poissons", State.AutoUpgradeHeavier, function(val)
        State.AutoUpgradeHeavier = val
    end, "AutoUpgradeHeavier")
    tabHalloween:slider("Reserve Minimum Candy", 0, 500000, State.MinCandyReserve, function(val)
        State.MinCandyReserve = val
    end, "MinCandyReserve", 1000)
    local tabVisuals = window:tab("Visuels", "eye")
    tabVisuals:section("Configuration ESP")
    tabVisuals:toggle("ESP Global Active", State.EspEnabled, function(val)
        State.EspEnabled = val
    end, "EspEnabled")
    tabVisuals:toggle("Afficher Poissons & Butin", State.EspShowLoot, function(val)
        State.EspShowLoot = val
    end, "EspShowLoot")
    tabVisuals:toggle("Afficher Monstres & Mines", State.EspShowMonsters, function(val)
        State.EspShowMonsters = val
    end, "EspShowMonsters")
    tabVisuals:toggle("Afficher Zone du Chaudron", State.EspShowZone, function(val)
        State.EspShowZone = val
    end, "EspShowZone")
    tabVisuals:toggle("Silhouettes Chams", State.EspChams, function(val)
        State.EspChams = val
    end, "EspChams")
    tabVisuals:dropdown("Rarete Minimale ESP", { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }, State.EspMinRarity, function(selected)
        State.EspMinRarity = selected
    end, "EspMinRarity")
    local tabMisc = window:tab("Misc", "settings")
    tabMisc:section("Boutique Decoration")
    tabMisc:toggle("Auto-Buy Caisses Deco (Functional Objects)", State.AutoBuyDecoCrate, function(val)
        State.AutoBuyDecoCrate = val
    end, "AutoBuyDecoCrate")
    tabMisc:section("Securite & Continuite")
    tabMisc:toggle("Anti-AFK", State.AntiAfk, function(val)
        State.AntiAfk = val
    end, "AntiAfk")
    tabMisc:toggle("Auto-Reconnexion Serveur", State.AutoReconnect, function(val)
        State.AutoReconnect = val
    end, "AutoReconnect")
    tabMisc:toggle("Teleportation au Chaudron au Spawn", State.AutoTpOnSpawn, function(val)
        State.AutoTpOnSpawn = val
    end, "AutoTpOnSpawn")
    tabMisc:section("Serveur Prive (VIP)")
    tabMisc:input("Lien Serveur Prive", "Collez votre lien VIP Roblox ici...", function(text)
        State.PrivateServerLink = text
    end, "PrivateServerLink")
    tabMisc:section("Maintenance")
    tabMisc:button("Sauvegarder la Configuration", function()
        Settings.save(State, Executor)
        Logger.notify("Sauvegarde", "Configuration enregistree sur l'executor.", 2)
    end)
    tabMisc:button("Reinitialiser les Remotes Appris", function()
        RemotesUtils.resetLearned()
        Logger.notify("Remotes", "Variantes d'arguments reinitialisees.", 2)
    end)
    tabMisc:button("Arreter & Decharger le Script", function()
        Cleanup.execute(State, Executor)
        Logger.notify("Dechargement", "AutoCauldron a ete desactive proprement.", 3)
    end)
    local statusThread = task.spawn(function()
        while State.Running do
            pcall(function()
                local inZoneStr = State.InZone and "Dans la Zone" or "Hors Zone"
                local diveStr = State.CurrentDiveActive and "Plongee en cours" or "En attente"
                local targetStr = State.CurrentTargetCand and string.format("%s (%s)", State.CurrentTargetCand.Name, State.CurrentTargetCand.Rarity) or "Aucune"
                local mythicStr = State.MythicEggInShaft and "DETECTE DANS LE PUITS !" or "Non present"
                local body = string.format(
                    "Position: %s\nEtat: %s\nCandy: %s\nMythic Egg: %s\nCible: %s\nPlongees: %d | Achats: %d",
                    inZoneStr,
                    diveStr,
                    Helpers.formatNumber(State.HalloweenCoins),
                    mythicStr,
                    targetStr,
                    State.Stats.DivesCompleted,
                    State.Stats.ItemsPurchased
                )
                if statusParagraph and typeof(statusParagraph.set) == "function" then
                    statusParagraph:set("Statut en Direct", body)
                end
            end)
            task.wait(0.75)
        end
    end)
    Cleanup.addThread(statusThread)
end
return Interface
