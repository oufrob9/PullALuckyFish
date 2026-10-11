--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — SAKURA UI (PREMIUM EDITION)
  ========================================================================================
  Fichier      : ui_sakura.luau
  Auteur       : oufrob9 (PullALuckyFish)
  Style        : Sakura / Cherry Blossom (Pastels doux, Icônes réelles, Animations fluides)
  Description  : Interface visuelle haute fidélité pour le script de Pull A Lucky Fish.
                 Organise parfaitement toutes les catégories demandées.
                 Architecture avec callbacks propres prêts à brancher le backend après test.
  Usage        : loadstring(game:HttpGet("https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/ui_sakura.luau"))()
  ========================================================================================
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

-- ========================================================================================
-- 🎨 CONFIGURATION DU THÈME SAKURA
-- ========================================================================================
local SakuraTheme = {
    Background    = Color3.fromRGB(24, 17, 24),     -- Fond sombre aux reflets fleurs de cerisier
    Card          = Color3.fromRGB(33, 23, 33),     -- Conteneur de carte légèrement surélevé
    CardSub       = Color3.fromRGB(42, 29, 42),     -- Sous-éléments & champs
    Accent        = Color3.fromRGB(255, 117, 151),  -- Rose vif cerisier (Sakura Pink)
    AccentSoft    = Color3.fromRGB(255, 182, 193),  -- Rose pastel doux (Light Pink)
    AccentGlow    = Color3.fromRGB(255, 204, 218),  -- Éclat blanc-rosé
    TextLight     = Color3.fromRGB(255, 245, 248),  -- Texte principal contrasté
    TextMuted     = Color3.fromRGB(214, 178, 194),  -- Texte secondaire discret
    Stroke        = Color3.fromRGB(255, 117, 151),  -- Bordure subtile
    ToggleOff     = Color3.fromRGB(56, 40, 56),     -- Interrupteur éteint
    ToggleOn      = Color3.fromRGB(255, 117, 151),  -- Interrupteur allumé
    Danger        = Color3.fromRGB(255, 95, 115),   -- Boutons d'action critique
    Success       = Color3.fromRGB(120, 220, 160),  -- Validation
}

-- Vrais Icônes Roblox Asset IDs
local Icons = {
    SakuraLogo  = "rbxassetid://10723415903", -- Blossom / Fleur
    Farm        = "rbxassetid://10709791437", -- Épée / Outil / Force
    Boxes       = "rbxassetid://10709819149", -- Boîte cadeau / Box
    Sell        = "rbxassetid://10723346959", -- Dollar / Pièces
    DNA         = "rbxassetid://10734950309", -- Tube à essai / Labo
    Teleport    = "rbxassetid://10723407389", -- Map pin / Navigation
    Settings    = "rbxassetid://10734950020", -- Rouage / Configuration
    Check       = "rbxassetid://10709790644", -- Coche
    Chevron     = "rbxassetid://10709790948", -- Flèche dropdown
}

-- ========================================================================================
-- 💾 ÉTAT GLOBAL & CALLBACKS (Prêts pour branchement du backend)
-- ========================================================================================
local SakuraConfig = {
    -- Auto Farm
    AutoTrain            = false,
    TrainCPS             = 12,
    AutoCollectCash      = true,
    CollectInterval      = 3,
    UpgradeAllFish       = false,
    UpgradeReserveCash   = 1000,
    AutoEquipBestTool    = true,

    -- Boxes & Eggs
    AutoOpenBoxes        = false,
    AutoHatchEggs        = false,
    AutoSkipEggTimer     = false,
    AutoBuyEggs          = false,
    SelectedEggType      = "ForestEgg",
    AutoBuyBoxes         = false,
    SelectedBoxType      = "CommonFloatCrate",

    -- Vente Avancée
    AutoSellMaster       = false,
    KeepMutations        = true,
    MinMutationsToKeep   = 1,
    SellRarities         = {
        Common    = true,
        Uncommon  = true,
        Rare      = false,
        Epic      = false,
        Legendary = false,
        Mythic    = false,
    },
    BlacklistFish        = {},

    -- DNA Lab
    AutoGrindDNA         = false,
    GrindRarities        = {
        Common   = true,
        Uncommon = true,
    },
    AutoStartResearch    = false,
    AutoClaimDNA         = false,

    -- Utilitaires
    AntiAFK              = true,
    WalkSpeed            = 16,
    Noclip               = false,
    HidePets             = false,
    NoCutscenes          = false,
    GpuSaver             = false,
}

