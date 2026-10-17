local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
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
    pcall(function()
        if typeof(remoteObj) == "table" then
            if remoteObj.Fire then
                remoteObj:Fire(table.unpack(args, 1, args.n))
            elseif remoteObj.fire then
                remoteObj:fire(table.unpack(args, 1, args.n))
            elseif remoteObj.Call then
                local p = remoteObj:Call(table.unpack(args, 1, args.n))
                if typeof(p) == "table" and type(p.Await) == "function" then
                    p:Await()
                end
            end
        elseif typeof(remoteObj) == "Instance" then
            if remoteObj:IsA("RemoteEvent") then
                remoteObj:FireServer(table.unpack(args, 1, args.n))
            elseif remoteObj:IsA("RemoteFunction") then
                remoteObj:InvokeServer(table.unpack(args, 1, args.n))
            end
        end
    end)
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

local function getFishingZone()
    local tagged = CollectionService:GetTagged("CauldronFishingZone")
    for _, inst in ipairs(tagged) do
        if inst:IsA("BasePart") then return inst end
    end
    local wyspa = workspace:FindFirstChild("wyspa")
    local cd = wyspa and wyspa:FindFirstChild("CauldronDive")
    local zone = cd and cd:FindFirstChild("CauldronFishingZone")
    if zone and zone:IsA("BasePart") then return zone end
    return nil
end

local function getStirAnchor()
    local tagged = CollectionService:GetTagged("HalloweenStirCauldron")
    for _, inst in ipairs(tagged) do
        if inst:IsA("BasePart") then return inst end
        local p = inst:FindFirstChildWhichIsA("BasePart")
        if p then return p end
    end
    local wyspa = workspace:FindFirstChild("wyspa")
    local st = wyspa and wyspa:FindFirstChild("HalloweenStirStation")
    local anchor = st and (st:FindFirstChild("CauldronAnchor") or st:FindFirstChildWhichIsA("BasePart"))
    if anchor and anchor:IsA("BasePart") then return anchor end
    return nil
end

local function ensureOnIsland()
    local wyspa = workspace:FindFirstChild("wyspa")
    if not wyspa then
        if Remotes.HalloweenPortalUse then
            fireRemote(Remotes.HalloweenPortalUse)
        end
        for _, inst in ipairs(CollectionService:GetTagged("HalloweenPortal")) do
            local pr = inst:FindFirstChildWhichIsA("ProximityPrompt") or (inst:IsA("ProximityPrompt") and inst)
            if pr and pr.Enabled then triggerPrompt(pr) end
        end
        local t0 = os.clock()
        while not workspace:FindFirstChild("wyspa") and os.clock() - t0 < 6 and isRunning do
            task.wait(0.3)
        end
    end
end

local function ensureAtCauldron()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    ensureOnIsland()

    local zone = getFishingZone()
    if zone then
        local dist = (hrp.Position - zone.Position).Magnitude
        if dist > 25 then
            hrp.CFrame = zone.CFrame + Vector3.new(0, 3.5, 0)
            hrp.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.2)
        end
        return true
    end

    local wyspa = workspace:FindFirstChild("wyspa")
    if wyspa then
        local fallbackPos = Vector3.new(2410, 24, -380)
        local dist = (hrp.Position - fallbackPos).Magnitude
        if dist > 25 then
            hrp.CFrame = CFrame.lookAt(fallbackPos, Vector3.new(2402, 24, -470))
            hrp.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.2)
        end
        return true
    end
    return false
end

local function equipFishingRod()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end

    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool then
        local name = currentTool.Name
        if not (name:find("Potion") or name:find("Egg") or name:find("Dumbbell") or name:find("DNA") or name:find("Lootbox") or name:find("AutoCollect")) then
            return currentTool
        end
    end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:find("Rod") or tool.Name:find("Fish") or tool.Name:find("FISHROD")) then
                humanoid:EquipTool(tool)
                task.wait(0.12)
                return tool
            end
        end
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") and tool.Name == "Tool" then
                humanoid:EquipTool(tool)
                task.wait(0.12)
                return tool
            end
        end
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local name = tool.Name
                if not (name:find("Potion") or name:find("Egg") or name:find("Dumbbell") or name:find("DNA") or name:find("Lootbox") or name:find("AutoCollect")) then
                    humanoid:EquipTool(tool)
                    task.wait(0.12)
                    return tool
                end
            end
        end
    end
    return currentTool
end

local Config = {
    AutoFish = true,
    AutoStir = true,
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

local function isSelected(container, key)
    if not container or not key then return false end
    if type(container) == "table" then
        if container[key] == true then return true end
        for k, v in pairs(container) do
            if v == key or k == key then return true end
            if type(v) == "string" and v:lower() == key:lower() then return true end
            if type(k) == "string" and k:lower() == key:lower() and v == true then return true end
        end
    elseif type(container) == "string" then
        return container:lower() == key:lower()
    end
    return false
end

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
    local coins = tonumber(ev.coins)
    if not coins then
        for _, k in ipairs({"halloweenCoins", "candies", "eventCoins", "coins"}) do
            if s[k] and tonumber(s[k]) then coins = tonumber(s[k]) break end
        end
    end
    coins = coins or 0
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
        heavier = heavier,
        rawUpgrades = upgrades
    }
