--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — SAKURA CLEAN AUTOMATION
  ========================================================================================
  Features:
    1. 💰 Auto Collect Cash   - Clean loop collecting from all base slots
    2. 🥚 Auto Buy Eggs       - Buys all available in-game eggs (skips Mythic Robux egg)
    3. 📦 Auto Buy Boxes      - Buys all crates (Float Crates & Functional Objects Crate)
    4. 🌸 Minimalist UI       - Clean Sakura aesthetic, English only, draggable & minimizable
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
-- 1. GAME SERVICES & STATE
-- ========================================================================================
local Shared = ReplicatedStorage:WaitForChild("shared", 10)
local Client = ReplicatedStorage:WaitForChild("client", 10)

if not Shared or not Client then
    warn("[SAKURA] Critical folders missing in ReplicatedStorage.")
    return
end

local Remotes = require(Shared:WaitForChild("Remotes", 10))
local CPD = require(Client:WaitForChild("ClientPlayerData", 10))

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

-- Universal Red Remote Invoker
local function fireRemote(remoteObj, ...)
    if not remoteObj then return false end
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
-- 2. CONFIGURATION
-- ========================================================================================
local Config = {
    AutoCollectCash = true,
    AutoBuyEggs     = true,
    AutoBuyBoxes    = true,
}

-- ========================================================================================
-- 3. CORE LOGIC
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

-- Buy Eggs (Skips MythicEgg which costs Robux)
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
                task.wait(0.2)
            end
        end
    end
end

-- Buy Boxes (Float Crates & Functional Objects Crate)
local function buyBoxes()
    if not Config.AutoBuyBoxes then return end
    local s = getState()
    local items = s.lootboxShopItems or {}
    local sold = s.lootboxShopSoldSlots or {}

    for slotIdx = 1, 3 do
        local boxName = items[slotIdx]
        local isSold = sold[slotIdx] == true

        if boxName and not isSold then
            -- Standard Float Lootbox purchase
            fireRemote(Remotes.BuyFloatLootbox, slotIdx)
            fireRemote(Remotes.BuyFloatLootbox, tostring(slotIdx))
            fireRemote(Remotes.BuyFloatLootbox, boxName)
            fireRemote(Remotes.BuyFloatLootbox, slotIdx, boxName)

            -- If it's a functional objects crate or from decorations store
            if boxName == "FunctionalObjectsCrate" or tostring(boxName):find("Functional") then
                fireRemote(Remotes.BuyDecorationsStoreItem, "FunctionalObjectsCrate")
                fireRemote(Remotes.BuyDecorationsStoreItem, slotIdx)
                fireRemote(Remotes.BuyDecoration, "FunctionalObjectsCrate")
            end
            task.wait(0.2)
        end
    end

    -- Also check decorations store stock directly for FunctionalObjectsCrate
    local decoStock = s.decorationsStoreStock or {}
    if decoStock["FunctionalObjectsCrate"] ~= 0 then
        fireRemote(Remotes.BuyDecorationsStoreItem, "FunctionalObjectsCrate")
        fireRemote(Remotes.BuyDecorationsStoreItem, 1)
        fireRemote(Remotes.BuyDecoration, "FunctionalObjectsCrate")
    end
end

-- Background Loop
_G.__SAKURA_LUCKYFISH = (_G.__SAKURA_LUCKYFISH or 0) + 1
local GEN = _G.__SAKURA_LUCKYFISH

task.spawn(function()
    while _G.__SAKURA_LUCKYFISH == GEN do
        if Config.AutoCollectCash then
            pcall(collectCash)
        end
        if Config.AutoBuyEggs then
            pcall(buyEggs)
        end
        if Config.AutoBuyBoxes then
            pcall(buyBoxes)
        end
        task.wait(1.5)
    end
end)

-- ========================================================================================
-- 4. MINIMALIST SAKURA UI (CLEAN & ENGLISH ONLY)
-- ========================================================================================
local Theme = {
    Background = Color3.fromRGB(22, 16, 22),
    Card       = Color3.fromRGB(30, 22, 30),
    CardSub    = Color3.fromRGB(40, 28, 40),
    Accent     = Color3.fromRGB(255, 117, 151),
    AccentSoft = Color3.fromRGB(255, 182, 193),
    Text       = Color3.fromRGB(255, 245, 248),
    TextDim    = Color3.fromRGB(214, 178, 194),
    Green      = Color3.fromRGB(120, 230, 160),
    Red        = Color3.fromRGB(255, 110, 130),
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

-- Main Window
local Main = Instance.new("Frame")
Main.Name = "SakuraMain"
Main.Size = UDim2.new(0, 420, 0, 360)
Main.Position = UDim2.new(0.5, -210, 0.5, -180)
Main.BackgroundColor3 = Theme.Background
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

-- Dragging logic
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

-- Title Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Theme.Card
Header.BorderSizePixel = 0
Header.Parent = Main

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🌸 SAKURA • Pull A Lucky Fish"
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextColor3 = Theme.Text
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Window Controls (Minimize & Close)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Theme.CardSub
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.TextColor3 = Theme.AccentSoft
CloseBtn.Parent = Header
local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -66, 0.5, -13)
MinBtn.BackgroundColor3 = Theme.CardSub
MinBtn.Text = "—"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 11
MinBtn.TextColor3 = Theme.AccentSoft
MinBtn.Parent = Header
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