local SakuraCallbacks = {
    onToggle = function(name, value)
        print("[SAKURA UI] Toggle changé :", name, "=", value)
    end,
    onSlider = function(name, value)
        print("[SAKURA UI] Slider ajusté :", name, "=", value)
    end,
    onDropdown = function(name, selected)
        print("[SAKURA UI] Dropdown sélectionné :", name, "=", selected)
    end,
    onAction = function(name)
        print("[SAKURA UI] Action déclenchée :", name)
    end,
}

-- ========================================================================================
-- 🖥️ CRÉATION DU CONTENEUR SCREEN GUI
-- ========================================================================================
local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
if targetParent:FindFirstChild("LuckyFish_SakuraUI") then
    targetParent:FindFirstChild("LuckyFish_SakuraUI"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LuckyFish_SakuraUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

-- Helper Tween
local function tween(inst, props, dur, style, dir)
    dur = dur or 0.25
    style = style or Enum.EasingStyle.Quart
    dir = dir or Enum.EasingDirection.Out
    local tw = TweenService:Create(inst, TweenInfo.new(dur, style, dir), props)
    tw:Play()
    return tw
end

-- ========================================================================================
-- 🪟 FENÊTRE PRINCIPALE
-- ========================================================================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "SakuraMain"
MainFrame.Size = UDim2.new(0, 680, 0, 480)
MainFrame.Position = UDim2.new(0.5, -340, 0.5, -240)
MainFrame.BackgroundColor3 = SakuraTheme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

-- Bordure dégradée éclat Sakura
local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.8
MainStroke.Color = SakuraTheme.Accent
MainStroke.Parent = MainFrame

local MainGradient = Instance.new("UIGradient")
MainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, SakuraTheme.Accent),
    ColorSequenceKeypoint.new(0.5, SakuraTheme.AccentSoft),
    ColorSequenceKeypoint.new(1.0, SakuraTheme.Accent),
})
MainGradient.Rotation = 45
MainGradient.Parent = MainStroke

-- Drag & Drop fluide
local dragging, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ========================================================================================
-- 🌸 SIDEBAR GAUCHE (NAVIGATION PAR ONGLETS & ICÔNES)
-- ========================================================================================
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(29, 20, 29)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 14)
SideCorner.Parent = Sidebar

-- Masquer l'arrondi droit de la sidebar pour fusionner avec le contenu
local SidePatch = Instance.new("Frame")
SidePatch.Size = UDim2.new(0, 14, 1, 0)
SidePatch.Position = UDim2.new(1, -14, 0, 0)
SidePatch.BackgroundColor3 = Color3.fromRGB(29, 20, 29)
SidePatch.BorderSizePixel = 0
SidePatch.Parent = Sidebar

-- En-tête Sidebar avec Logo Sakura
local HeaderBox = Instance.new("Frame")
HeaderBox.Size = UDim2.new(1, 0, 0, 60)
HeaderBox.BackgroundTransparency = 1
HeaderBox.Parent = Sidebar

local LogoIcon = Instance.new("ImageLabel")
LogoIcon.Size = UDim2.new(0, 26, 0, 26)
LogoIcon.Position = UDim2.new(0, 14, 0.5, -13)
LogoIcon.BackgroundTransparency = 1
LogoIcon.Image = Icons.SakuraLogo
LogoIcon.ImageColor3 = SakuraTheme.Accent
LogoIcon.Parent = HeaderBox

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -50, 0, 20)
TitleText.Position = UDim2.new(0, 48, 0, 12)
TitleText.BackgroundTransparency = 1
TitleText.Text = "SAKURA HUB"
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 13
TitleText.TextColor3 = SakuraTheme.TextLight
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = HeaderBox

local SubTitleText = Instance.new("TextLabel")
SubTitleText.Size = UDim2.new(1, -50, 0, 14)
SubTitleText.Position = UDim2.new(0, 48, 0, 32)
SubTitleText.BackgroundTransparency = 1
SubTitleText.Text = "Pull A Lucky Fish"
SubTitleText.Font = Enum.Font.Gotham
SubTitleText.TextSize = 10
SubTitleText.TextColor3 = SakuraTheme.AccentSoft
SubTitleText.TextXAlignment = Enum.TextXAlignment.Left
SubTitleText.Parent = HeaderBox

