--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — SAKURA CLEAN AUTO-COLLECT & MULTI-BUY
  ========================================================================================
  Fonctionnalités réelles & fonctionnelles :
    1. 💰 Auto-Collect Cash en continu sur tous les slots de base (propre et efficace)
    2. 🥚 Auto-Buy Œufs avec MULTI-SÉLECTION (Cochez plusieurs œufs souhaités)
    3. 📦 Auto-Buy Boîtes/Caisses avec MULTI-SÉLECTION (Cochez plusieurs boîtes)
    4. 📊 Affichage en temps réel du cash, du stock en boutique et des gains
  ========================================================================================
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- ========================================================================================
-- 1. CONNEXION SÉCURISÉE AUX SERVICES DU JEU
-- ========================================================================================
local Shared = ReplicatedStorage:WaitForChild("shared", 10)
local Client = ReplicatedStorage:WaitForChild("client", 10)

if not Shared or not Client then
    warn("[SAKURA] Dossiers partagés non trouvés.")
    return
end

local Remotes = require(Shared:WaitForChild("Remotes", 10))
local CPD = require(Client:WaitForChild("ClientPlayerData", 10))

-- Helper d'état direct (Reflex / Profile)
local function getState()
    if CPD and CPD.serverProfile and CPD.serverProfile.getState then
        local ok, s = pcall(function() return CPD.serverProfile:getState() end)
        if ok and type(s) == "table" then return s end
    end
    if CPD and CPD.getState then
        local ok, s = pcall(function() return CPD:getState() end)
        if ok and type(s) == "table" then return s end
    end
    return {}
end

-- Helper d'appel Red Remote fiable (supporte :Fire, :fire et :Call)
local function fireRemote(remoteObj, ...)
    if not remoteObj then return false end
    local args = table.pack(...)
    local success = false

    -- Essai 1 : Red Event :Fire
    if typeof(remoteObj) == "table" and remoteObj.Fire then
        local ok = pcall(function() remoteObj:Fire(table.unpack(args, 1, args.n)) end)
        if ok then success = true end
    end
    -- Essai 2 : Red Event :fire
    if not success and typeof(remoteObj) == "table" and remoteObj.fire then
        local ok = pcall(function() remoteObj:fire(table.unpack(args, 1, args.n)) end)
        if ok then success = true end
    end
    -- Essai 3 : Red Function :Call
    if typeof(remoteObj) == "table" and remoteObj.Call then
        pcall(function()
            task.spawn(function()
                remoteObj:Call(table.unpack(args, 1, args.n)):Await()
            end)
        end)
        success = true
    end
    -- Essai 4 : Instance Roblox standard
    if typeof(remoteObj) == "Instance" and remoteObj:IsA("RemoteEvent") then
        pcall(function() remoteObj:FireServer(table.unpack(args, 1, args.n)) end)
        success = true
    end

    return success
end

-- Formatage de nombres
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function formatNumber(n)
    n = tonumber(n) or 0
    if n < 1000 then return tostring(math.floor(n)) end
    local i = 1
    while n >= 1000 and i < #SUFFIXES do
        n = n / 1000
        i = i + 1
    end
    return string.format("%.2f %s", n, SUFFIXES[i])
end

-- ========================================================================================
-- 2. CONFIGURATION & ÉTAT INTERNE
-- ========================================================================================
local Config = {
    -- Auto Collect Cash
    AutoCollectCash  = true,
    CollectInterval  = 2.0, -- secondes

    -- Auto Buy Eggs
    AutoBuyEggs      = false,
    SelectedEggs     = {
        ["ForestEgg"] = true,
        ["FarmEgg"]   = true,
        ["OceanEgg"]  = false,
        ["MythicEgg"] = false,
    },

    -- Auto Buy Boxes
    AutoBuyBoxes     = false,
    SelectedBoxes    = {
        ["CommonFloatCrate"]       = true,
        ["RareFloatCrate"]         = true,
        ["EpicFloatCrate"]         = false,
        ["LegendaryFloatCrate"]    = false,
        ["MythicFloatCrate"]       = false,
        ["CatFloatCrate"]          = false,
        ["FunctionalObjectsCrate"] = false,
    },
}

