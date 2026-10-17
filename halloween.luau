local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

_G.__HALLOWEEN_FARM = (_G.__HALLOWEEN_FARM or 0) + 1
local CURRENT_SESSION = _G.__HALLOWEEN_FARM

local isRunning = true
local connections = {}

local function cleanShutdown()
    if not isRunning then return end
    isRunning = false
    _G.__HALLOWEEN_FARM = (_G.__HALLOWEEN_FARM or 0) + 1
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
    local oldGui = targetParent and targetParent:FindFirstChild("HalloweenAutoFarm_UI")
    if oldGui then
        oldGui:Destroy()
    end
end

local Shared = ReplicatedStorage:WaitForChild("shared", 10)
local Client = ReplicatedStorage:WaitForChild("client", 10)
if not Shared or not Client then return end

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

local function triggerPrompt(prompt)
    if not prompt or not prompt.Enabled then return end
    if fireproximityprompt then
        pcall(function() fireproximityprompt(prompt) end)
    end
    pcall(function()
        prompt:InputHoldBegin()
        task.wait(prompt.HoldDuration or 0)
        prompt:InputHoldEnd()
    end)
end

local function getPartCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.CFrame end
    if inst:IsA("Attachment") then return inst.WorldCFrame end
    if inst:IsA("Model") then return inst:GetPivot() end
    if inst:IsA("ProximityPrompt") and inst.Parent then return getPartCFrame(inst.Parent) end
    return nil
end

local function teleportTo(cf)
    if not cf then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = typeof(cf) == "CFrame" and cf or CFrame.new(cf) + Vector3.new(0, 3, 0)
    end
end

local Locations = {
    IslandArrival = CFrame.new(2406.00, 20.25, -339.55),
    IslandCenter  = Vector3.new(2420.00, 0.00, -430.00),
    CauldronStation = nil,
    CauldronZone = nil,
    ShopPedestals = nil,
    RitualAltar = nil,
    UpgradesPad = nil
}

local function resolveLocations()
    local island = workspace:FindFirstChild("wyspa")
    if island then
        local stir = island:FindFirstChild("HalloweenStirStation")
        if stir and stir:FindFirstChild("CauldronAnchor") then
            Locations.CauldronStation = stir.CauldronAnchor.CFrame + Vector3.new(0, 3, 4)
        end
        local dive = island:FindFirstChild("CauldronDive")
        if dive and dive:FindFirstChild("CauldronFishingZone") then
            Locations.CauldronZone = dive.CauldronFishingZone.CFrame + Vector3.new(0, 4, 0)
        end
        local ritual = island:FindFirstChild("ritual")
        if ritual then
            Locations.RitualAltar = ritual:GetPivot() + Vector3.new(0, 3, 5)
        end
        local upgrades = island:FindFirstChild("HalloweenEventUpgrades")
        if upgrades then
            Locations.UpgradesPad = upgrades.CFrame + Vector3.new(0, 3, 0)
        end
    end
    local shop = workspace:FindFirstChild("Eventshop")
    if shop and shop:FindFirstChild("pedestals") then
        Locations.ShopPedestals = shop.pedestals:GetPivot() + Vector3.new(0, 3, 5)
    end

    if not Locations.CauldronStation then
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenStirCauldron")) do
            local p = getPartCFrame(inst)
            if p then Locations.CauldronStation = p + Vector3.new(0, 3, 4) break end
        end
    end
    if not Locations.CauldronZone then
        for _, inst in ipairs(CollectionService:GetTagged("CauldronFishingZone")) do
            local p = getPartCFrame(inst)
            if p then Locations.CauldronZone = p + Vector3.new(0, 4, 0) break end
        end
    end
    if not Locations.RitualAltar then
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenRitual")) do
            local p = getPartCFrame(inst)
            if p then Locations.RitualAltar = p + Vector3.new(0, 3, 5) break end
        end
    end
    if not Locations.ShopPedestals then
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenEventShopPedestals")) do
            local p = getPartCFrame(inst)
            if p then Locations.ShopPedestals = p + Vector3.new(0, 3, 5) break end
        end
    end
    if not Locations.UpgradesPad then
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenEventZoneUpgrades")) do
            local p = getPartCFrame(inst)
            if p then Locations.UpgradesPad = p + Vector3.new(0, 3, 0) break end
        end
    end
end

resolveLocations()

