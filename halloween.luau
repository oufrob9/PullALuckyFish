local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
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
local UI = nil

local function cleanShutdown()
    if not isRunning then return end
    isRunning = false
    _G.__HALLOWEEN_FARM = (_G.__HALLOWEEN_FARM or 0) + 1
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    if UI and UI.Destroy then
        pcall(function() UI:Destroy() end)
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
    CauldronStation = nil,
    CauldronZone = nil,
    ShopPedestals = nil
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
    if not Locations.ShopPedestals then
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenEventShopPedestals")) do
            local p = getPartCFrame(inst)
            if p then Locations.ShopPedestals = p + Vector3.new(0, 3, 5) break end
        end
    end
end

resolveLocations()

local Config = {
    AutoFish = true,
    AutoStir = true,
    AutoTeleport = false,
    AutoUpgrade = true,
    SelectedUpgrades = {
        Capacity = true,
        Machine = true,
        Luck = true,
        HeavierFish = true
    },
    AutoBuy = false,
    SelectedShopItems = {
        HalloweenEggA = false,
        HalloweenEggB = false,
        HalloweenBase = false,
        HalloweenMount = false,
        HalloweenRod = false
    },
    AntiAfk = true
}

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

local isStirring = false

local function autoStirCauldron()
    if not Config.AutoStir then
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

    if Config.AutoTeleport and Locations.CauldronStation then
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

local function autoFishEvent()
    if not Config.AutoFish then return end

    if Config.AutoTeleport and Locations.CauldronZone then
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

local function autoBuyUpgrades()
    if not Config.AutoUpgrade or not Remotes.HalloweenBuyUpgrade then return end
    local selected = Config.SelectedUpgrades or {}
    local data = getHalloweenData()
    local coins = data.coins
    local order = { "Capacity", "Machine", "Luck", "HeavierFish" }

    for _, upId in ipairs(order) do
        local isChosen = (selected[upId] == true)
        if isChosen then
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
end

local SHOP_ITEMS = {
    { Key = "HalloweenEggA", Price = 25000 },
    { Key = "HalloweenEggB", Price = 75000 },
    { Key = "HalloweenBase", Price = 1500000 },
    { Key = "HalloweenMount", Price = 4000000 },
    { Key = "HalloweenRod", Price = 15000000 }
}

local function autoBuyShop()
    if not Config.AutoBuy or not Remotes.BuyHalloweenShopItem then return end
    local selected = Config.SelectedShopItems or {}
    local data = getHalloweenData()
    local coins = data.coins

    for _, item in ipairs(SHOP_ITEMS) do
        local isChosen = (selected[item.Key] == true)
        if isChosen and coins >= item.Price then
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
                    local isChosen = (selected[item.Key] == true)
                    if isChosen and (act:find(item.Key:lower()) or obj:find(item.Key:lower())) then
                        triggerPrompt(desc)
                    end
                end
            end
        end
    end
end

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if Config.AntiAfk and VirtualUser then
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
        if Config.AutoStir then pcall(autoStirCauldron) end
        if Config.AutoFish then pcall(autoFishEvent) end
        if Config.AutoUpgrade then pcall(autoBuyUpgrades) end
        if Config.AutoBuy then pcall(autoBuyShop) end
        task.wait(0.25)
    end
end)

local bobloSource = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local okBoblo, BobloUI = pcall(function() return loadstring(game:HttpGet(bobloSource))() end)
if not okBoblo or not BobloUI then
    bobloSource = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"
    BobloUI = loadstring(game:HttpGet(bobloSource))()
end

UI = BobloUI:CreateWindow({
    Id = "pullaluckyfish-halloween",
    Title = "Pull A Lucky Fish — Halloween",
    Icon = "flame",
    Theme = "Dark",
    Accent = Color3.fromHex("#FF7700"),
    FooterText = "Halloween Event Hub",
    ConfigFolder = "LuckyFish_Halloween",
    AutoLoad = true
})

local MainTab = UI:AddTab({ Id = "main", Title = "Halloween Farm", Icon = "sparkles" })

local FishSection = MainTab:AddSection({ Title = "Auto Fish", Icon = "fish" })

FishSection:AddToggle({
    Id = "AutoFish",
    Title = "Auto Fish Event",
    Description = "Automatically cast and dive into the cauldron",
    Default = true,
    Callback = function(val) Config.AutoFish = val end
})

