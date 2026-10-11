--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — SAKURA PREMIUM SUITE
  ========================================================================================
  Features:
    1. 💰 Auto-Collect Cash   - Ultra-clean base plot collection loop
    2. 🥚 Auto-Buy Eggs       - Buys all available in-game eggs (skips Robux Mythic Egg)
    3. 📦 Auto-Buy Boxes      - Buys Float Crates & Functional Objects Crates
    4. 🐟 Fast Auto-Sell      - High-performance, stable selling with customizable
                                filters for Mutations and Fish Rarities to keep
    5. 🛑 Clean Teardown      - Closing the menu gracefully halts all background tasks
    6. 🌸 Modern Fluent UI    - 100% English, sleek glassmorphism, responsive & smooth
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
-- 1. CLEAN TEARDOWN & LIFECYCLE MANAGEMENT
-- ========================================================================================
_G.__SAKURA_LUCKYFISH = (_G.__SAKURA_LUCKYFISH or 0) + 1
local CURRENT_SESSION = _G.__SAKURA_LUCKYFISH

local isRunning = true
local connections = {}

local function cleanShutdown()
    if not isRunning then return end
    isRunning = false
    _G.__SAKURA_LUCKYFISH = (_G.__SAKURA_LUCKYFISH or 0) + 1

    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)

    local oldGui = LocalPlayer:FindFirstChildOfClass("PlayerGui") and LocalPlayer.PlayerGui:FindFirstChild("SakuraLuckyFish_Clean")
    if oldGui then
        oldGui:Destroy()
    end
    print("[SAKURA] Clean shutdown completed. All background tasks halted.")
end

-- ========================================================================================
-- 2. GAME SERVICES & DATA BINDINGS
-- ========================================================================================
local Shared = ReplicatedStorage:WaitForChild("shared", 10)
local Client = ReplicatedStorage:WaitForChild("client", 10)

if not Shared or not Client then
    warn("[SAKURA] Game shared/client folders missing.")
    return
end

local Remotes = require(Shared:WaitForChild("Remotes", 10))
local CPD = require(Client:WaitForChild("ClientPlayerData", 10))

-- Load Fish Config for accurate rarity resolution
local FishConfig = {}
pcall(function()
    local cfg = Shared:FindFirstChild("config") and Shared.config:FindFirstChild("FishConfig")
    if cfg then FishConfig = require(cfg) end
end)

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

-- Universal Red Remote Caller
local function fireRemote(remoteObj, ...)
    if not isRunning or not remoteObj then return false end
    local args = table.pack(...)

    if typeof(remoteObj) == "table" then
        if remoteObj.Fire then pcall(function() remoteObj:Fire(table.unpack(args, 1, args.n)) end) end
        if remoteObj.fire then pcall(function() remoteObj:fire(table.unpack(args, 1, args.n)) end) end
        if remoteObj.Call then
            pcall(function()
                task.spawn(function() remoteObj:Call(table.unpack(args, 1, args.n)):Await() end)
            end)
        end
    elseif typeof(remoteObj) == "Instance" then
        if remoteObj:IsA("RemoteEvent") then
            pcall(function() remoteObj:FireServer(table.unpack(args, 1, args.n)) end)
        elseif remoteObj:IsA("RemoteFunction") then
            pcall(function()
                task.spawn(function() remoteObj:InvokeServer(table.unpack(args, 1, args.n)) end)
            end)
        end
    end
    return true
end

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
-- 3. CONFIGURATION STATE
-- ========================================================================================
local Config = {
    -- Auto Collect Cash
    AutoCollectCash = true,

    -- Auto Buy Eggs
    AutoBuyEggs     = true,

    -- Auto Buy Boxes
    AutoBuyBoxes    = true,

    -- Auto Sell
    AutoSell        = false,
    KeepAllMutations = true,
    KeepMutations   = {
        ["Gold"]        = true,
        ["Diamond"]     = true,
        ["Shiny"]       = true,
        ["Rainbow"]     = true,
        ["Radioactive"] = true,
        ["Molten"]      = true,
        ["Frozen"]      = true,
        ["Bloody"]      = true,
        ["Cat"]         = true,
        ["Enriched"]    = true,
        ["Bubblegum"]   = true,
        ["Pollinated"]  = true,
    },
    KeepRarities    = {
        ["Common"]    = false,
        ["Uncommon"]  = false,
        ["Rare"]      = false,
        ["Epic"]      = true,
        ["Legendary"] = true,
        ["Mythic"]    = true,
        ["Devine"]    = true,
        ["Godly"]     = true,
        ["Celestial"] = true,
        ["Hacked"]    = true,
        ["Dino"]      = true,
        ["SCP"]       = true,
        ["Backroom"]  = true,
        ["Secret"]    = true,
        ["OG"]        = true,
    },
    KeepFishSpecies = {},
}

