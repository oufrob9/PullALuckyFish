--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — SAFE DEBUG & TESTING PROBE
  ========================================================================================
  Fichier      : debug_probe.luau
  Auteur       : oufrob9 (PullALuckyFish)
  Description  : Outil d'inspection et de diagnostic sécurisé pour compte principal.
                 Permet de tester UN PAR UN les remotes et mécaniques sans risque de ban,
                 sans vider vos fonds et avec un mode DRY-RUN (simulation) pour l'Auto-Sell.
  Usage        : loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/debug_probe.luau"))()
  ========================================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- ========================================================================================
-- 1. RÉCUPÉRATION SÉCURISÉE DES SERVICES & MODULES DU JEU
-- ========================================================================================
local Shared = ReplicatedStorage:WaitForChild("shared", 10)
local Client = ReplicatedStorage:WaitForChild("client", 10)

if not Shared or not Client then
    warn("[DEBUG PROBE] Erreur : Dossiers Shared/Client introuvables dans ReplicatedStorage.")
    return
end

local RemotesModule = Shared:WaitForChild("Remotes", 10)
local Remotes = RemotesModule and require(RemotesModule) or nil

local ClientPlayerDataModule = Client:WaitForChild("ClientPlayerData", 10)
local ClientPlayerData = ClientPlayerDataModule and require(ClientPlayerDataModule) or nil

if not Remotes then
    warn("[DEBUG PROBE] Erreur : Impossible de charger le module Remotes.")
    return
end

-- Helper d'appel universel pour le réseau Red
local function callRemote(name, ...)
    local remote = Remotes[name]
    if not remote then
        warn("[DEBUG PROBE] Remote introuvable : " .. tostring(name))
        return false, "Remote not found"
    end

    local success, result
    if typeof(remote) == "table" then
        if remote.fire then
            success, result = pcall(function(...) return remote:fire(...) end, ...)
        elseif remote.Fire then
            success, result = pcall(function(...) return remote:Fire(...) end, ...)
        elseif remote.call then
            success, result = pcall(function(...) return remote:call(...) end, ...)
        elseif remote.Call then
            success, result = pcall(function(...) return remote:Call(...) end, ...)
        elseif remote.FireServer then
            success, result = pcall(function(...) return remote:FireServer(...) end, ...)
        else
            warn("[DEBUG PROBE] Type de table remote inconnu pour " .. tostring(name))
            return false, "Unknown remote table layout"
        end
    elseif typeof(remote) == "Instance" then
        if remote:IsA("RemoteEvent") then
            success, result = pcall(function(...) return remote:FireServer(...) end, ...)
        elseif remote:IsA("RemoteFunction") then
            success, result = pcall(function(...) return remote:InvokeServer(...) end, ...)
        end
    end

    return success, result
end

-- ========================================================================================
-- 2. ÉTAT DU JOUEUR (LECTURE SEULE / SANS RISQUE)
-- ========================================================================================
local function getPlayerState()
    if ClientPlayerData and ClientPlayerData.getState then
        local success, state = pcall(function() return ClientPlayerData:getState() end)
        if success and type(state) == "table" then
            return state
        end
    end
    return {}
end

-- ========================================================================================
-- 3. INTERFACE UTILISATEUR DU DEBUG PROBE (Console & Boutons de test)
-- ========================================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LuckyFish_SafeProbe"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
if ScreenGui.Parent ~= targetParent then
    pcall(function()
        if targetParent:FindFirstChild("LuckyFish_SafeProbe") then
            targetParent:FindFirstChild("LuckyFish_SafeProbe"):Destroy()
        end
        ScreenGui.Parent = targetParent
    end)
end

-- Fenêtre Principale
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 520)
MainFrame.Position = UDim2.new(0.5, -280, 0.5, -260)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 26)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 117, 151)
MainStroke.Thickness = 1.6
MainStroke.Parent = MainFrame