local Config = {
    AutoStirCauldron   = true,
    AutoCauldronDive   = true,
    AutoLockPosition   = false,
    AutoCollectCandies = true,
    AutoBuyUpgrades    = true,
    AutoBuySpookyEgg   = false,
    AutoBuyCursedEgg   = false,
    AutoBuyBroomMount  = false,
    AutoBuyDeathScythe = false,
    AutoBuyEventBase   = false,
    AutoHatchEventEggs = true,
    AutoRitualAltar    = true,
    AntiAfkEnabled     = true,
    CollectRadius      = 400
}

local CONFIG_FILE = "Halloween_Farm_Config.json"

local function saveSettings()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadSettings()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            if raw and #raw > 0 then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    for k, _ in pairs(Config) do
                        if data[k] ~= nil and type(Config[k]) == type(data[k]) then
                            Config[k] = data[k]
                        end
                    end
                end
            end
        end
    end)
end

loadSettings()

local function formatKMB(n)
    n = tonumber(n) or 0
    if n >= 1000000000 then return string.format("%.2fB", n / 1000000000) end
    if n >= 1000000 then return string.format("%.2fM", n / 1000000) end
    if n >= 1000 then return string.format("%.1fK", n / 1000) end
    return tostring(math.floor(n))
end

local function getHalloweenData()
    local s = getState()
    local ev = s.events and s.events.HalloweenEvent_2026_10 or {}
    local coins = tonumber(ev.coins) or 0
    local bobberWeight = tonumber(ev.bobberWeight) or 0
    local stats = ev.cauldronStats or {}
    local casts = tonumber(stats.casts) or 0
    local fish = tonumber(stats.fish) or 0
    local maxDepth = tonumber(stats.maxDepth) or 0
    local upgrades = ev.upgrades or {}
    local machine = tonumber(upgrades.Machine) or 1
    local capacity = tonumber(upgrades.Capacity) or 0
    local luck = tonumber(upgrades.Luck) or 0
    local heavier = tonumber(upgrades.HeavierFish) or 0

    return {
        coins = coins,
        bobberWeight = bobberWeight,
        casts = casts,
        fish = fish,
        maxDepth = maxDepth,
        machine = machine,
        capacity = capacity,
        luck = luck,
        heavier = heavier
    }
end

local collectedCount = 0

local function autoCollectEventDrops()
    if not Config.AutoCollectCandies then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local keywords = { "candy", "candies", "pumpkin", "spooky", "halloween", "cauldron", "treat", "drop", "ghost", "witch" }

    for _, desc in ipairs(workspace:GetDescendants()) do
        if not isRunning or not Config.AutoCollectCandies then break end
        local nameLower = desc.Name:lower()
        local matches = false
        for _, kw in ipairs(keywords) do
            if nameLower:find(kw) then
                matches = true
                break
            end
        end

        if matches then
            local pCFrame = getPartCFrame(desc)
            if pCFrame then
                local dist = (hrp.Position - pCFrame.Position).Magnitude
                if dist <= Config.CollectRadius then
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        triggerPrompt(desc)
                        collectedCount = collectedCount + 1
                        task.wait(0.06)
                    end
                    local prompt = desc:FindFirstChildWhichIsA("ProximityPrompt")
                    if prompt and prompt.Enabled then
                        triggerPrompt(prompt)
                        collectedCount = collectedCount + 1
                        task.wait(0.06)
                    end
                    local touch = desc:FindFirstChildWhichIsA("TouchTransmitter") or desc:FindFirstChild("TouchInterest")
                    if touch and desc:IsA("BasePart") then
                        if firetouchinterest then
                            pcall(function()
                                firetouchinterest(hrp, desc, 0)
                                task.wait(0.02)
                                firetouchinterest(hrp, desc, 1)
                                collectedCount = collectedCount + 1
                            end)
                        end
                    end
                    local click = desc:FindFirstChildWhichIsA("ClickDetector")
                    if click and fireclickdetector then
                        pcall(function()
                            fireclickdetector(click)
                            collectedCount = collectedCount + 1
                        end)
                        task.wait(0.04)
                    end
                end
            end
        end
    end
end

local isStirring = false