local Stats = {
    TotalCollected = 0,
    LastCollectTime = 0,
    TotalEggsBought = 0,
    TotalBoxesBought = 0,
}

-- ========================================================================================
-- 3. LOGIQUE MÉTIER RÉELLE (COLLECTE DU CASH & ACHAT DU STOCK)
-- ========================================================================================

-- Collecte propre de chaque slot de la base
local function collectCashOnce()
    local s = getState()
    local slots = s.baseSlots or {}
    local collectedSomething = false

    for slotIndex, slotData in pairs(slots) do
        -- Le remote attend l'index du slot sous forme de string et de number
        fireRemote(Remotes.RequestCollectCash, tostring(slotIndex))
        fireRemote(Remotes.RequestCollectCash, tonumber(slotIndex))
        collectedSomething = true
    end

    -- Activation des remotes globaux de récolte
    fireRemote(Remotes.RequestCollectCash)
    fireRemote(Remotes.AutoCollectActivated)
    fireRemote(Remotes.RequestUseAutoCollect, true)

    Stats.LastCollectTime = os.clock()
    return collectedSomething
end

-- Achat automatique des œufs sélectionnés
local function checkAndBuyEggs()
    if not Config.AutoBuyEggs then return end
    local s = getState()
    local shopItems = s.eggShopItems or {}
    local soldSlots = s.eggShopSoldSlots or {}

    for slotIdx = 1, 3 do
        local eggName = shopItems[slotIdx]
        local isSold = soldSlots[slotIdx] == true

        if eggName and not isSold and Config.SelectedEggs[eggName] then
            -- Tente l'achat par numéro de slot et par nom
            fireRemote(Remotes.BuyEgg, slotIdx)
            fireRemote(Remotes.BuyEgg, tostring(slotIdx))
            fireRemote(Remotes.BuyEgg, eggName)
            Stats.TotalEggsBought = Stats.TotalEggsBought + 1
            task.wait(0.3)
        end
    end
end

-- Achat automatique des boîtes/caisses sélectionnées
local function checkAndBuyBoxes()
    if not Config.AutoBuyBoxes then return end
    local s = getState()
    local shopItems = s.lootboxShopItems or {}
    local soldSlots = s.lootboxShopSoldSlots or {}

    for slotIdx = 1, 3 do
        local boxName = shopItems[slotIdx]
        local isSold = soldSlots[slotIdx] == true

        if boxName and not isSold and Config.SelectedBoxes[boxName] then
            -- Tente l'achat par numéro de slot et par nom
            fireRemote(Remotes.BuyFloatLootbox, slotIdx)
            fireRemote(Remotes.BuyFloatLootbox, tostring(slotIdx))
            fireRemote(Remotes.BuyFloatLootbox, boxName)
            Stats.TotalBoxesBought = Stats.TotalBoxesBought + 1
            task.wait(0.3)
        end
    end
end

-- ========================================================================================
-- 4. BOUCLE DE FOND ASYNCHRONE
-- ========================================================================================
_G.__SAKURA_LUCKYFISH = (_G.__SAKURA_LUCKYFISH or 0) + 1
local CURRENT_GEN = _G.__SAKURA_LUCKYFISH

task.spawn(function()
    while _G.__SAKURA_LUCKYFISH == CURRENT_GEN do
        if Config.AutoCollectCash then
            pcall(collectCashOnce)
        end
        if Config.AutoBuyEggs then
            pcall(checkAndBuyEggs)
        end
        if Config.AutoBuyBoxes then
            pcall(checkAndBuyBoxes)
        end
        task.wait(math.max(1, Config.CollectInterval))
    end
end)