end

local isStirring = false

local function performStir()
    local data = getHalloweenData()
    if data.bobberWeight >= 617190 then
        if isStirring then
            isStirring = false
            if Remotes.HalloweenStirStop then fireRemote(Remotes.HalloweenStirStop) end
        end
        return false
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
    return true
end

local function performFish()
    ensureAtCauldron()
    local tool = equipFishingRod()
    if tool then
        pcall(function() tool:Activate() end)
    end

    if Remotes.FishingCastBegin then fireRemote(Remotes.FishingCastBegin) end
    if Remotes.FishingRemoteCast then fireRemote(Remotes.FishingRemoteCast) end
    if Remotes.FishingRemoteStage then fireRemote(Remotes.FishingRemoteStage, 1, true) end
    if Remotes.FishingStage then fireRemote(Remotes.FishingStage, 1, true) end

    if Remotes.CauldronDiveStart then fireRemote(Remotes.CauldronDiveStart) end
    if Remotes.CauldronDiveFinish then fireRemote(Remotes.CauldronDiveFinish) end

    if VirtualInputManager then
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
        end)
    end
    if VirtualUser then
        pcall(function()
            VirtualUser:Button1Down(Vector2.new(500, 500))
            task.wait(0.04)
            VirtualUser:Button1Up(Vector2.new(500, 500))
        end)
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

local function performUpgrade(upId)
    if Remotes.HalloweenBuyUpgrade then
        fireRemote(Remotes.HalloweenBuyUpgrade, upId)
    end
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local mainUI = pGui and pGui:FindFirstChild("MainUI")
    local eventUpgradesUI = mainUI and mainUI:FindFirstChild("EventUpgrades")
    if eventUpgradesUI then
        for _, desc in ipairs(eventUpgradesUI:GetDescendants()) do
            if desc:IsA("GuiButton") and desc.Name:lower():find(upId:lower()) then
                pcall(function()
                    if firesignal then firesignal(desc.MouseButton1Click) end
                end)
            end
        end
    end
end

local function performUpgradesPass(selected)
    local data = getHalloweenData()
    local coins = data.coins
    local order = { "Capacity", "Machine", "Luck", "HeavierFish" }

    for _, upId in ipairs(order) do
        if isSelected(selected, upId) then
            local info = UPGRADE_DATA[upId]
            if info then
                local currentStage = data[upId:lower()] or (data.rawUpgrades and tonumber(data.rawUpgrades[upId])) or 0
                if upId == "Machine" then currentStage = math.max(1, currentStage) - 1 end
                if currentStage < info.Max then
                    local nextCost = info.Costs[currentStage + 1]
                    if nextCost and coins >= nextCost then
                        performUpgrade(upId)
                        coins = coins - nextCost
                        task.wait(0.12)
                    end
                end
            end
        end
    end
end

local SHOP_ITEMS = {
    { Key = "HalloweenEggA", Name = "HalloweenEgg_Spooky", Pedestal = 3, Price = 25000 },
    { Key = "HalloweenEggB", Name = "HalloweenEgg_Cursed", Pedestal = 3, Price = 75000 },
    { Key = "HalloweenBase", Name = "BaseHalloween",        Pedestal = 4, Price = 1500000 },
    { Key = "HalloweenMount", Name = "MOUNT_WitchBroom",    Pedestal = 1, Price = 4000000 },
    { Key = "HalloweenRod", Name = "FISHROD_DeathScythe",   Pedestal = 2, Price = 15000000 }
}