-- Séparateur délicat
local Sep1 = Instance.new("Frame")
Sep1.Size = UDim2.new(1, -24, 0, 1)
Sep1.Position = UDim2.new(0, 12, 0, 60)
Sep1.BackgroundColor3 = Color3.fromRGB(48, 33, 48)
Sep1.BorderSizePixel = 0
Sep1.Parent = Sidebar

-- Liste des onglets
local TabsScroll = Instance.new("ScrollingFrame")
TabsScroll.Size = UDim2.new(1, 0, 1, -110)
TabsScroll.Position = UDim2.new(0, 0, 0, 66)
TabsScroll.BackgroundTransparency = 1
TabsScroll.BorderSizePixel = 0
TabsScroll.ScrollBarThickness = 0
TabsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TabsScroll.Parent = Sidebar

local TabsLayout = Instance.new("UIListLayout")
TabsLayout.Padding = UDim.new(0, 4)
TabsLayout.Parent = TabsScroll

-- Pied de page Sidebar
local FootBox = Instance.new("Frame")
FootBox.Size = UDim2.new(1, 0, 0, 40)
FootBox.Position = UDim2.new(0, 0, 1, -40)
FootBox.BackgroundTransparency = 1
FootBox.Parent = Sidebar

local FootText = Instance.new("TextLabel")
FootText.Size = UDim2.new(1, -20, 1, 0)
FootText.Position = UDim2.new(0, 12, 0, 0)
FootText.BackgroundTransparency = 1
FootText.Text = "v1.0.0 • Main Account Ready"
FootText.Font = Enum.Font.Gotham
FootText.TextSize = 9
FootText.TextColor3 = SakuraTheme.TextMuted
FootText.TextXAlignment = Enum.TextXAlignment.Left
FootText.Parent = FootBox

-- ========================================================================================
-- 📄 ZONE DE CONTENU PRINCIPALE (PAGES DES ONGLETS)
-- ========================================================================================
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -188, 1, -44)
ContentArea.Position = UDim2.new(0, 184, 0, 38)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Barre supérieure de contrôle (Titre de l'onglet actif + Bouton Réduire / Fermer)
local TopControlBar = Instance.new("Frame")
TopControlBar.Size = UDim2.new(1, -180, 0, 36)
TopControlBar.Position = UDim2.new(0, 180, 0, 0)
TopControlBar.BackgroundTransparency = 1
TopControlBar.Parent = MainFrame

local ActivePageTitle = Instance.new("TextLabel")
ActivePageTitle.Size = UDim2.new(1, -80, 1, 0)
ActivePageTitle.Position = UDim2.new(0, 14, 0, 0)
ActivePageTitle.BackgroundTransparency = 1
ActivePageTitle.Text = "🌸 Auto-Farm & Force"
ActivePageTitle.Font = Enum.Font.GothamBold
ActivePageTitle.TextSize = 13
ActivePageTitle.TextColor3 = SakuraTheme.TextLight
ActivePageTitle.TextXAlignment = Enum.TextXAlignment.Left
ActivePageTitle.Parent = TopControlBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Color3.fromRGB(44, 28, 40)
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = SakuraTheme.AccentSoft
CloseBtn.Parent = TopControlBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

-- Bouton Fleur Sakura flottant pour ré-ouvrir si réduit
local FloatToggleBtn = Instance.new("ImageButton")
FloatToggleBtn.Name = "SakuraFloatButton"
FloatToggleBtn.Size = UDim2.new(0, 42, 0, 42)
FloatToggleBtn.Position = UDim2.new(0, 20, 0.5, -21)
FloatToggleBtn.BackgroundColor3 = SakuraTheme.Background
FloatToggleBtn.Image = Icons.SakuraLogo
FloatToggleBtn.ImageColor3 = SakuraTheme.Accent
FloatToggleBtn.Visible = false
FloatToggleBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatToggleBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = SakuraTheme.Accent
FloatStroke.Thickness = 1.5
FloatStroke.Parent = FloatToggleBtn

FloatToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    FloatToggleBtn.Visible = false
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.BackgroundColor3 = Color3.fromRGB(44, 28, 40)
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
MinBtn.TextColor3 = SakuraTheme.AccentSoft
MinBtn.Parent = TopControlBar

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    FloatToggleBtn.Visible = true
end)