-- Floating Sakura Toggle Button
local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 40, 0, 40)
FloatBtn.Position = UDim2.new(0, 15, 0.5, -20)
FloatBtn.BackgroundColor3 = Theme.Background
FloatBtn.Text = "🌸"
FloatBtn.TextSize = 20
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatBtn
local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 1.4
FloatStroke.Parent = FloatBtn
FloatBtn.MouseButton1Click:Connect(function()
    Main.Visible = true
    FloatBtn.Visible = false
end)
MinBtn.MouseButton1Click:Connect(function()
    Main.Visible = false
    FloatBtn.Visible = true
end)

-- Content Container
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -20, 1, -52)
Content.Position = UDim2.new(0, 10, 0, 46)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Theme.Accent
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.Parent = Main

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.Parent = Content

local function createCard(title)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = Content

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

local function createToggle(card, title, defaultVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -48, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 38, 0, 18)
    btn.Position = UDim2.new(1, -38, 0.5, -9)
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

    local current = defaultVal
    btn.MouseButton1Click:Connect(function()
        current = not current
        if current then
            btn.BackgroundColor3 = Theme.Accent
            knob.Position = UDim2.new(1, -16, 0.5, -7)
        else
            btn.BackgroundColor3 = Theme.CardSub
            knob.Position = UDim2.new(0, 2, 0.5, -7)
        end
        callback(current)
    end)
    return row
end

-- CARD 1: LIVE BALANCE
local BalCard = createCard("Account Balance")
local BalLabel = Instance.new("TextLabel")
BalLabel.Size = UDim2.new(1, 0, 0, 18)
BalLabel.BackgroundTransparency = 1
BalLabel.Font = Enum.Font.GothamBold
BalLabel.TextSize = 12
BalLabel.TextColor3 = Theme.Green
BalLabel.TextXAlignment = Enum.TextXAlignment.Left
BalLabel.Text = "💰 Cash: Loading..."
BalLabel.Parent = BalCard

-- CARD 2: AUTO COLLECT CASH
local CashCard = createCard("Cash Collection")
createToggle(CashCard, "Auto Collect Cash (All Base Slots)", Config.AutoCollectCash, function(val)
    Config.AutoCollectCash = val
end)

local CollectBtn = Instance.new("TextButton")
CollectBtn.Size = UDim2.new(1, 0, 0, 26)
CollectBtn.BackgroundColor3 = Theme.CardSub
CollectBtn.Text = "⚡ Force Collect Now"
CollectBtn.Font = Enum.Font.GothamSemibold
CollectBtn.TextSize = 11
CollectBtn.TextColor3 = Theme.Text
CollectBtn.Parent = CashCard
local CbCorner = Instance.new("UICorner")
CbCorner.CornerRadius = UDim.new(0, 6)
CbCorner.Parent = CollectBtn
CollectBtn.MouseButton1Click:Connect(function()
    collectCash()
    CollectBtn.Text = "✔ Collected!"
    task.wait(0.8)
    CollectBtn.Text = "⚡ Force Collect Now"
end)

-- CARD 3: AUTO BUY EGGS
local EggCard = createCard("Egg Automation")
createToggle(EggCard, "Auto Buy Eggs (Skips Mythic Robux Egg)", Config.AutoBuyEggs, function(val)
    Config.AutoBuyEggs = val
end)

local EggStatus = Instance.new("TextLabel")
EggStatus.Size = UDim2.new(1, 0, 0, 16)
EggStatus.BackgroundTransparency = 1
EggStatus.Font = Enum.Font.Gotham
EggStatus.TextSize = 10
EggStatus.TextColor3 = Theme.TextDim
EggStatus.TextXAlignment = Enum.TextXAlignment.Left
EggStatus.Text = "Shop Stock: Scanning..."
EggStatus.Parent = EggCard

-- CARD 4: AUTO BUY BOXES
local BoxCard = createCard("Box & Crate Automation")
createToggle(BoxCard, "Auto Buy Boxes (Floats & Functional Crates)", Config.AutoBuyBoxes, function(val)
    Config.AutoBuyBoxes = val
end)

local BoxStatus = Instance.new("TextLabel")
BoxStatus.Size = UDim2.new(1, 0, 0, 16)
BoxStatus.BackgroundTransparency = 1
BoxStatus.Font = Enum.Font.Gotham
BoxStatus.TextSize = 10
BoxStatus.TextColor3 = Theme.TextDim
BoxStatus.TextXAlignment = Enum.TextXAlignment.Left
BoxStatus.Text = "Shop Stock: Scanning..."
BoxStatus.Parent = BoxCard

-- Real-Time Status Updater Loop
task.spawn(function()
    while _G.__SAKURA_LUCKYFISH == GEN do
        pcall(function()
            local s = getState()
            local money = s.money or 0
            local gems = s.gems or 0
            BalLabel.Text = string.format("💰 Cash: %s  |  💎 Gems: %s", formatNumber(money), formatNumber(gems))

            -- Update Egg Stock Status
            local eItems = s.eggShopItems or {}
            local eSold = s.eggShopSoldSlots or {}
            local eParts = {}
            for i = 1, 3 do
                local name = eItems[i] or "-"
                local st = eSold[i] and "Sold" or "Ready"
                table.insert(eParts, string.format("#%d: %s (%s)", i, name, st))
            end
            EggStatus.Text = table.concat(eParts, " | ")

            -- Update Box Stock Status
            local bItems = s.lootboxShopItems or {}
            local bSold = s.lootboxShopSoldSlots or {}
            local bParts = {}
            for i = 1, 3 do
                local name = bItems[i] or "-"
                local st = bSold[i] and "Sold" or "Ready"
                table.insert(bParts, string.format("#%d: %s (%s)", i, name, st))
            end
            BoxStatus.Text = table.concat(bParts, " | ")
        end)
        task.wait(1.5)
    end
end)

print("🌸 [SAKURA] Clean Automation loaded successfully!")