local function autoStirCauldron()
    if not Config.AutoStirCauldron then
        if isStirring then
            isStirring = false
            if Remotes.HalloweenStirStop then fireRemote(Remotes.HalloweenStirStop) end
        end
        return
    end

    local data = getHalloweenData()
    if data.bobberWeight >= 617190 then
        if isStirring then
            isStirring = false
            if Remotes.HalloweenStirStop then fireRemote(Remotes.HalloweenStirStop) end
        end
        return
    end

    if Config.AutoLockPosition and Locations.CauldronStation then
        teleportTo(Locations.CauldronStation)
    end

    if Remotes.HalloweenStirStart then
        fireRemote(Remotes.HalloweenStirStart)
        isStirring = true
    end

    for _, inst in ipairs(CollectionService:GetTagged("HalloweenStirCauldron")) do
        local prompt = inst:FindFirstChildWhichIsA("ProximityPrompt") or (inst:IsA("ProximityPrompt") and inst)
        if prompt and prompt.Enabled then
            triggerPrompt(prompt)
        end
    end
end

local function autoCauldronDive()
    if not Config.AutoCauldronDive then return end

    if Config.AutoLockPosition and Locations.CauldronZone then
        teleportTo(Locations.CauldronZone)
    end

    if Remotes.FishingCastBegin then fireRemote(Remotes.FishingCastBegin) end
    if Remotes.FishingRemoteCast then fireRemote(Remotes.FishingRemoteCast) end
    if Remotes.FishingRemoteStage then fireRemote(Remotes.FishingRemoteStage, 1, true) end
    if Remotes.FishingStage then fireRemote(Remotes.FishingStage, 1, true) end

    if Remotes.CauldronDiveStart then
        fireRemote(Remotes.CauldronDiveStart)
    end

    if Remotes.CauldronDiveFinish then
        fireRemote(Remotes.CauldronDiveFinish)
    end
end

local UPGRADE_DATA = {
    Capacity = {
        Costs = { 500, 3500, 7500, 25000, 200000, 1750000, 6000000 },
        Max = 7
    },
    Machine = {
        Costs = { 1500, 6000, 50000, 500000, 2000000 },
        Max = 5
    },
    Luck = {
        Costs = { 750, 5000, 20000, 60000, 600000, 3500000 },
        Max = 6
    },
    HeavierFish = {
        Costs = { 1000, 9000, 55000, 750000, 4500000 },
        Max = 5
    }
}

local function autoBuyHalloweenUpgrades()
    if not Config.AutoBuyUpgrades or not Remotes.HalloweenBuyUpgrade then return end
    local data = getHalloweenData()
    local coins = data.coins
    local order = { "Capacity", "Machine", "Luck", "HeavierFish" }

    for _, upId in ipairs(order) do
        local info = UPGRADE_DATA[upId]
        if info then
            local currentStage = data[upId:lower()] or (upId == "Machine" and data.machine or 0)
            if upId == "Machine" then currentStage = math.max(1, currentStage) - 1 end
            if currentStage < info.Max then
                local nextCost = info.Costs[currentStage + 1]
                if nextCost and coins >= nextCost then
                    fireRemote(Remotes.HalloweenBuyUpgrade, upId)
                    coins = coins - nextCost
                    task.wait(0.1)
                end
            end
        end
    end
end

local SHOP_ITEMS = {
    { Key = "HalloweenEggA", ConfigKey = "AutoBuySpookyEgg",   Price = 25000,   OneTime = false },
    { Key = "HalloweenEggB", ConfigKey = "AutoBuyCursedEgg",   Price = 75000,   OneTime = false },
    { Key = "HalloweenBase", ConfigKey = "AutoBuyEventBase",   Price = 1500000, OneTime = true  },
    { Key = "HalloweenMount",ConfigKey = "AutoBuyBroomMount",  Price = 4000000, OneTime = true  },
    { Key = "HalloweenRod",  ConfigKey = "AutoBuyDeathScythe", Price = 15000000,OneTime = true }
}

local function autoBuyHalloweenShop()
    if not Remotes.BuyHalloweenShopItem then return end
    local data = getHalloweenData()
    local coins = data.coins

    for _, item in ipairs(SHOP_ITEMS) do
        if Config[item.ConfigKey] and coins >= item.Price then
            fireRemote(Remotes.BuyHalloweenShopItem, item.Key)
            task.wait(0.1)
        end
    end

    for _, inst in ipairs(CollectionService:GetTagged("HalloweenEventShopPedestals")) do
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = desc.ActionText:lower()
                local obj = desc.ObjectText:lower()
                for _, item in ipairs(SHOP_ITEMS) do
                    if Config[item.ConfigKey] and (act:find(item.Key:lower()) or obj:find(item.Key:lower())) then
                        triggerPrompt(desc)
                    end
                end
            end
        end
    end
end