-- ========================================================================================
-- 🛠️ SYSTÈME DE COMPOSANTS UI SAKURA (Cards, Toggles, Sliders, Dropdowns, Buttons)
-- ========================================================================================
local Pages = {}
local TabButtons = {}

local function createPage(pageId, pageTitle, iconAsset)
    local pageScroll = Instance.new("ScrollingFrame")
    pageScroll.Name = "Page_" .. pageId
    pageScroll.Size = UDim2.new(1, -10, 1, -10)
    pageScroll.Position = UDim2.new(0, 5, 0, 5)
    pageScroll.BackgroundTransparency = 1
    pageScroll.BorderSizePixel = 0
    pageScroll.ScrollBarThickness = 4
    pageScroll.ScrollBarImageColor3 = SakuraTheme.Accent
    pageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    pageScroll.Visible = false
    pageScroll.Parent = ContentArea

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 10)
    pageLayout.Parent = pageScroll

    -- Bouton dans la sidebar
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -16, 0, 36)
    tabBtn.Position = UDim2.new(0, 8, 0, 0)
    tabBtn.BackgroundColor3 = Color3.fromRGB(34, 24, 34)
    tabBtn.BackgroundTransparency = 1
    tabBtn.Text = ""
    tabBtn.AutoButtonColor = false
    tabBtn.Parent = TabsScroll

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabBtn

    local tabIcon = Instance.new("ImageLabel")
    tabIcon.Size = UDim2.new(0, 18, 0, 18)
    tabIcon.Position = UDim2.new(0, 10, 0.5, -9)
    tabIcon.BackgroundTransparency = 1
    tabIcon.Image = iconAsset or Icons.SakuraLogo
    tabIcon.ImageColor3 = SakuraTheme.TextMuted
    tabIcon.Parent = tabBtn

    local tabTitle = Instance.new("TextLabel")
    tabTitle.Size = UDim2.new(1, -38, 1, 0)
    tabTitle.Position = UDim2.new(0, 34, 0, 0)
    tabTitle.BackgroundTransparency = 1
    tabTitle.Text = pageTitle
    tabTitle.Font = Enum.Font.GothamSemibold
    tabTitle.TextSize = 11
    tabTitle.TextColor3 = SakuraTheme.TextMuted
    tabTitle.TextXAlignment = Enum.TextXAlignment.Left
    tabTitle.Parent = tabBtn

    Pages[pageId] = pageScroll
    TabButtons[pageId] = { Button = tabBtn, Icon = tabIcon, Title = tabTitle, RawTitle = pageTitle }

    tabBtn.MouseButton1Click:Connect(function()
        for id, p in pairs(Pages) do
            p.Visible = (id == pageId)
            local tb = TabButtons[id]
            if id == pageId then
                tween(tb.Button, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(48, 30, 48) }, 0.2)
                tween(tb.Icon, { ImageColor3 = SakuraTheme.Accent }, 0.2)
                tween(tb.Title, { TextColor3 = SakuraTheme.TextLight }, 0.2)
                ActivePageTitle.Text = "🌸 " .. tb.RawTitle
            else
                tween(tb.Button, { BackgroundTransparency = 1 }, 0.2)
                tween(tb.Icon, { ImageColor3 = SakuraTheme.TextMuted }, 0.2)
                tween(tb.Title, { TextColor3 = SakuraTheme.TextMuted }, 0.2)
            end
        end
    end)

    return pageScroll
end

-- Création d'une Carte (Section)
local function createCard(parent, title)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 0)
    card.BackgroundColor3 = SakuraTheme.Card
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(48, 34, 48)
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local cardPad = Instance.new("UIPadding")
    cardPad.PaddingTop = UDim.new(0, 10)
    cardPad.PaddingBottom = UDim.new(0, 12)
    cardPad.PaddingLeft = UDim.new(0, 12)
    cardPad.PaddingRight = UDim.new(0, 12)
    cardPad.Parent = card

    local cardLayout = Instance.new("UIListLayout")
    cardLayout.Padding = UDim.new(0, 8)
    cardLayout.Parent = card

    if title then
        local header = Instance.new("TextLabel")
        header.Size = UDim2.new(1, 0, 0, 18)
        header.BackgroundTransparency = 1
        header.Text = string.upper(title)
        header.Font = Enum.Font.GothamBold
        header.TextSize = 10
        header.TextColor3 = SakuraTheme.AccentSoft
        header.TextXAlignment = Enum.TextXAlignment.Left
        header.Parent = card
    end

    return card