-- Titre
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Color3.fromRGB(34, 26, 36)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -50, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🌸 Pull A Lucky Fish — Safe Diagnostic Probe"
TitleLabel.TextColor3 = Color3.fromRGB(255, 230, 238)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 40)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 140, 160)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Status Bar
local StatusBar = Instance.new("TextLabel")
StatusBar.Size = UDim2.new(1, -20, 0, 24)
StatusBar.Position = UDim2.new(0, 10, 0, 48)
StatusBar.BackgroundColor3 = Color3.fromRGB(38, 28, 40)
StatusBar.TextColor3 = Color3.fromRGB(255, 192, 203)
StatusBar.Font = Enum.Font.Gotham
StatusBar.TextSize = 11
StatusBar.Text = "Compte : " .. LocalPlayer.Name .. " | Mode : Sécurité Maximale (Pas de vente auto non désirée)"
StatusBar.Parent = MainFrame

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 6)
StatusCorner.Parent = StatusBar

-- Zone Console Logs
local LogBox = Instance.new("ScrollingFrame")
LogBox.Size = UDim2.new(1, -20, 0, 170)
LogBox.Position = UDim2.new(0, 10, 0, 78)
LogBox.BackgroundColor3 = Color3.fromRGB(15, 12, 16)
LogBox.BorderSizePixel = 0
LogBox.ScrollBarThickness = 5
LogBox.ScrollBarImageColor3 = Color3.fromRGB(255, 117, 151)
LogBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogBox.Parent = MainFrame

local LogCorner = Instance.new("UICorner")
LogCorner.CornerRadius = UDim.new(0, 6)
LogCorner.Parent = LogBox

local LogList = Instance.new("UIListLayout")
LogList.Padding = UDim.new(0, 2)
LogList.Parent = LogBox

local function addLog(msg, color)
    color = color or Color3.fromRGB(230, 230, 230)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 16)
    lbl.Position = UDim2.new(0, 5, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.Code
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = "[" .. os.date("%X") .. "] " .. tostring(msg)
    lbl.Parent = LogBox
    LogBox.CanvasPosition = Vector2.new(0, 999999)
end

addLog("🌸 Initialisation du Safe Probe terminée.", Color3.fromRGB(255, 180, 200))
addLog("💡 Cliquez sur les boutons ci-dessous pour tester chaque mécanique individuellement.", Color3.fromRGB(200, 200, 200))

-- Bouton Clear Logs
local ClearBtn = Instance.new("TextButton")
ClearBtn.Size = UDim2.new(0, 80, 0, 18)
ClearBtn.Position = UDim2.new(1, -95, 0, 82)
ClearBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 42)
ClearBtn.TextColor3 = Color3.fromRGB(255, 180, 200)
ClearBtn.Text = "Effacer logs"
ClearBtn.Font = Enum.Font.Gotham
ClearBtn.TextSize = 10
ClearBtn.ZIndex = 5
ClearBtn.Parent = MainFrame
local ClearCorner = Instance.new("UICorner")
ClearCorner.CornerRadius = UDim.new(0, 4)
ClearCorner.Parent = ClearBtn
ClearBtn.MouseButton1Click:Connect(function()
    for _, ch in ipairs(LogBox:GetChildren()) do
        if ch:IsA("TextLabel") then ch:Destroy() end
    end
end)

-- Grille des Boutons de Test
local ActionsScroll = Instance.new("ScrollingFrame")
ActionsScroll.Size = UDim2.new(1, -20, 0, 250)
ActionsScroll.Position = UDim2.new(0, 10, 0, 256)
ActionsScroll.BackgroundTransparency = 1
ActionsScroll.ScrollBarThickness = 5
ActionsScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 117, 151)
ActionsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ActionsScroll.Parent = MainFrame

local ActionsGrid = Instance.new("UIGridLayout")
ActionsGrid.CellSize = UDim2.new(0.485, 0, 0, 36)
ActionsGrid.CellPadding = UDim2.new(0.03, 0, 0, 6)
ActionsGrid.Parent = ActionsScroll

local function createActionButton(text, color, callback)
    local btn = Instance.new("TextButton")
    btn.BackgroundColor3 = color or Color3.fromRGB(42, 32, 46)
    btn.TextColor3 = Color3.fromRGB(255, 240, 246)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.Text = text
    btn.AutoButtonColor = true
    btn.Parent = ActionsScroll

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 117, 151)
    stroke.Thickness = 0.8
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local success, err = pcall(callback)
        if not success then
            addLog("❌ ERREUR : " .. tostring(err), Color3.fromRGB(255, 80, 80))
        end
    end)
    return btn
end

-- ========================================================================================
-- 4. TESTS SÉCURISÉS INDIVIDUELS (AVEC VÉRIFICATIONS COMPTE PRINCIPAL)
-- ========================================================================================