FishSection:AddToggle({
    Id = "AutoStir",
    Title = "Auto Stir Cauldron",
    Description = "Stir cauldron to raise float weight (max 617K kg)",
    Default = true,
    Callback = function(val) Config.AutoStir = val end
})

FishSection:AddToggle({
    Id = "AutoTeleport",
    Title = "Auto Teleport to Event",
    Description = "Position character at cauldron station / zone",
    Default = false,
    Callback = function(val) Config.AutoTeleport = val end
})

local UpgradeSection = MainTab:AddSection({ Title = "Auto Upgrade", Icon = "zap" })

UpgradeSection:AddToggle({
    Id = "AutoUpgrade",
    Title = "Enable Auto Upgrade",
    Description = "Automatically purchase chosen upgrades when affordable",
    Default = true,
    Callback = function(val) Config.AutoUpgrade = val end
})

UpgradeSection:AddDropdown({
    Id = "SelectedUpgrades",
    Title = "Choose Upgrades",
    Description = "Select which upgrades to auto-buy",
    Multi = true,
    Values = {
        Capacity = "Float Capacity",
        Machine = "Cauldron Tier (Machine)",
        Luck = "Cauldron Luck",
        HeavierFish = "Heavier Fish"
    },
    Default = {
        Capacity = true,
        Machine = true,
        Luck = true,
        HeavierFish = true
    },
    Callback = function(selected)
        if type(selected) == "table" then
            Config.SelectedUpgrades = selected
        end
    end
})

local ShopSection = MainTab:AddSection({ Title = "Auto Buy", Icon = "shopping-bag" })

ShopSection:AddToggle({
    Id = "AutoBuy",
    Title = "Enable Auto Buy",
    Description = "Automatically buy chosen shop items from pedestals",
    Default = false,
    Callback = function(val) Config.AutoBuy = val end
})

ShopSection:AddDropdown({
    Id = "SelectedShopItems",
    Title = "Choose Shop Items",
    Description = "Select which items to auto-buy from Halloween shop",
    Multi = true,
    Values = {
        HalloweenEggA = "Spooky Egg (25K)",
        HalloweenEggB = "Cursed Egg (75K)",
        HalloweenBase = "Halloween Base (1.5M)",
        HalloweenMount = "Witch's Broom (4M)",
        HalloweenRod = "Death Scythe (15M)"
    },
    Default = {
        HalloweenEggA = false,
        HalloweenEggB = false,
        HalloweenBase = false,
        HalloweenMount = false,
        HalloweenRod = false
    },
    Callback = function(selected)
        if type(selected) == "table" then
            Config.SelectedShopItems = selected
        end
    end
})

local SettingsSection = MainTab:AddSection({ Title = "Settings & Status", Icon = "shield" })

SettingsSection:AddToggle({
    Id = "AntiAfk",
    Title = "Anti-AFK",
    Description = "Prevents 20-minute idle disconnect",
    Default = true,
    Callback = function(val) Config.AntiAfk = val end
})

local CoinsStatus = SettingsSection:AddStatus({
    Id = "CoinsStatus",
    Title = "Halloween Coins",
    Value = "0"
})

local WeightStatus = SettingsSection:AddStatus({
    Id = "WeightStatus",
    Title = "Bobber Weight",
    Value = "0 / 617.2K"
})

local DivesStatus = SettingsSection:AddStatus({
    Id = "DivesStatus",
    Title = "Cauldron Stats",
    Value = "0 Dives | 0 Fish"
})

SettingsSection:AddButton({
    Title = "Teleport to Halloween Island",
    Callback = function()
        teleportTo(Locations.IslandArrival)
    end
})

SettingsSection:AddButton({
    Title = "Unload Script",
    Callback = function()
        cleanShutdown()
    end
})

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        pcall(function()
            local d = getHalloweenData()
            if CoinsStatus and CoinsStatus.SetValue then
                CoinsStatus:SetValue(formatKMB(d.coins))
            end
            if WeightStatus and WeightStatus.SetValue then
                WeightStatus:SetValue(string.format("%s / 617.2K", formatKMB(d.bobberWeight)))
            end
            if DivesStatus and DivesStatus.SetValue then
                DivesStatus:SetValue(string.format("%d Dives | %d Fish | %dm", d.casts, d.fish, d.maxDepth))
            end
        end)
        task.wait(1.5)
    end
end)