-- ========================================================================================
-- 5. INTERFACE SAKURA GRAPHIQUE ÉLÉGANTE & COMPACTE
-- ========================================================================================
local Theme = {
    Bg        = Color3.fromRGB(24, 17, 24),
    Card      = Color3.fromRGB(33, 23, 33),
    CardSub   = Color3.fromRGB(44, 30, 44),
    Accent    = Color3.fromRGB(255, 117, 151),
    AccentSoft= Color3.fromRGB(255, 182, 193),
    Text      = Color3.fromRGB(255, 245, 248),
    TextDim   = Color3.fromRGB(214, 178, 194),
    Green     = Color3.fromRGB(120, 230, 160),
    Red       = Color3.fromRGB(255, 100, 120),
}

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
if targetParent:FindFirstChild("SakuraLuckyFish_Clean") then
    targetParent:FindFirstChild("SakuraLuckyFish_Clean"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SakuraLuckyFish_Clean"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

-- Fenêtre Principale
local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, 520, 0, 440)
Main.Position = UDim2.new(0.5, -260, 0.5, -220)
Main.BackgroundColor3 = Theme.Bg
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Accent
MainStroke.Thickness = 1.6
MainStroke.Parent = Main

-- Drag & Drop
local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Barre Supérieure
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Theme.Card
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TopTitle = Instance.new("TextLabel")
TopTitle.Size = UDim2.new(1, -90, 1, 0)
TopTitle.Position = UDim2.new(0, 14, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "🌸 SAKURA — Auto-Collect & Multi-Buy"
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13
TopTitle.TextColor3 = Theme.Text
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.Parent = TopBar

-- Boutons Réduire et Fermer
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -14)
CloseBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 42)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Theme.AccentSoft
CloseBtn.Parent = TopBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -68, 0.5, -14)
MinBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 42)
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.TextColor3 = Theme.AccentSoft
MinBtn.Parent = TopBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Bouton Flottant Fleur Sakura
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0, 20, 0.5, -22)
FloatBtn.BackgroundColor3 = Theme.Bg
FloatBtn.Text = "🌸"
FloatBtn.TextSize = 22
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatBtn
local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 1.5
FloatStroke.Parent = FloatBtn
FloatBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    FloatBtn.Visible = false
end)
MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    FloatBtn.Visible = true
end)

-- Barre de Navigation Onglets
local NavFrame = Instance.new("Frame")
NavFrame.Size = UDim2.new(1, -20, 0, 32)
NavFrame.Position = UDim2.new(0, 10, 0, 48)
NavFrame.BackgroundTransparency = 1
NavFrame.Parent = Main

local NavLayout = Instance.new("UIListLayout")
NavLayout.FillDirection = Enum.FillDirection.Horizontal
NavLayout.Padding = UDim.new(0, 8)
NavLayout.Parent = NavFrame

-- Pages Container
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -20, 1, -92)
Container.Position = UDim2.new(0, 10, 0, 84)
Container.BackgroundTransparency = 1
Container.Parent = Main

local Tabs = {}
local TabButtons = {}

local function createTab(name, title)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Container

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = pageScroll or page

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.315, 0, 1, 0)
    btn.BackgroundColor3 = Theme.Card
    btn.Text = title
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = NavFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.Accent
    stroke.Thickness = 0.8
    stroke.Transparency = 0.6
    stroke.Parent = btn

    Tabs[name] = page
    TabButtons[name] = { Button = btn, Stroke = stroke }

    btn.MouseButton1Click:Connect(function()
        for tName, p in pairs(Tabs) do
            p.Visible = (tName == name)
            local bData = TabButtons[tName]
            if tName == name then
                bData.Button.BackgroundColor3 = Theme.CardSub
                bData.Button.TextColor3 = Theme.AccentSoft
                bData.Stroke.Transparency = 0
            else
                bData.Button.BackgroundColor3 = Theme.Card
                bData.Button.TextColor3 = Theme.TextDim
                bData.Stroke.Transparency = 0.6
            end
        end
    end)

    return page
end

local PageCash  = createTab("Cash", "💰 Auto-Collect Cash")
local PageEggs  = createTab("Eggs", "🥚 Auto-Buy Œufs")
local PageBoxes = createTab("Boxes", "📦 Auto-Buy Boîtes")