local function autoPerformRitual()
    if not Config.AutoRitualAltar then return end

    for _, inst in ipairs(CollectionService:GetTagged("HalloweenRitual")) do
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = desc.ActionText:lower()
                if act:find("place") or act:find("start") or act:find("ritual") then
                    triggerPrompt(desc)
                    task.wait(0.1)
                end
            end
        end
    end

    local wyspa = workspace:FindFirstChild("wyspa")
    local ritual = wyspa and wyspa:FindFirstChild("ritual")
    if ritual then
        for _, desc in ipairs(ritual:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = desc.ActionText:lower()
                if act:find("place") or act:find("start") or act:find("ritual") then
                    triggerPrompt(desc)
                    task.wait(0.1)
                end
            end
        end
    end
end

local function autoHatchHalloweenItems()
    if not Config.AutoHatchEventEggs then return end
    local s = getState()

    local placedEggs = s.placedEggs or {}
    for eggId, data in pairs(placedEggs) do
        local ready = (type(data) == "table" and (data.Ready == true or data.ready == true))
        local remSec = type(data) == "table" and (data.RemainingSeconds or data.remainingSeconds or data.Timer or data.timer)
        if remSec and tonumber(remSec) and tonumber(remSec) <= 0 then ready = true end
        if ready then
            if Remotes.HatchEgg then
                fireRemote(Remotes.HatchEgg, eggId)
                fireRemote(Remotes.HatchEgg, tostring(eggId))
            end
        end
    end

    local placedBoxes = s.placedLootboxes or {}
    for boxId, data in pairs(placedBoxes) do
        local ready = (type(data) == "table" and (data.Ready == true or data.ready == true))
        local remSec = type(data) == "table" and (data.RemainingSeconds or data.remainingSeconds or data.Timer or data.timer)
        if remSec and tonumber(remSec) and tonumber(remSec) <= 0 then ready = true end
        if ready then
            if Remotes.OpenFloatLootbox then
                fireRemote(Remotes.OpenFloatLootbox, boxId)
                fireRemote(Remotes.OpenFloatLootbox, tostring(boxId))
            end
            if Remotes.ClaimFloatLootboxReward then
                fireRemote(Remotes.ClaimFloatLootboxReward, boxId)
            end
        end
    end

    local inv = s.inventory or {}
    local candidates = {}
    for key, item in pairs(inv) do
        if type(item) == "table" then
            local name = item.ConfigName or tostring(key)
            local count = tonumber(item.Stack) or 1
            if count > 0 then
                local low = name:lower()
                if low:find("halloween") or low:find("spooky") or low:find("cursed") or low:find("pumpkin") then
                    table.insert(candidates, name)
                end
            end
        end
    end

    local placedTotal = 0
    for _ in pairs(placedEggs) do placedTotal = placedTotal + 1 end
    for _ in pairs(placedBoxes) do placedTotal = placedTotal + 1 end

    local maxLimit = 3
    pcall(function()
        local PLC = Shared:FindFirstChild("config") and Shared.config:FindFirstChild("PlacementLimitConfig")
        local mod = PLC and require(PLC)
        if mod and mod.GetLimit then maxLimit = mod.GetLimit(s.placementLimitLevel or 0) end
    end)

    if placedTotal < maxLimit and #candidates > 0 then
        local chosen = candidates[1]
        local isEgg = chosen:lower():find("egg")
        if isEgg and Remotes.PlaceEgg then
            fireRemote(Remotes.PlaceEgg, chosen, placedTotal + 1)
            fireRemote(Remotes.PlaceEgg, placedTotal + 1, chosen)
            fireRemote(Remotes.PlaceEgg, chosen)
        elseif Remotes.PlaceFloatLootbox then
            fireRemote(Remotes.PlaceFloatLootbox, chosen, placedTotal + 1)
            fireRemote(Remotes.PlaceFloatLootbox, placedTotal + 1, chosen)
            fireRemote(Remotes.PlaceFloatLootbox, chosen)
        end
    end
end

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if Config.AntiAfkEnabled and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end))

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        if Config.AutoCollectCandies then pcall(autoCollectEventDrops) end
        if Config.AutoStirCauldron then pcall(autoStirCauldron) end
        if Config.AutoCauldronDive then pcall(autoCauldronDive) end
        if Config.AutoBuyUpgrades then pcall(autoBuyHalloweenUpgrades) end
        pcall(autoBuyHalloweenShop)
        if Config.AutoRitualAltar then pcall(autoPerformRitual) end
        if Config.AutoHatchEventEggs then pcall(autoHatchHalloweenItems) end
        task.wait(0.25)
    end