-- ========================================================================================
-- 4. AUTOMATION LOGIC (FAST, STABLE & SAFE)
-- ========================================================================================

-- Cash Collection
local function collectCash()
    local s = getState()
    local slots = s.baseSlots or {}
    for slotIndex, _ in pairs(slots) do
        fireRemote(Remotes.RequestCollectCash, tostring(slotIndex))
        fireRemote(Remotes.RequestCollectCash, tonumber(slotIndex))
    end
    fireRemote(Remotes.RequestCollectCash)
    fireRemote(Remotes.AutoCollectActivated)
    fireRemote(Remotes.RequestUseAutoCollect, true)
end

-- Buy Eggs (Skips Mythic Robux Egg)
local function buyEggs()
    if not Config.AutoBuyEggs then return end
    local s = getState()
    local items = s.eggShopItems or {}
    local sold = s.eggShopSoldSlots or {}

    for slotIdx = 1, 3 do
        local eggName = items[slotIdx]
        local isSold = sold[slotIdx] == true

        if eggName and not isSold then
            -- Skip Robux paid eggs
            if eggName ~= "MythicEgg" and not tostring(eggName):lower():find("mythic") then
                fireRemote(Remotes.BuyEgg, slotIdx)
                fireRemote(Remotes.BuyEgg, tostring(slotIdx))
                fireRemote(Remotes.BuyEgg, eggName)
                fireRemote(Remotes.BuyEgg, slotIdx, eggName)
                task.wait(0.25)
            end
        end
    end
end

-- Buy Boxes (Float Crates & Functional Objects Crates)
local function buyBoxes()
    if not Config.AutoBuyBoxes then return end
    local s = getState()
    local items = s.lootboxShopItems or {}
    local sold = s.lootboxShopSoldSlots or {}

    for slotIdx = 1, 3 do
        local boxName = items[slotIdx]
        local isSold = sold[slotIdx] == true

        if boxName and not isSold then
            fireRemote(Remotes.BuyFloatLootbox, slotIdx)
            fireRemote(Remotes.BuyFloatLootbox, tostring(slotIdx))
            fireRemote(Remotes.BuyFloatLootbox, boxName)
            fireRemote(Remotes.BuyFloatLootbox, slotIdx, boxName)

            if boxName == "FunctionalObjectsCrate" or tostring(boxName):find("Functional") then
                fireRemote(Remotes.BuyDecorationsStoreItem, "FunctionalObjectsCrate")
                fireRemote(Remotes.BuyDecorationsStoreItem, slotIdx)
                fireRemote(Remotes.BuyDecoration, "FunctionalObjectsCrate")
            end
            task.wait(0.25)
        end
    end

    -- Check decoration store for FunctionalObjectsCrate
    local decoStock = s.decorationsStoreStock or {}
    if decoStock["FunctionalObjectsCrate"] ~= 0 then
        fireRemote(Remotes.BuyDecorationsStoreItem, "FunctionalObjectsCrate")
        fireRemote(Remotes.BuyDecorationsStoreItem, 1)
        fireRemote(Remotes.BuyDecoration, "FunctionalObjectsCrate")
    end
end