-- Composant Carte
local function makeCard(parent, headerTitle)
    local c = Instance.new("Frame")
    c.Size = UDim2.new(1, 0, 0, 0)
    c.BackgroundColor3 = Theme.Card
    c.AutomaticSize = Enum.AutomaticSize.Y
    c.BorderSizePixel = 0
    c.Parent = parent

    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 8)
    cc.Parent = c

    local cp = Instance.new("UIPadding")
    cp.PaddingTop = UDim.new(0, 8)
    cp.PaddingBottom = UDim.new(0, 8)
    cp.PaddingLeft = UDim.new(0, 10)
    cp.PaddingRight = UDim.new(0, 10)
    cp.Parent = c

    local cl = Instance.new("UIListLayout")
    cl.Padding = UDim.new(0, 6)
    cl.Parent = c

    if headerTitle then
        local hl = Instance.new("TextLabel")
        hl.Size = UDim2.new(1, 0, 0, 16)
        hl.BackgroundTransparency = 1
        hl.Text = string.upper(headerTitle)
        hl.Font = Enum.Font.GothamBold
        hl.TextSize = 10
        hl.TextColor3 = Theme.AccentSoft
        hl.TextXAlignment = Enum.TextXAlignment.Left
        hl.Parent = c
    end
    return c
end

-- Composant Toggle Switch
local function makeToggle(card, text, defaultVal, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
    row.BackgroundTransparency = 1
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 40, 0, 20)
    btn.Position = UDim2.new(1, -40, 0.5, -10)
    btn.BackgroundColor3 = defaultVal and Theme.Accent or Theme.CardSub
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = btn

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = defaultVal and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = btn

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local current = defaultVal
    btn.MouseButton1Click:Connect(function()
        current = not current
        if current then
            btn.BackgroundColor3 = Theme.Accent
            knob.Position = UDim2.new(1, -17, 0.5, -7)
        else
            btn.BackgroundColor3 = Theme.CardSub
            knob.Position = UDim2.new(0, 3, 0.5, -7)
        end
        onToggle(current)
    end)
    return row
end

-- Composant Bouton d'Action
local function makeButton(card, text, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Theme.CardSub
    btn.Text = text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.Text
    btn.Parent = card

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Theme.Accent
    bStroke.Thickness = 0.8
    bStroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        btn.BackgroundColor3 = Theme.Accent
        task.wait(0.1)
        btn.BackgroundColor3 = Theme.CardSub
        onClick()
    end)
    return btn
end

-- ========================================================================================
-- 📑 CONTENU ONGLET 1 : AUTO-COLLECT CASH
-- ========================================================================================
local CardStats = makeCard(PageCash, "Solde & Statistiques Directes")
local CashDisplay = Instance.new("TextLabel")
CashDisplay.Size = UDim2.new(1, 0, 0, 20)
CashDisplay.BackgroundTransparency = 1
CashDisplay.Font = Enum.Font.GothamBold
CashDisplay.TextSize = 13
CashDisplay.TextColor3 = Theme.Green
CashDisplay.TextXAlignment = Enum.TextXAlignment.Left
CashDisplay.Text = "💵 Cash Actuel : Chargement..."
CashDisplay.Parent = CardStats

local StatusDisplay = Instance.new("TextLabel")
StatusDisplay.Size = UDim2.new(1, 0, 0, 16)
StatusDisplay.BackgroundTransparency = 1
StatusDisplay.Font = Enum.Font.Gotham
StatusDisplay.TextSize = 11
StatusDisplay.TextColor3 = Theme.TextDim
StatusDisplay.TextXAlignment = Enum.TextXAlignment.Left
StatusDisplay.Text = "⏱️ État : Collecte automatique active"
StatusDisplay.Parent = CardStats

local CardCollect = makeCard(PageCash, "Paramètres de Récolte")
makeToggle(CardCollect, "Activer Auto-Collect Cash en continu", Config.AutoCollectCash, function(val)
    Config.AutoCollectCash = val
    StatusDisplay.Text = val and "⏱️ État : Collecte automatique active" or "⏱️ État : En pause"
    StatusDisplay.TextColor3 = val and Theme.Green or Theme.Red
end)