end)

local Theme = {
    Background = Color3.fromRGB(15, 11, 18),
    Sidebar    = Color3.fromRGB(22, 15, 26),
    Card       = Color3.fromRGB(26, 18, 30),
    CardSub    = Color3.fromRGB(38, 25, 42),
    CardActive = Color3.fromRGB(56, 32, 60),
    Orange     = Color3.fromRGB(255, 130, 45),
    OrangeSoft = Color3.fromRGB(255, 175, 110),
    Purple     = Color3.fromRGB(185, 95, 255),
    PurpleSoft = Color3.fromRGB(215, 155, 255),
    Text       = Color3.fromRGB(255, 245, 248),
    TextDim    = Color3.fromRGB(195, 165, 185),
    Green      = Color3.fromRGB(115, 230, 155),
    Red        = Color3.fromRGB(255, 95, 115),
    Stroke     = Color3.fromRGB(255, 130, 45),
    StrokeSub  = Color3.fromRGB(65, 38, 55)
}

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HalloweenAutoFarm_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

table.insert(connections, ScreenGui.Destroying:Connect(cleanShutdown))

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 480, 0, 540)
MainFrame.Position = UDim2.new(0.5, -240, 0.5, -270)
MainFrame.BackgroundColor3 = Theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Stroke
MainStroke.Thickness = 1.2
MainStroke.Transparency = 0.3
MainStroke.Parent = MainFrame

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Theme.Sidebar
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 12)
HeaderCorner.Parent = Header

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -120, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "🎃 HALLOWEEN TURBO FARM"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextColor3 = Theme.Orange
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local StatusBadge = Instance.new("TextLabel")
StatusBadge.Size = UDim2.new(0, 50, 0, 20)
StatusBadge.Position = UDim2.new(1, -100, 0.5, -10)
StatusBadge.BackgroundColor3 = Theme.CardSub
StatusBadge.Text = "V2.0"
StatusBadge.Font = Enum.Font.GothamBold
StatusBadge.TextSize = 10
StatusBadge.TextColor3 = Theme.Green
StatusBadge.Parent = Header

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 6)
BadgeCorner.Parent = StatusBadge

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -38, 0.5, -14)
CloseBtn.BackgroundColor3 = Theme.CardSub
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.TextColor3 = Theme.TextDim
CloseBtn.AutoButtonColor = false
CloseBtn.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -70, 0.5, -14)
MinBtn.BackgroundColor3 = Theme.CardSub
MinBtn.Text = "–"
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 13
MinBtn.TextColor3 = Theme.TextDim
MinBtn.AutoButtonColor = false
MinBtn.Parent = Header

local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetHeight = isMinimized and 44 or 540
    TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 480, 0, targetHeight)
    }):Play()
end)

local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
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

Header.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local FloatingToggle = Instance.new("TextButton")
FloatingToggle.Name = "FloatingToggle"
FloatingToggle.Size = UDim2.new(0, 42, 0, 42)
FloatingToggle.Position = UDim2.new(0, 16, 0.5, -21)
FloatingToggle.BackgroundColor3 = Theme.Sidebar
FloatingToggle.Text = "🎃"
FloatingToggle.TextSize = 20
FloatingToggle.Parent = ScreenGui

local FTC = Instance.new("UICorner")
FTC.CornerRadius = UDim.new(1, 0)
FTC.Parent = FloatingToggle

local FTS = Instance.new("UIStroke")
FTS.Color = Theme.Orange
FTS.Thickness = 1.2
FTS.Parent = FloatingToggle

FloatingToggle.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -44)
Content.Position = UDim2.new(0, 0, 0, 44)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local Dashboard = Instance.new("Frame")
Dashboard.Size = UDim2.new(1, -24, 0, 84)
Dashboard.Position = UDim2.new(0, 12, 0, 10)
Dashboard.BackgroundColor3 = Theme.Card
Dashboard.Parent = Content

local DashCorner = Instance.new("UICorner")
DashCorner.CornerRadius = UDim.new(0, 8)
DashCorner.Parent = Dashboard

local DashStroke = Instance.new("UIStroke")
DashStroke.Color = Theme.StrokeSub
DashStroke.Thickness = 0.8
DashStroke.Parent = Dashboard