-- Fast & Stable Auto-Sell
local isSellingBusy = false
local function runAutoSell()
    if not Config.AutoSell or isSellingBusy then return end
    isSellingBusy = true

    local s = getState()
    local inv = s.inventory or {}
    local toSellKeys = {}

    for key, item in pairs(inv) do
        if type(item) == "table" and (item.Category == "Fish" or tostring(key):find("@")) then
            local species, level, mutation = tostring(key):match("^(.-)@(%d+)@(.+)$")
            if not species then
                species, level = tostring(key):match("^(.-)@(%d+)$")
            end
            species = species or item.ConfigName or tostring(key)
            mutation = mutation or (item.Mutations and item.Mutations[1]) or item.Mutation

            local keep = false

            -- 1. Check Mutation Whitelist
            if mutation and mutation ~= "" then
                if Config.KeepAllMutations or Config.KeepMutations[mutation] then
                    keep = true
                end
            end

            -- 2. Check Species Whitelist
            if Config.KeepFishSpecies[species] then
                keep = true
            end

            -- 3. Check Rarity Whitelist
            local rarity = item.Rarity or (FishConfig[species] and FishConfig[species].Rarity) or "Common"
            if Config.KeepRarities[rarity] then
                keep = true
            end

            -- 4. Check Protected / Favorites
            if s.favorites and s.favorites[key] then keep = true end
            if s.lockedFish and s.lockedFish[key] then keep = true end

            if not keep then
                table.insert(toSellKeys, key)
            end
        end
    end

    if #toSellKeys > 0 then
        -- Attempt batch sell first
        local batchFired = fireRemote(Remotes.SellFishBatch, toSellKeys)
        if not batchFired or #toSellKeys > 15 then
            -- Rapid staggered fallback
            for i = 1, math.min(#toSellKeys, 20) do
                if not isRunning or not Config.AutoSell then break end
                fireRemote(Remotes.SellFish, toSellKeys[i])
                if i % 6 == 0 then task.wait(0.04) end
            end
        end
    end

    isSellingBusy = false
end

-- Main Background Worker
task.spawn(function()
    while isRunning and _G.__SAKURA_LUCKYFISH == CURRENT_SESSION do
        if Config.AutoCollectCash then
            pcall(collectCash)
        end
        if Config.AutoBuyEggs then
            pcall(buyEggs)
        end
        if Config.AutoBuyBoxes then
            pcall(buyBoxes)
        end
        if Config.AutoSell then
            pcall(runAutoSell)
        end
        task.wait(1.4)
    end
end)

-- ========================================================================================
-- 5. MODERN SAKURA UI (FULL ENGLISH, ULTRA SLEEK)
-- ========================================================================================
local Theme = {
    Background = Color3.fromRGB(19, 14, 20),
    Sidebar    = Color3.fromRGB(25, 18, 26),
    Card       = Color3.fromRGB(30, 22, 32),
    CardSub    = Color3.fromRGB(42, 30, 44),
    Accent     = Color3.fromRGB(255, 107, 139),
    AccentSoft = Color3.fromRGB(255, 175, 195),
    Text       = Color3.fromRGB(255, 245, 248),
    TextDim    = Color3.fromRGB(205, 170, 188),
    Green      = Color3.fromRGB(115, 230, 155),
    Red        = Color3.fromRGB(255, 95, 120),
    Stroke     = Color3.fromRGB(255, 107, 139),
}

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SakuraLuckyFish_Clean"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

-- Handle Destroying connection for clean shutdown
table.insert(connections, ScreenGui.Destroying:Connect(cleanShutdown))

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "SakuraMain"
Main.Size = UDim2.new(0, 580, 0, 420)
Main.Position = UDim2.new(0.5, -290, 0.5, -210)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Stroke
MainStroke.Thickness = 1.4
MainStroke.Parent = Main

-- Dragging
local dragging, dragStart, startPos
table.insert(connections, Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

-- Top Bar
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Theme.Sidebar
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 12)
TopCorner.Parent = TopBar

local TopTitle = Instance.new("TextLabel")
TopTitle.Size = UDim2.new(1, -90, 1, 0)
TopTitle.Position = UDim2.new(0, 14, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "🌸 SAKURA • Lucky Fish Automation"
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13
TopTitle.TextColor3 = Theme.Text
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.Parent = TopBar

-- Close & Minimize Buttons
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Theme.CardSub
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.TextColor3 = Theme.AccentSoft
CloseBtn.Parent = TopBar
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(cleanShutdown)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.BackgroundColor3 = Theme.CardSub
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 11
MinBtn.TextColor3 = Theme.AccentSoft
MinBtn.Parent = TopBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Floating Sakura Blossom Button (When Minimized)
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 42, 0, 42)
FloatBtn.Position = UDim2.new(0, 15, 0.5, -21)
FloatBtn.BackgroundColor3 = Theme.Background
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

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -48)
Sidebar.Position = UDim2.new(0, 8, 0, 44)
Sidebar.BackgroundColor3 = Theme.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 10)
SideCorner.Parent = Sidebar

local SideLayout = Instance.new("UIListLayout")
SideLayout.Padding = UDim.new(0, 6)
SideLayout.Parent = Sidebar