end

-- Création d'un Toggle Switch
local function addToggle(card, labelText, defaultVal, callbackKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 32)
    row.BackgroundTransparency = 1
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -50, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = SakuraTheme.TextLight
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local switch = Instance.new("TextButton")
    switch.Size = UDim2.new(0, 42, 0, 22)
    switch.Position = UDim2.new(1, -42, 0.5, -11)
    switch.BackgroundColor3 = defaultVal and SakuraTheme.ToggleOn or SakuraTheme.ToggleOff
    switch.Text = ""
    switch.AutoButtonColor = false
    switch.Parent = row

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultVal and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local currentVal = defaultVal
    switch.MouseButton1Click:Connect(function()
        currentVal = not currentVal
        SakuraConfig[callbackKey] = currentVal

        if currentVal then
            tween(switch, { BackgroundColor3 = SakuraTheme.ToggleOn }, 0.2)
            tween(knob, { Position = UDim2.new(1, -19, 0.5, -8) }, 0.2)
        else
            tween(switch, { BackgroundColor3 = SakuraTheme.ToggleOff }, 0.2)
            tween(knob, { Position = UDim2.new(0, 3, 0.5, -8) }, 0.2)
        end

        SakuraCallbacks.onToggle(callbackKey, currentVal)
    end)

    return row
end

-- Création d'un Slider
local function addSlider(card, labelText, minVal, maxVal, defaultVal, unit, callbackKey)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 44)
    container.BackgroundTransparency = 1
    container.Parent = card

    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 18)
    header.BackgroundTransparency = 1
    header.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = SakuraTheme.TextLight
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = header

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 1, 0)
    valLbl.Position = UDim2.new(1, -60, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(defaultVal) .. (unit or "")
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 11
    valLbl.TextColor3 = SakuraTheme.AccentSoft
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = header

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 24)
    track.BackgroundColor3 = SakuraTheme.CardSub
    track.BorderSizePixel = 0
    track.Parent = container

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    local pctInit = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    fill.Size = UDim2.new(pctInit, 0, 1, 0)
    fill.BackgroundColor3 = SakuraTheme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local sliding = false
    local function updateSlide(input)
        local posX = input.Position.X - track.AbsolutePosition.X
        local pct = math.clamp(posX / track.AbsoluteSize.X, 0, 1)
        local value = math.floor(minVal + (maxVal - minVal) * pct)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        valLbl.Text = tostring(value) .. (unit or "")
        SakuraConfig[callbackKey] = value
        SakuraCallbacks.onSlider(callbackKey, value)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
            updateSlide(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlide(input)
        end
    end)

    return container
end

-- Création d'un Bouton d'Action
local function addButton(card, btnText, color, callbackKey)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = color or SakuraTheme.CardSub
    btn.Text = btnText
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = SakuraTheme.TextLight
    btn.AutoButtonColor = true
    btn.Parent = card

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = SakuraTheme.Accent
    stroke.Thickness = 0.8
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        tween(btn, { BackgroundColor3 = SakuraTheme.Accent }, 0.1):Play()
        task.wait(0.12)
        tween(btn, { BackgroundColor3 = color or SakuraTheme.CardSub }, 0.2):Play()
        SakuraCallbacks.onAction(callbackKey)
    end)

    return btn
end

-- ========================================================================================
-- 📑 CONSTRUCTION DES PAGES & CATÉGORIES DEMANDÉES
-- ========================================================================================

-- ----------------------------------------------------------------------------------------
-- PAGE 1 : 🌸 AUTO-FARM & FORCE
-- ----------------------------------------------------------------------------------------
local FarmPage = createPage("Farm", "Auto-Farm", Icons.Farm)