local CandyLiveLabel = Instance.new("TextLabel")
CandyLiveLabel.Size = UDim2.new(0.5, -14, 0, 22)
CandyLiveLabel.Position = UDim2.new(0, 10, 0, 8)
CandyLiveLabel.BackgroundTransparency = 1
CandyLiveLabel.Text = "🍬 Coins: 0"
CandyLiveLabel.Font = Enum.Font.GothamBold
CandyLiveLabel.TextSize = 12
CandyLiveLabel.TextColor3 = Theme.OrangeSoft
CandyLiveLabel.TextXAlignment = Enum.TextXAlignment.Left
CandyLiveLabel.Parent = Dashboard

local WeightLiveLabel = Instance.new("TextLabel")
WeightLiveLabel.Size = UDim2.new(0.5, -14, 0, 22)
WeightLiveLabel.Position = UDim2.new(0.5, 4, 0, 8)
WeightLiveLabel.BackgroundTransparency = 1
WeightLiveLabel.Text = "⚖️ Weight: 0 / 617.2K"
WeightLiveLabel.Font = Enum.Font.GothamBold
WeightLiveLabel.TextSize = 12
WeightLiveLabel.TextColor3 = Theme.PurpleSoft
WeightLiveLabel.TextXAlignment = Enum.TextXAlignment.Right
WeightLiveLabel.Parent = Dashboard

local WeightBarBg = Instance.new("Frame")
WeightBarBg.Size = UDim2.new(1, -20, 0, 6)
WeightBarBg.Position = UDim2.new(0, 10, 0, 32)
WeightBarBg.BackgroundColor3 = Theme.CardSub
WeightBarBg.BorderSizePixel = 0
WeightBarBg.Parent = Dashboard

local WBgCorner = Instance.new("UICorner")
WBgCorner.CornerRadius = UDim.new(1, 0)
WBgCorner.Parent = WeightBarBg

local WeightBarFill = Instance.new("Frame")
WeightBarFill.Size = UDim2.new(0, 0, 1, 0)
WeightBarFill.BackgroundColor3 = Theme.Orange
WeightBarFill.BorderSizePixel = 0
WeightBarFill.Parent = WeightBarBg

local WFillCorner = Instance.new("UICorner")
WFillCorner.CornerRadius = UDim.new(1, 0)
WFillCorner.Parent = WeightBarFill

local DiveStatsLabel = Instance.new("TextLabel")
DiveStatsLabel.Size = UDim2.new(1, -20, 0, 18)
DiveStatsLabel.Position = UDim2.new(0, 10, 0, 42)
DiveStatsLabel.BackgroundTransparency = 1
DiveStatsLabel.Text = "🎣 Dives: 0  |  Fish: 0  |  Max Depth: 0m"
DiveStatsLabel.Font = Enum.Font.Gotham
DiveStatsLabel.TextSize = 10
DiveStatsLabel.TextColor3 = Theme.TextDim
DiveStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
DiveStatsLabel.Parent = Dashboard

local UpgradesStatusLabel = Instance.new("TextLabel")
UpgradesStatusLabel.Size = UDim2.new(1, -20, 0, 18)
UpgradesStatusLabel.Position = UDim2.new(0, 10, 0, 60)
UpgradesStatusLabel.BackgroundTransparency = 1
UpgradesStatusLabel.Text = "⚡ Cauldron: T1  |  Capacity: 0  |  Luck: 0  |  Fat: 0"
UpgradesStatusLabel.Font = Enum.Font.Gotham
UpgradesStatusLabel.TextSize = 10
UpgradesStatusLabel.TextColor3 = Theme.Green
UpgradesStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
UpgradesStatusLabel.Parent = Dashboard

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -24, 0, 30)
TabContainer.Position = UDim2.new(0, 12, 0, 100)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Content

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = TabContainer

local PageScroll = Instance.new("ScrollingFrame")
PageScroll.Size = UDim2.new(1, -24, 1, -142)
PageScroll.Position = UDim2.new(0, 12, 0, 136)
PageScroll.BackgroundTransparency = 1
PageScroll.BorderSizePixel = 0
PageScroll.ScrollBarThickness = 3
PageScroll.ScrollBarImageColor3 = Theme.Orange
PageScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PageScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PageScroll.Parent = Content

local pageLayout = Instance.new("UIListLayout")
pageLayout.Padding = UDim.new(0, 10)
pageLayout.Parent = PageScroll

local pages = {}
local tabButtons = {}