-- Test 1 : Inspecter le Profil & Données Joueur
createActionButton("📊 1. Profil & Stats Live", Color3.fromRGB(40, 32, 48), function()
    local s = getPlayerState()
    local cash = s.money or 0
    local strength = s.strength or 0
    local rebirth = s.rebirthLevel or 0
    local gems = s.gems or 0
    local world = s.currentWorldId or 1
    addLog(string.format("💰 Cash: %.2e | 💪 Force: %.2e | 🔄 Rebirth: %d | 💎 Gems: %d | 🌍 World: %d", cash, strength, rebirth, gems, world), Color3.fromRGB(120, 255, 180))
end)

-- Test 2 : Auto Collect Cash (1 pulsation test)
createActionButton("💵 2. Test Collect Cash (1x)", Color3.fromRGB(40, 48, 40), function()
    addLog("Envoi de RequestCollectCash...", Color3.fromRGB(255, 230, 150))
    local before = (getPlayerState().money or 0)
    local ok, res = callRemote("RequestCollectCash")
    task.wait(0.3)
    local after = (getPlayerState().money or 0)
    local diff = after - before
    if ok then
        addLog("✔ RequestCollectCash validé ! Gain: +" .. tostring(diff), Color3.fromRGB(150, 255, 150))
    else
        addLog("❌ Échec RequestCollectCash : " .. tostring(res), Color3.fromRGB(255, 100, 100))
    end
end)