local TrainCard = createCard(FarmPage, "Entraînement de la Force")
addToggle(TrainCard, "Auto Train (Entraînement continu)", SakuraConfig.AutoTrain, "AutoTrain")
addSlider(TrainCard, "Vitesse de Clic (CPS)", 1, 30, SakuraConfig.TrainCPS, " CPS", "TrainCPS")
addToggle(TrainCard, "Auto-Équiper Meilleur Haltère", SakuraConfig.AutoEquipBestTool, "AutoEquipBestTool")

local CashCard = createCard(FarmPage, "Récolte & Tycoon")
addToggle(CashCard, "Auto Collect Cash (Plots de base)", SakuraConfig.AutoCollectCash, "AutoCollectCash")
addSlider(CashCard, "Intervalle de Collecte", 1, 10, SakuraConfig.CollectInterval, "s", "CollectInterval")
addToggle(CashCard, "Upgrade All Fish (Amélioration des plots)", SakuraConfig.UpgradeAllFish, "UpgradeAllFish")
addSlider(CashCard, "Réserve de Cash Sécurisée", 0, 50000, SakuraConfig.UpgradeReserveCash, "$", "UpgradeReserveCash")

-- ----------------------------------------------------------------------------------------
-- PAGE 2 : 📦 BOÎTES & ŒUFS
-- ----------------------------------------------------------------------------------------
local BoxesPage = createPage("Boxes", "Boîtes & Œufs", Icons.Boxes)

local HatchCard = createCard(BoxesPage, "Incubation & Ouverture")
addToggle(HatchCard, "Auto Open Placed Boxes (Ouvrir boîtes posées)", SakuraConfig.AutoOpenBoxes, "AutoOpenBoxes")
addToggle(HatchCard, "Auto Hatch Eggs (Éclosion dès que prêt)", SakuraConfig.AutoHatchEggs, "AutoHatchEggs")
addToggle(HatchCard, "Auto Skip Timer (Passer le temps d'attente)", SakuraConfig.AutoSkipEggTimer, "AutoSkipEggTimer")

local BuyCard = createCard(BoxesPage, "Achats Automatiques")
addToggle(BuyCard, "Auto Buy Eggs (Acheter œufs du shop)", SakuraConfig.AutoBuyEggs, "AutoBuyEggs")
addButton(BuyCard, "🥚 Type d'Œuf Actuel : ForestEgg", SakuraTheme.CardSub, "SelectEgg")
addToggle(BuyCard, "Auto Buy Boxes (Acheter caisses flotteurs)", SakuraConfig.AutoBuyBoxes, "AutoBuyBoxes")
addButton(BuyCard, "📦 Type de Boîte Actuel : CommonFloatCrate", SakuraTheme.CardSub, "SelectBox")

-- ----------------------------------------------------------------------------------------
-- PAGE 3 : 🐟 VENTE AVANCÉE
-- ----------------------------------------------------------------------------------------
local SellPage = createPage("Sell", "Vente Avancée", Icons.Sell)

local SellCard = createCard(SellPage, "Filtre Intelligent de Vente")
addToggle(SellCard, "Auto Sell Master (Activer la vente)", SakuraConfig.AutoSellMaster, "AutoSellMaster")
addToggle(SellCard, "🛡️ Protéger TOUTES les Mutations", SakuraConfig.KeepMutations, "KeepMutations")
addSlider(SellCard, "Min Mutations pour Protection", 1, 4, SakuraConfig.MinMutationsToKeep, "", "MinMutationsToKeep")

local RarityFilterCard = createCard(SellPage, "Raretés Autorisées à la Vente")
for rName, enabled in pairs(SakuraConfig.SellRarities) do
    addToggle(RarityFilterCard, "Vendre " .. rName, enabled, "SellRarity_" .. rName)
end

local PreviewCard = createCard(SellPage, "Vérification Compte Principal")
addButton(PreviewCard, "🔍 Tester le Filtre (Dry-Run / 0 vente réelle)", SakuraTheme.CardSub, "TestSellFilter")

-- ----------------------------------------------------------------------------------------
-- PAGE 4 : 🧬 DNA LAB
-- ----------------------------------------------------------------------------------------
local DnaPage = createPage("DNA", "DNA Lab", Icons.DNA)