local function showTab(tabName)
    for name, page in pairs(pages) do
        page.Visible = (name == tabName)
    end
    for name, btn in pairs(tabButtons) do
        local active = (name == tabName)
        btn.BackgroundColor3 = active and Theme.CardActive or Theme.Card
        btn.TextColor3 = active and Theme.Orange or Theme.TextDim
    end
end

local function makeTabBtn(name, icon, width)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, width, 1, 0)
    btn.BackgroundColor3 = Theme.Card
    btn.Text = icon .. " " .. name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = TabContainer

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Theme.StrokeSub
    bStroke.Thickness = 0.8
    bStroke.Parent = btn

    btn.MouseButton1Click:Connect(function()
        showTab(name)
    end)
    tabButtons[name] = btn

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 0, 0)
    page.AutomaticSize = Enum.AutomaticSize.Y
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = PageScroll

    local pLayout = Instance.new("UIListLayout")
    pLayout.Padding = UDim.new(0, 8)
    pLayout.Parent = page

    pages[name] = page
    return page
end

local FarmPage     = makeTabBtn("Auto Farm", "⚡", 104)
local UpgradePage  = makeTabBtn("Shop & Tier", "🛒", 110)
local RitualPage   = makeTabBtn("Ritual & Eggs", "🔮", 116)
local TeleportPage = makeTabBtn("Teleports", "🚀", 104)

local function makeCard(parent, title)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 0)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = Theme.Card
    card.Parent = parent

    local cCorner = Instance.new("UICorner")
    cCorner.CornerRadius = UDim.new(0, 8)
    cCorner.Parent = card

    local cStroke = Instance.new("UIStroke")
    cStroke.Color = Theme.StrokeSub
    cStroke.Thickness = 0.8
    cStroke.Parent = card

    local cLayout = Instance.new("UIListLayout")
    cLayout.Padding = UDim.new(0, 6)
    cLayout.Parent = card

    local cPad = Instance.new("UIPadding")
    cPad.PaddingTop = UDim.new(0, 8)
    cPad.PaddingBottom = UDim.new(0, 8)
    cPad.PaddingLeft = UDim.new(0, 10)
    cPad.PaddingRight = UDim.new(0, 10)
    cPad.Parent = card

    if title then
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.BackgroundTransparency = 1
        lbl.Text = title
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextColor3 = Theme.OrangeSoft
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = card
    end
    return card
end

local function makeToggle(card, title, configKey)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = card

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = title
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = Theme.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local defaultVal = Config[configKey] or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 38, 0, 20)
    btn.Position = UDim2.new(1, -38, 0.5, -10)
    btn.BackgroundColor3 = defaultVal and Theme.Orange or Theme.CardSub
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = row

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(1, 0)
    bCorner.Parent = btn

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultVal and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = btn

    local kCorner = Instance.new("UICorner")
    kCorner.CornerRadius = UDim.new(1, 0)
    kCorner.Parent = knob

    local val = defaultVal
    btn.MouseButton1Click:Connect(function()
        val = not val
        Config[configKey] = val
        saveSettings()
        local targetColor = val and Theme.Orange or Theme.CardSub
        local targetPos = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = targetColor }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
    end)
    return row
end

local function makeButton(card, text, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Theme.CardSub
    btn.Text = text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.Text
    btn.AutoButtonColor = false
    btn.Parent = card

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 6)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Theme.Orange
    bStroke.Thickness = 0.8
    bStroke.Transparency = 0.6
    bStroke.Parent = btn

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.CardActive }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.15), { Transparency = 0.2 }):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.CardSub }):Play()
        TweenService:Create(bStroke, TweenInfo.new(0.15), { Transparency = 0.6 }):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Orange }):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.CardActive }):Play()
        onClick()
    end)
    return btn
end

local FarmCard1 = makeCard(FarmPage, "1. Cauldron Stirring & Float Weight")
makeToggle(FarmCard1, "Auto Stir Cauldron (Speed Float Weight)", "AutoStirCauldron")
makeToggle(FarmCard1, "Auto Lock Position at Active Spot", "AutoLockPosition")
makeButton(FarmCard1, "⚡ Force Stir Cauldron Now", function()
    autoStirCauldron()
end)

local FarmCard2 = makeCard(FarmPage, "2. Cauldron Dive & Fishing")
makeToggle(FarmCard2, "Auto Cauldron Dive (Fish The Pot)", "AutoCauldronDive")
makeButton(FarmCard2, "⚡ Force Cauldron Dive Once", function()
    autoCauldronDive()
end)