local SidePad = Instance.new("UIPadding")
SidePad.PaddingTop = UDim.new(0, 8)
SidePad.PaddingLeft = UDim.new(0, 6)
SidePad.PaddingRight = UDim.new(0, 6)
SidePad.Parent = Sidebar

-- Content Pages Container
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -164, 1, -48)
Container.Position = UDim2.new(0, 156, 0, 44)
Container.BackgroundTransparency = 1
Container.Parent = Main

local Tabs = {}
local TabBtns = {}

local function createTab(id, title)
    local page = Instance.new("ScrollingFrame")
    page.Name = "Page_" .. id
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = Theme.Accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = Container

    local pageLayout = Instance.new("UIListLayout")
    pageLayout.Padding = UDim.new(0, 8)
    pageLayout.Parent = page

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Theme.Card
    btn.Text = title
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Theme.Accent
    btnStroke.Thickness = 0.8
    btnStroke.Transparency = 0.7
    btnStroke.Parent = btn

    Tabs[id] = page
    TabBtns[id] = { Button = btn, Stroke = btnStroke }

    btn.MouseButton1Click:Connect(function()
        for tId, p in pairs(Tabs) do
            p.Visible = (tId == id)
            local b = TabBtns[tId]
            if tId == id then
                b.Button.BackgroundColor3 = Theme.CardSub
                b.Button.TextColor3 = Theme.AccentSoft
                b.Stroke.Transparency = 0
            else
                b.Button.BackgroundColor3 = Theme.Card
                b.Button.TextColor3 = Theme.TextDim
                b.Stroke.Transparency = 0.7
            end
        end
    end)

    return page
end

local PageFarm  = createTab("Farm", "💰 Farm & Cash")
local PageEggs  = createTab("Eggs", "🥚 Eggs & Boxes")
local PageSell  = createTab("Sell", "🐟 Auto-Sell")

-- Card Builder
local function makeCard(parent, title)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 0)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = card

    if title then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = string.upper(title)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 10
        lbl.TextColor3 = Theme.AccentSoft
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card
    end
    return card
end

-- Toggle Switch Builder
local function makeToggle(card, title, defaultVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 36, 0, 18)
    btn.Position = UDim2.new(1, -36, 0.5, -9)
    btn.BackgroundColor3 = defaultVal and Theme.Accent or Theme.CardSub
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = btn

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = defaultVal and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = btn

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local val = defaultVal
    btn.MouseButton1Click:Connect(function()
        val = not val
        if val then
            btn.BackgroundColor3 = Theme.Accent
            knob.Position = UDim2.new(1, -16, 0.5, -7)
        else
            btn.BackgroundColor3 = Theme.CardSub
            knob.Position = UDim2.new(0, 2, 0.5, -7)
        end
        callback(val)
    end)
    return row
end

-- Action Button Builder
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
-- 📑 TAB 1: FARM & CASH
-- ========================================================================================
local BalanceCard = makeCard(PageFarm, "Live Balance")
local BalLabel = Instance.new("TextLabel")
BalLabel.Size = UDim2.new(1, 0, 0, 18)
BalLabel.BackgroundTransparency = 1
BalLabel.Font = Enum.Font.GothamBold
BalLabel.TextSize = 12
BalLabel.TextColor3 = Theme.Green
BalLabel.TextXAlignment = Enum.TextXAlignment.Left
BalLabel.Text = "💰 Cash: Loading..."
BalLabel.Parent = BalanceCard

local CashAutoCard = makeCard(PageFarm, "Auto Cash Collection")
makeToggle(CashAutoCard, "Auto Collect Cash (All Base Slots)", Config.AutoCollectCash, function(v)
    Config.AutoCollectCash = v
end)
makeButton(CashAutoCard, "⚡ Force Collect Now", function()
    collectCash()
end)

-- ========================================================================================
-- 📑 TAB 2: EGGS & BOXES
-- ========================================================================================
local EggCard = makeCard(PageEggs, "Egg Shop (Skips Mythic Robux)")
makeToggle(EggCard, "Auto Buy Eggs in Stock", Config.AutoBuyEggs, function(v)
    Config.AutoBuyEggs = v
end)
local EggStockLabel = Instance.new("TextLabel")
EggStockLabel.Size = UDim2.new(1, 0, 0, 16)
EggStockLabel.BackgroundTransparency = 1
EggStockLabel.Font = Enum.Font.Gotham
EggStockLabel.TextSize = 10
EggStockLabel.TextColor3 = Theme.TextDim
EggStockLabel.TextXAlignment = Enum.TextXAlignment.Left
EggStockLabel.Text = "Stock: Scanning..."
EggStockLabel.Parent = EggCard