local DnaCard = createCard(DnaPage, "Broyeur Génétique (Grinder)")
addToggle(DnaCard, "Auto Grind Fish for DNA (Broyer doublons)", SakuraConfig.AutoGrindDNA, "AutoGrindDNA")
addToggle(DnaCard, "Broyer Poissons Common", true, "GrindCommon")
addToggle(DnaCard, "Broyer Poissons Uncommon", true, "GrindUncommon")

local ResearchCard = createCard(DnaPage, "Recherche & Récolte")
addToggle(ResearchCard, "Auto Start DNA Research (Lancer cuves)", SakuraConfig.AutoStartResearch, "AutoStartResearch")
addToggle(ResearchCard, "Auto Claim DNA Results (Récupérer)", SakuraConfig.AutoClaimDNA, "AutoClaimDNA")

-- ----------------------------------------------------------------------------------------
-- PAGE 5 : 📍 TÉLÉPORTATIONS
-- ----------------------------------------------------------------------------------------
local TeleportPage = createPage("TP", "Téléportations", Icons.Teleport)

local TpCard = createCard(TeleportPage, "Points d'Intérêt & Zones")
addButton(TpCard, "🏠 TP Base Plot (Mon île)", SakuraTheme.CardSub, "TP_Base")
addButton(TpCard, "🎣 TP Zone de Pêche (ThrowZone)", SakuraTheme.CardSub, "TP_ThrowZone")
addButton(TpCard, "🏪 TP Shop Central (Vendeur)", SakuraTheme.CardSub, "TP_Shop")
addButton(TpCard, "🏘️ TP Fishing Village (Quêtes & Marché)", SakuraTheme.CardSub, "TP_Village")
addButton(TpCard, "🧬 TP DNA Lab & Grinder", SakuraTheme.CardSub, "TP_DnaLab")
addButton(TpCard, "🤿 TP The Deeps (Abysses)", SakuraTheme.CardSub, "TP_Deeps")
addButton(TpCard, "☢️ TP Silo & Réacteur Nucléaire", SakuraTheme.CardSub, "TP_Radioactive")
addButton(TpCard, "🛸 TP Océan Alien", SakuraTheme.CardSub, "TP_Alien")

-- ----------------------------------------------------------------------------------------
-- PAGE 6 : ⚙️ SÉCURITÉ & UTILITAIRES
-- ----------------------------------------------------------------------------------------
local SettingsPage = createPage("Settings", "Utilitaires", Icons.Settings)

local SafetyCard = createCard(SettingsPage, "Sécurité Compte & Anti-AFK")
addToggle(SafetyCard, "Anti-AFK (Doux, SANS autorejoin)", SakuraConfig.AntiAFK, "AntiAFK")

-- Implémentation locale de l'anti-AFK sans autorejoin
LocalPlayer.Idled:Connect(function()
    if SakuraConfig.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end
end)

local PlayerModsCard = createCard(SettingsPage, "Mouvements du Joueur")
addSlider(PlayerModsCard, "Vitesse de Course (WalkSpeed)", 16, 120, SakuraConfig.WalkSpeed, " studs", "WalkSpeed")
addToggle(PlayerModsCard, "Noclip (Traverser les obstacles)", SakuraConfig.Noclip, "Noclip")

-- Noclip loop
RunService.Stepped:Connect(function()
    if SakuraConfig.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

local PerfCard = createCard(SettingsPage, "Performances & FPS")
addToggle(PerfCard, "Masquer les Familiers (Boost FPS)", SakuraConfig.HidePets, "HidePets")
addToggle(PerfCard, "Supprimer les Cinématiques", SakuraConfig.NoCutscenes, "NoCutscenes")

-- ========================================================================================
-- 🚀 ACTIVATION DU PREMIER ONGLET PAR DÉFAUT
-- ========================================================================================
if Pages["Farm"] and TabButtons["Farm"] then
    Pages["Farm"].Visible = true
    local tb = TabButtons["Farm"]
    tb.Button.BackgroundTransparency = 0
    tb.Button.BackgroundColor3 = Color3.fromRGB(48, 30, 48)
    tb.Icon.ImageColor3 = SakuraTheme.Accent
    tb.Title.TextColor3 = SakuraTheme.TextLight
end

print("🌸 [SAKURA UI] Chargé avec succès pour Pull A Lucky Fish !")