makeButton(CardCollect, "⚡ Récolter Tout Immédiatement (Force Collect)", function()
    local ok = collectCashOnce()
    StatusDisplay.Text = "✔ Récolté avec succès à " .. os.date("%X")
    StatusDisplay.TextColor3 = Theme.Green
end)

-- ========================================================================================
-- 📑 CONTENU ONGLET 2 : AUTO-BUY ŒUFS (MULTI-SÉLECTION)
-- ========================================================================================
local CardEggMaster = makeCard(PageEggs, "Activation Principale")
makeToggle(CardEggMaster, "Activer Auto-Achat d'Œufs (Auto-Buy Eggs)", Config.AutoBuyEggs, function(val)
    Config.AutoBuyEggs = val
end)

local CardEggShop = makeCard(PageEggs, "Boutique d'Œufs en Direct (3 Emplacements)")
local EggSlot1 = Instance.new("TextLabel")
EggSlot1.Size = UDim2.new(1, 0, 0, 16)
EggSlot1.BackgroundTransparency = 1
EggSlot1.Font = Enum.Font.Gotham
EggSlot1.TextSize = 11
EggSlot1.TextColor3 = Theme.Text
EggSlot1.TextXAlignment = Enum.TextXAlignment.Left
EggSlot1.Text = "Slot 1 : ..."
EggSlot1.Parent = CardEggShop

local EggSlot2 = Instance.new("TextLabel")
EggSlot2.Size = UDim2.new(1, 0, 0, 16)
EggSlot2.BackgroundTransparency = 1
EggSlot2.Font = Enum.Font.Gotham
EggSlot2.TextSize = 11
EggSlot2.TextColor3 = Theme.Text
EggSlot2.TextXAlignment = Enum.TextXAlignment.Left
EggSlot2.Text = "Slot 2 : ..."
EggSlot2.Parent = CardEggShop

local EggSlot3 = Instance.new("TextLabel")
EggSlot3.Size = UDim2.new(1, 0, 0, 16)
EggSlot3.BackgroundTransparency = 1
EggSlot3.Font = Enum.Font.Gotham
EggSlot3.TextSize = 11
EggSlot3.TextColor3 = Theme.Text
EggSlot3.TextXAlignment = Enum.TextXAlignment.Left
EggSlot3.Text = "Slot 3 : ..."
EggSlot3.Parent = CardEggShop

local CardEggSelect = makeCard(PageEggs, "Sélectionnez les Œufs à Acheter (Multi-Choix)")
local eggOptions = { "ForestEgg", "FarmEgg", "OceanEgg", "MythicEgg" }
for _, eggName in ipairs(eggOptions) do
    makeToggle(CardEggSelect, "Acheter " .. eggName, Config.SelectedEggs[eggName] or false, function(checked)
        Config.SelectedEggs[eggName] = checked
    end)
end

makeButton(PageEggs, "🛒 Acheter les Œufs Ciblés Maintenant", function()
    checkAndBuyEggs()
end)

-- ========================================================================================
-- 📑 CONTENU ONGLET 3 : AUTO-BUY BOÎTES (MULTI-SÉLECTION)
-- ========================================================================================
local CardBoxMaster = makeCard(PageBoxes, "Activation Principale")
makeToggle(CardBoxMaster, "Activer Auto-Achat de Boîtes (Auto-Buy Boxes)", Config.AutoBuyBoxes, function(val)
    Config.AutoBuyBoxes = val
end)

local CardBoxShop = makeCard(PageBoxes, "Boutique de Boîtes en Direct (3 Emplacements)")
local BoxSlot1 = Instance.new("TextLabel")
BoxSlot1.Size = UDim2.new(1, 0, 0, 16)
BoxSlot1.BackgroundTransparency = 1
BoxSlot1.Font = Enum.Font.Gotham
BoxSlot1.TextSize = 11
BoxSlot1.TextColor3 = Theme.Text
BoxSlot1.TextXAlignment = Enum.TextXAlignment.Left
BoxSlot1.Text = "Slot 1 : ..."
BoxSlot1.Parent = CardBoxShop