local FarmCard3 = makeCard(FarmPage, "3. Collectibles & Candies")
makeToggle(FarmCard3, "Auto Collect Candies & Pumpkins (Full Map)", "AutoCollectCandies")
makeButton(FarmCard3, "⚡ Force Collect Visible Candies", function()
    autoCollectEventDrops()
end)

local UpgradeCard1 = makeCard(UpgradePage, "1. Event Upgrades (Auto Buy)")
makeToggle(UpgradeCard1, "Auto Buy All Halloween Upgrades", "AutoBuyUpgrades")
makeButton(UpgradeCard1, "⚡ Buy Next Available Upgrades Now", function()
    autoBuyHalloweenUpgrades()
end)

local UpgradeCard2 = makeCard(UpgradePage, "2. Halloween Event Shop Pedestals")
makeToggle(UpgradeCard2, "Auto Buy Spooky Egg (25k Coins)", "AutoBuySpookyEgg")
makeToggle(UpgradeCard2, "Auto Buy Cursed Egg (75k Coins)", "AutoBuyCursedEgg")
makeToggle(UpgradeCard2, "Auto Buy Witch Broom Mount (4M Coins)", "AutoBuyBroomMount")
makeToggle(UpgradeCard2, "Auto Buy Death Scythe Rod (15M Coins)", "AutoBuyDeathScythe")
makeToggle(UpgradeCard2, "Auto Buy Halloween Base (1.5M Coins)", "AutoBuyEventBase")
makeButton(UpgradeCard2, "⚡ Purchase Enabled Shop Items Now", function()
    autoBuyHalloweenShop()
end)

local RitualCard1 = makeCard(RitualPage, "1. Halloween Ritual (Corrupted El Maja)")
makeToggle(RitualCard1, "Auto Corrupted Ritual Altar (3x 100%+ Fish)", "AutoRitualAltar")
makeButton(RitualCard1, "⚡ Trigger Ritual Altar Now", function()
    autoPerformRitual()
end)

local RitualCard2 = makeCard(RitualPage, "2. Halloween Eggs & Crates")
makeToggle(RitualCard2, "Auto Place & Hatch Event Eggs & Crates", "AutoHatchEventEggs")
makeButton(RitualCard2, "⚡ Force Place & Hatch Available Eggs", function()
    autoHatchHalloweenItems()
end)

local TpCard1 = makeCard(TeleportPage, "1. Halloween Island Teleports")
makeButton(TpCard1, "🏝️ Teleport to Halloween Island (Arrival)", function()
    teleportTo(Locations.IslandArrival)
end)
makeButton(TpCard1, "🍲 Teleport to Stir Cauldron Station", function()
    resolveLocations()
    teleportTo(Locations.CauldronStation or Locations.IslandArrival)
end)
makeButton(TpCard1, "🎣 Teleport to Cauldron Fishing Pier", function()
    resolveLocations()
    teleportTo(Locations.CauldronZone or Locations.IslandArrival)
end)
makeButton(TpCard1, "🛍️ Teleport to Halloween Event Shop", function()
    resolveLocations()
    teleportTo(Locations.ShopPedestals or Locations.IslandArrival)
end)
makeButton(TpCard1, "🔮 Teleport to Ritual Altar", function()
    resolveLocations()
    teleportTo(Locations.RitualAltar or Locations.IslandArrival)
end)

local TpCard2 = makeCard(TeleportPage, "2. Controls & Utilities")
makeToggle(TpCard2, "Anti-AFK Protection (Prevent Disconnect)", "AntiAfkEnabled")
makeButton(TpCard2, "🛑 Unload Halloween Script Cleanly", function()
    cleanShutdown()
end)

showTab("Auto Farm")

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        pcall(function()
            local d = getHalloweenData()
            CandyLiveLabel.Text = string.format("🍬 Coins: %s", formatKMB(d.coins))
            WeightLiveLabel.Text = string.format("⚖️ Weight: %s / 617.2K", formatKMB(d.bobberWeight))
            local pct = math.clamp(d.bobberWeight / 617190, 0, 1)
            WeightBarFill.Size = UDim2.new(pct, 0, 1, 0)
            DiveStatsLabel.Text = string.format("🎣 Dives: %d  |  Fish: %d  |  Max Depth: %dm", d.casts, d.fish, d.maxDepth)
            UpgradesStatusLabel.Text = string.format("⚡ Cauldron: T%d  |  Cap: %d  |  Luck: %d  |  Fat: %d", d.machine, d.capacity, d.luck, d.heavier)
        end)
        task.wait(1.5)
    end
end)