-- Test 3 : Auto Train (3 clics d'essai)
createActionButton("💪 3. Test Auto-Train (3 taps)", Color3.fromRGB(50, 36, 40), function()
    local before = (getPlayerState().strength or 0)
    addLog("Début du micro-test Train (3 appels)...", Color3.fromRGB(255, 230, 150))
    for i = 1, 3 do
        callRemote("Train")
        task.wait(0.1)
    end
    task.wait(0.3)
    local after = (getPlayerState().strength or 0)
    local gained = after - before
    addLog("✔ Train test terminé ! Force gagnée : +" .. tostring(gained), Color3.fromRGB(150, 255, 150))
end)

-- Test 4 : DRY-RUN Auto-Sell (SIMULATION SANS VENTE)
createActionButton("🔍 4. Auto-Sell DRY-RUN (0 risque)", Color3.fromRGB(54, 40, 26), function()
    addLog("--- SIMULATION AUTO-SELL (DRY-RUN SÉCURISÉ) ---", Color3.fromRGB(255, 215, 0))
    local s = getPlayerState()
    local inventory = s.inventory or {}
    local totalFish = 0
    local sellableCount = 0
    local protectedCount = 0

    -- Simulation : On vendrait Common/Uncommon/Rare, on protège Epic/Legendary/Mythic et toute mutation
    for key, item in pairs(inventory) do
        if typeof(item) == "table" and item.Category == "Fish" or (item.ConfigName and not item.Category) then
            totalFish = totalFish + 1
            local rarity = item.Rarity or "Unknown"
            local hasMutation = item.Mutations and #item.Mutations > 0

            if hasMutation or rarity == "Mythic" or rarity == "Legendary" or rarity == "Secret" or rarity == "OG" then
                protectedCount = protectedCount + 1
            else
                sellableCount = sellableCount + 1
            end
        end
    end

    addLog(string.format("🔎 Total poissons analysés : %d", totalFish), Color3.fromRGB(255, 240, 200))
    addLog(string.format("🛡️ Poissons qui SERAIENT PROTÉGÉS : %d (Mutations / Rares)", protectedCount), Color3.fromRGB(120, 255, 150))
    addLog(string.format("📦 Poissons qui SERAIENT VENDUS : %d", sellableCount), Color3.fromRGB(255, 180, 120))
    addLog("✔ Aucun poisson n'a été vendu. Test 100% sûr.", Color3.fromRGB(100, 220, 255))
end)

-- Test 5 : Vente Test 1 Poisson Unique (Common uniquement)
createActionButton("⚠️ 5. Vente Test 1 Poisson (Test)", Color3.fromRGB(60, 28, 32), function()
    addLog("⚠️ Vérification de l'inventaire pour 1 poisson Common de test...", Color3.fromRGB(255, 160, 160))
    local s = getPlayerState()
    local inventory = s.inventory or {}
    local testFishKey = nil

    for key, item in pairs(inventory) do
        if typeof(item) == "table" and (item.Rarity == "Common" or item.ConfigName == "Gold Fish") and not item.Mutations then
            testFishKey = key
            break
        end
    end

    if not testFishKey then
        addLog("ℹ️ Aucun poisson Common jetable trouvé dans l'inventaire. Annulation de sécurité.", Color3.fromRGB(255, 200, 150))
        return
    end

    addLog("Tentative de vente sécurisée pour : " .. tostring(testFishKey), Color3.fromRGB(255, 220, 150))
    local ok, res = callRemote("SellFish", testFishKey)
    if ok then
        addLog("✔ Remote SellFish opérationnel avec succès !", Color3.fromRGB(150, 255, 150))
    else
        addLog("❌ Échec SellFish : " .. tostring(res), Color3.fromRGB(255, 100, 100))
    end
end)

-- Test 6 : Inspecter les Œufs Posés (placedEggs)
createActionButton("🥚 6. Inspecter Œufs & Timers", Color3.fromRGB(44, 34, 52), function()
    local s = getPlayerState()
    local eggs = s.placedEggs or {}
    local count = 0
    addLog("--- INSPECTION DES ŒUFS POSÉS ---", Color3.fromRGB(255, 200, 240))
    for id, eggData in pairs(eggs) do
        count = count + 1
        local eggName = eggData.ConfigName or "Egg"
        local remaining = eggData.RemainingSeconds or 0
        addLog(string.format("🥚 #%d: %s | Temps restant: %ds", count, eggName, remaining), Color3.fromRGB(255, 220, 255))
    end
    if count == 0 then
        addLog("ℹ️ Aucun œuf en cours d'incubation sur la base.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Test 7 : Tester Skip Timer / Hatch Œuf prêt
createActionButton("🐣 7. Test Hatch Œuf (Si Prêt)", Color3.fromRGB(48, 36, 48), function()
    local s = getPlayerState()
    local eggs = s.placedEggs or {}
    local hatched = false
    for id, eggData in pairs(eggs) do
        if (eggData.RemainingSeconds or 0) <= 0 then
            addLog("Tentative d'éclosion pour œuf " .. tostring(id), Color3.fromRGB(255, 230, 150))
            callRemote("HatchEgg", id)
            hatched = true
            break
        end
    end
    if not hatched then
        addLog("ℹ️ Aucun œuf prêt à éclore pour le moment.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Test 8 : Inspecter les Boîtes Posées (placedLootboxes)
createActionButton("📦 8. Inspecter Boîtes Posées", Color3.fromRGB(44, 38, 34), function()
    local s = getPlayerState()
    local boxes = s.placedLootboxes or {}
    local count = 0
    addLog("--- INSPECTION DES BOÎTES POSÉES ---", Color3.fromRGB(255, 215, 180))
    for id, boxData in pairs(boxes) do
        count = count + 1
        local boxName = boxData.ConfigName or "Lootbox"
        addLog(string.format("📦 #%d: %s (ID: %s)", count, boxName, tostring(id):sub(1, 8)), Color3.fromRGB(255, 230, 200))
    end
    if count == 0 then
        addLog("ℹ️ Aucune boîte posée sur la base.", Color3.fromRGB(200, 200, 200))
    end
end)

-- Test 9 : Upgrade Fish sur la Base (Slot 1)
createActionButton("🐟 9. Test Upgrade 1 Slot Fish", Color3.fromRGB(36, 44, 46), function()
    local s = getPlayerState()
    local slots = s.baseSlots or {}
    local slot1 = slots[1] or slots["1"]
    if not slot1 then
        addLog("ℹ️ Slot 1 vide ou non trouvé.", Color3.fromRGB(200, 200, 200))
        return
    end
    addLog("Tentative d'upgrade sur Slot 1...", Color3.fromRGB(255, 230, 150))
    local ok, res = callRemote("RequestUpgradeFish", 1)
    if ok then
        addLog("✔ RequestUpgradeFish envoyé avec succès.", Color3.fromRGB(150, 255, 150))
    else
        addLog("❌ Échec UpgradeFish : " .. tostring(res), Color3.fromRGB(255, 100, 100))
    end
end)

-- Test 10 : Inspecter DNA Lab & Poissons broyables
createActionButton("🧬 10. Inspection DNA Lab", Color3.fromRGB(46, 32, 54), function()
    local s = getPlayerState()
    local inventory = s.inventory or {}
    local dnaVials = 0
    local fishCandidates = 0
    for key, item in pairs(inventory) do
        if typeof(item) == "table" then
            if tostring(key):find("DNA") then
                dnaVials = dnaVials + (item.Stack or 1)
            elseif item.Category == "Fish" or item.Rarity == "Common" or item.Rarity == "Uncommon" then
                fishCandidates = fishCandidates + (item.Stack or 1)
            end
        end
    end
    addLog(string.format("🧬 Fioles d'ADN actuelles : %d", dnaVials), Color3.fromRGB(200, 160, 255))
    addLog(string.format("🐟 Poissons Common/Uncommon éligibles broyeur : %d", fishCandidates), Color3.fromRGB(180, 220, 255))
    addLog("✔ Broyage manuel sécurisé : Remote GrindFishForDna prêt.", Color3.fromRGB(150, 255, 150))
end)

-- Test 11 : Téléportation Sécurisée (ThrowZone Pêche)
createActionButton("📍 11. TP Test (ThrowZone)", Color3.fromRGB(36, 40, 56), function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local throwZone = workspace:FindFirstChild("ThrowZone")
    if root and throwZone then
        local targetCFrame = throwZone.CFrame + Vector3.new(0, 5, 0)
        root.CFrame = targetCFrame
        addLog("✔ Téléporté à la ThrowZone (Pêche principale).", Color3.fromRGB(150, 255, 150))
    else
        addLog("❌ ThrowZone introuvable dans Workspace.", Color3.fromRGB(255, 100, 100))
    end
end)

-- Test 12 : Téléportation Sécurisée (Shop Central)
createActionButton("🏪 12. TP Test (Shop Central)", Color3.fromRGB(36, 50, 52), function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local shop = workspace:FindFirstChild("Shop")
    if root and shop then
        local targetPos = (shop:IsA("Model") and shop:GetPivot().Position) or shop.Position
        root.CFrame = CFrame.new(targetPos + Vector3.new(0, 4, 0))
        addLog("✔ Téléporté au Shop central.", Color3.fromRGB(150, 255, 150))
    else
        addLog("❌ Shop introuvable dans Workspace.", Color3.fromRGB(255, 100, 100))
    end
end)

-- Test 13 : Anti-AFK Sécurisé (SANS Auto-Rejoin)
local antiAfkActive = false
local antiAfkConnection = nil
createActionButton("🛡️ 13. Toggle Anti-AFK (Pas de Rejoin)", Color3.fromRGB(32, 54, 42), function()
    antiAfkActive = not antiAfkActive
    if antiAfkActive then
        antiAfkConnection = LocalPlayer.Idled:Connect(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            addLog("🛡️ Anti-AFK a empêché le kick d'inactivité (VirtualUser).", Color3.fromRGB(150, 255, 200))
        end)
        addLog("✔ Anti-AFK activé (Doux, sans auto-rejoin).", Color3.fromRGB(120, 255, 150))
    else
        if antiAfkConnection then
            antiAfkConnection:Disconnect()
            antiAfkConnection = nil
        end
        addLog("⏹️ Anti-AFK désactivé.", Color3.fromRGB(255, 150, 150))
    end
end)

-- Test 14 : Vérification des Remotes Disponibles
createActionButton("🔎 14. Scan Remotes Disponibles", Color3.fromRGB(40, 36, 50), function()
    local keyRemotes = {
        "Train", "RequestCollectCash", "SellFish", "SellFishBatch",
        "RequestUpgradeFish", "HatchEgg", "SkipEggTimer", "BuyEgg",
        "OpenLuckyblock", "OpenFloatLootbox", "GrindFishForDna"
    }
    addLog("--- VÉRIFICATION DES REMOTES CLÉS ---", Color3.fromRGB(255, 220, 150))
    for _, name in ipairs(keyRemotes) do
        local exists = Remotes[name] ~= nil
        if exists then
            addLog("✔ Remote trouvé : " .. name, Color3.fromRGB(140, 255, 140))
        else
            addLog("❌ Remote MANQUANT : " .. name, Color3.fromRGB(255, 100, 100))
        end
    end
end)

addLog("💡 Prêt ! Vous pouvez fermer cette fenêtre à tout moment via la croix ✕.", Color3.fromRGB(255, 190, 210))