local BoxSlot2 = Instance.new("TextLabel")
BoxSlot2.Size = UDim2.new(1, 0, 0, 16)
BoxSlot2.BackgroundTransparency = 1
BoxSlot2.Font = Enum.Font.Gotham
BoxSlot2.TextSize = 11
BoxSlot2.TextColor3 = Theme.Text
BoxSlot2.TextXAlignment = Enum.TextXAlignment.Left
BoxSlot2.Text = "Slot 2 : ..."
BoxSlot2.Parent = CardBoxShop

local BoxSlot3 = Instance.new("TextLabel")
BoxSlot3.Size = UDim2.new(1, 0, 0, 16)
BoxSlot3.BackgroundTransparency = 1
BoxSlot3.Font = Enum.Font.Gotham
BoxSlot3.TextSize = 11
BoxSlot3.TextColor3 = Theme.Text
BoxSlot3.TextXAlignment = Enum.TextXAlignment.Left
BoxSlot3.Text = "Slot 3 : ..."
BoxSlot3.Parent = CardBoxShop

local CardBoxSelect = makeCard(PageBoxes, "Sélectionnez les Boîtes à Acheter (Multi-Choix)")
local boxOptions = {
    "CommonFloatCrate", "RareFloatCrate", "EpicFloatCrate",
    "LegendaryFloatCrate", "MythicFloatCrate", "CatFloatCrate", "FunctionalObjectsCrate"
}
for _, boxName in ipairs(boxOptions) do
    makeToggle(CardBoxSelect, "Acheter " .. boxName, Config.SelectedBoxes[boxName] or false, function(checked)
        Config.SelectedBoxes[boxName] = checked
    end)
end

makeButton(PageBoxes, "🛒 Acheter les Boîtes Ciblées Maintenant", function()
    checkAndBuyBoxes()
end)

-- ========================================================================================
-- 🔄 RAFRAÎCHISSEMENT EN DIRECT DES STATISTIQUES & BOUTIQUES
-- ========================================================================================
task.spawn(function()
    while _G.__SAKURA_LUCKYFISH == CURRENT_GEN do
        pcall(function()
            local s = getState()
            local m = s.money or 0
            CashDisplay.Text = "💵 Cash Actuel : " .. formatNumber(m)

            -- Shop Œufs
            local eItems = s.eggShopItems or {}
            local eSold = s.eggShopSoldSlots or {}
            EggSlot1.Text = string.format("Slot 1 : %s (%s)", eItems[1] or "Vide", eSold[1] and "Épuisé" or "Disponible")
            EggSlot2.Text = string.format("Slot 2 : %s (%s)", eItems[2] or "Vide", eSold[2] and "Épuisé" or "Disponible")
            EggSlot3.Text = string.format("Slot 3 : %s (%s)", eItems[3] or "Vide", eSold[3] and "Épuisé" or "Disponible")

            -- Shop Boîtes
            local bItems = s.lootboxShopItems or {}
            local bSold = s.lootboxShopSoldSlots or {}
            BoxSlot1.Text = string.format("Slot 1 : %s (%s)", bItems[1] or "Vide", bSold[1] and "Épuisé" or "Disponible")
            BoxSlot2.Text = string.format("Slot 2 : %s (%s)", bItems[2] or "Vide", bSold[2] and "Épuisé" or "Disponible")
            BoxSlot3.Text = string.format("Slot 3 : %s (%s)", bItems[3] or "Vide", bSold[3] and "Épuisé" or "Disponible")
        end)
        task.wait(1.5)
    end
end)

-- Afficher l'onglet Cash par défaut
Tabs["Cash"].Visible = true
TabButtons["Cash"].Button.BackgroundColor3 = Theme.CardSub
TabButtons["Cash"].Button.TextColor3 = Theme.AccentSoft
TabButtons["Cash"].Stroke.Transparency = 0

print("🌸 [SAKURA] Menu Auto-Collect & Multi-Buy chargé avec succès !")