local BoxCard = makeCard(PageEggs, "Box Shop (Floats & Functional Crates)")
makeToggle(BoxCard, "Auto Buy Boxes & Functional Crates", Config.AutoBuyBoxes, function(v)
    Config.AutoBuyBoxes = v
end)
local BoxStockLabel = Instance.new("TextLabel")
BoxStockLabel.Size = UDim2.new(1, 0, 0, 16)
BoxStockLabel.BackgroundTransparency = 1
BoxStockLabel.Font = Enum.Font.Gotham
BoxStockLabel.TextSize = 10
BoxStockLabel.TextColor3 = Theme.TextDim
BoxStockLabel.TextXAlignment = Enum.TextXAlignment.Left
BoxStockLabel.Text = "Stock: Scanning..."
BoxStockLabel.Parent = BoxCard

-- ========================================================================================
-- 📑 TAB 3: FAST AUTO-SELL & SMART FILTERS
-- ========================================================================================
local SellMasterCard = makeCard(PageSell, "Auto-Sell Master")
makeToggle(SellMasterCard, "Enable High-Speed Auto-Sell", Config.AutoSell, function(v)
    Config.AutoSell = v
end)
makeToggle(SellMasterCard, "Keep ALL Mutated Fish (Safety Master)", Config.KeepAllMutations, function(v)
    Config.KeepAllMutations = v
end)
makeButton(SellMasterCard, "⚡ Trigger Sell Pass Now", function()
    runAutoSell()
end)

local MutFilterCard = makeCard(PageSell, "Mutations to Keep (Whitelist)")
local mutationList = {
    "Shiny", "Rainbow", "Radioactive", "Diamond", "Gold",
    "Molten", "Frozen", "Bloody", "Cat", "Enriched"
}
for _, mut in ipairs(mutationList) do
    makeToggle(MutFilterCard, "Keep " .. mut .. " Mutation", Config.KeepMutations[mut] or false, function(v)
        Config.KeepMutations[mut] = v
    end)
end

local RarityFilterCard = makeCard(PageSell, "Fish Rarities to Keep (Whitelist)")
local rarityList = {
    "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Devine", "Godly", "Secret"
}
for _, rar in ipairs(rarityList) do
    makeToggle(RarityFilterCard, "Keep " .. rar .. " Fish", Config.KeepRarities[rar] or false, function(v)
        Config.KeepRarities[rar] = v
    end)
end

-- ========================================================================================
-- 🔄 LIVE STATS UPDATER
-- ========================================================================================
task.spawn(function()
    while isRunning and _G.__SAKURA_LUCKYFISH == CURRENT_SESSION do
        pcall(function()
            local s = getState()
            local m = s.money or 0
            local g = s.gems or 0
            BalLabel.Text = string.format("💰 Cash: %s  |  💎 Gems: %s", formatNumber(m), formatNumber(g))

            -- Update Egg Stock
            local eItems = s.eggShopItems or {}
            local eSold = s.eggShopSoldSlots or {}
            local eTxt = {}
            for i = 1, 3 do
                table.insert(eTxt, string.format("#%d: %s (%s)", i, eItems[i] or "-", eSold[i] and "Sold" or "Ready"))
            end
            EggStockLabel.Text = table.concat(eTxt, " | ")

            -- Update Box Stock
            local bItems = s.lootboxShopItems or {}
            local bSold = s.lootboxShopSoldSlots or {}
            local bTxt = {}
            for i = 1, 3 do
                table.insert(bTxt, string.format("#%d: %s (%s)", i, bItems[i] or "-", bSold[i] and "Sold" or "Ready"))
            end
            BoxStockLabel.Text = table.concat(bTxt, " | ")
        end)
        task.wait(1.4)
    end
end)

-- Initialize First Tab
Tabs["Farm"].Visible = true
TabBtns["Farm"].Button.BackgroundColor3 = Theme.CardSub
TabBtns["Farm"].Button.TextColor3 = Theme.AccentSoft
TabBtns["Farm"].Stroke.Transparency = 0

print("🌸 [SAKURA] Premium Suite loaded with full teardown & Auto-Sell!")