local function performShopPass(selected)
    local data = getHalloweenData()
    local coins = data.coins

    for _, item in ipairs(SHOP_ITEMS) do
        if isSelected(selected, item.Key) and coins >= item.Price then
            if Remotes.BuyHalloweenShopItem then
                fireRemote(Remotes.BuyHalloweenShopItem, item.Key)
                fireRemote(Remotes.BuyHalloweenShopItem, item.Name)
                fireRemote(Remotes.BuyHalloweenShopItem, item.Pedestal)
            end
            task.wait(0.12)
        end
    end

    for _, inst in ipairs(CollectionService:GetTagged("HalloweenEventShopPedestals")) do
        for _, desc in ipairs(inst:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = desc.ActionText:lower()
                local obj = desc.ObjectText:lower()
                for _, item in ipairs(SHOP_ITEMS) do
                    if isSelected(selected, item.Key) and (act:find(item.Key:lower()) or obj:find(item.Key:lower())) then
                        triggerPrompt(desc)
                    end
                end
            end
        end
    end
end

local bobloSource = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.lua"
local okBoblo, BobloUI = pcall(function() return loadstring(game:HttpGet(bobloSource))() end)
if not okBoblo or not BobloUI then
    bobloSource = "https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"
    BobloUI = loadstring(game:HttpGet(bobloSource))()
end

UI = BobloUI:CreateWindow({
    Id = "luckyfish-halloween-hub",
    Title = "Pull A Lucky Fish — Halloween",
    Icon = "flame",
    Theme = "Dark",
    Accent = Color3.fromHex("#FF7700"),
    Settings = false
})

local MainTab = UI:AddTab({ Id = "main", Title = "Halloween Farm", Icon = "sparkles" })

local FishSection = MainTab:AddSection({ Title = "Auto Fish", Icon = "fish" })

local autoFishToggle = FishSection:AddToggle({
    Id = "AutoFish",
    Title = "Auto Fish Event",
    Description = "Teleports to cauldron, casts rod and dives for fish and candies",
    Default = true,
    Callback = function(val) Config.AutoFish = val end
})

local autoStirToggle = FishSection:AddToggle({
    Id = "AutoStir",
    Title = "Auto Stir Cauldron",
    Description = "Stir cauldron to raise float weight up to 617K kg max depth",
    Default = true,
    Callback = function(val) Config.AutoStir = val end
})

local UpgradeSection = MainTab:AddSection({ Title = "Auto Upgrade", Icon = "zap" })

local autoUpgradeToggle = UpgradeSection:AddToggle({
    Id = "AutoUpgrade",
    Title = "Enable Auto Upgrade",
    Description = "Automatically purchases chosen upgrades when coins allow",
    Default = true,
    Callback = function(val) Config.AutoUpgrade = val end
})

local upgradesDropdown = UpgradeSection:AddDropdown({
    Id = "SelectedUpgrades",
    Title = "Choose Upgrades",
    Description = "Select which upgrades to auto-purchase",
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

local autoBuyToggle = ShopSection:AddToggle({
    Id = "AutoBuy",
    Title = "Enable Auto Buy",
    Description = "Automatically purchases chosen items from Halloween shop",
    Default = false,
    Callback = function(val) Config.AutoBuy = val end
})

local shopDropdown = ShopSection:AddDropdown({
    Id = "SelectedShopItems",
    Title = "Choose Shop Items",
    Description = "Select which items to auto-purchase from shop pedestals",
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

local MiscSection = MainTab:AddSection({ Title = "Utilities", Icon = "shield" })

local antiAfkToggle = MiscSection:AddToggle({
    Id = "AntiAfk",
    Title = "Anti-AFK",
    Description = "Prevents 20-minute idle disconnect",
    Default = true,
    Callback = function(val) Config.AntiAfk = val end
})

local CoinsStatus = MiscSection:AddStatus({
    Id = "CoinsStatus",
    Title = "Halloween Coins",
    Value = "0"
})

local WeightStatus = MiscSection:AddStatus({
    Id = "WeightStatus",
    Title = "Bobber Weight",
    Value = "0 / 617.2K"
})

MiscSection:AddButton({
    Title = "Teleport to Halloween Cauldron",
    Callback = function()
        ensureAtCauldron()
    end
})

MiscSection:AddButton({
    Title = "Unload Script",
    Callback = function()
        cleanShutdown()
    end
})

local function isFeatureEnabled(toggleObj, defaultKey)
    if toggleObj and toggleObj.GetValue then
        local v = toggleObj:GetValue()
        if v ~= nil then return v == true end
    end
    return Config[defaultKey] == true
end

local function getActiveSelection(dropdownObj, defaultKey)
    if dropdownObj and dropdownObj.GetValue then
        local v = dropdownObj:GetValue()
        if v ~= nil then return v end
    end
    return Config[defaultKey]
end

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        if isFeatureEnabled(autoFishToggle, "AutoFish") then
            if isFeatureEnabled(autoStirToggle, "AutoStir") then
                pcall(performStir)
            end
            pcall(performFish)
        end
        task.wait(0.35)
    end
end)

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        if isFeatureEnabled(autoUpgradeToggle, "AutoUpgrade") then
            local sel = getActiveSelection(upgradesDropdown, "SelectedUpgrades")
            pcall(function() performUpgradesPass(sel) end)
        end
        task.wait(1.5)
    end
end)

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        if isFeatureEnabled(autoBuyToggle, "AutoBuy") then
            local sel = getActiveSelection(shopDropdown, "SelectedShopItems")
            pcall(function() performShopPass(sel) end)
        end
        task.wait(2.0)
    end
end)

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
        end)
        task.wait(1.5)
    end
end)

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if isFeatureEnabled(antiAfkToggle, "AntiAfk") and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
        end)
    end
end))

task.spawn(function()
    while isRunning and _G.__HALLOWEEN_FARM == CURRENT_SESSION do
        if isFeatureEnabled(antiAfkToggle, "AntiAfk") and VirtualUser then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.zero, workspace.CurrentCamera.CFrame)
                task.wait(0.2)
                VirtualUser:Button2Up(Vector2.zero, workspace.CurrentCamera.CFrame)
            end)
        end
        task.wait(45)
    end
end)
