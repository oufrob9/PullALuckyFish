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

_G.__SAKURA_MAIN = (_G.__SAKURA_MAIN or 0) + 1
local CURRENT_SESSION = _G.__SAKURA_MAIN

local isRunning = true
local connections = {}

local function cleanShutdown()
    if not isRunning then return end
    isRunning = false
    _G.__SAKURA_MAIN = (_G.__SAKURA_MAIN or 0) + 1
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
    local oldGui = targetParent and targetParent:FindFirstChild("SakuraLuckyFish_Main")
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

local Config = {
    AutoCollectCash = false,
    AutoBuyEggs = false,
    AutoBuyBoxes = false,
    AutoBuyAuctionHouse = false,
    AutoPlace = false,
    AutoOpen = false,
    AntiAFK = false,
    OpenPriority = "HighTierFirst"
}

local CONFIG_FILE = "PullALuckyFish_Config.json"

local function saveSettings()
    pcall(function()
        if writefile then
            local payload = {
                AutoCollectCash = Config.AutoCollectCash,
                AutoBuyEggs = Config.AutoBuyEggs,
                AutoBuyBoxes = Config.AutoBuyBoxes,
                AutoBuyAuctionHouse = Config.AutoBuyAuctionHouse,
                AutoPlace = Config.AutoPlace,
                AutoOpen = Config.AutoOpen,
                AntiAFK = Config.AntiAFK,
                OpenPriority = Config.OpenPriority
            }
            writefile(CONFIG_FILE, HttpService:JSONEncode(payload))
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

local function getPartCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then
        return inst.CFrame
    elseif inst:IsA("Attachment") then
        return inst.WorldCFrame
    elseif inst:IsA("Model") then
        return inst:GetPivot()
    elseif inst:IsA("ProximityPrompt") and inst.Parent then
        return getPartCFrame(inst.Parent)
    end
    return nil
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

local function getMaxPlacementLimit()
    local limit = 3
    pcall(function()
        local PLC = Shared:FindFirstChild("config") and Shared.config:FindFirstChild("PlacementLimitConfig")
        local mod = PLC and require(PLC)
        if mod and mod.GetLimit then
            local s = getState()
            limit = mod.GetLimit(s.placementLimitLevel or 0)
        elseif mod and mod.BaseLimit then
            limit = mod.BaseLimit + (getState().placementLimitLevel or 0)
        end
    end)
    return limit or 3
end

local function getPlacedItemCount()
    local s = getState()
    local placedEggs = s.placedEggs or {}
    local placedBoxes = s.placedLootboxes or {}
    local count = 0
    for _ in pairs(placedEggs) do count = count + 1 end
    for _ in pairs(placedBoxes) do count = count + 1 end
    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            local guiCount = 0
            for _, g in ipairs(pg:GetChildren()) do
                if g:IsA("BillboardGui") and (g.Name:find("LootboxTimer_") or g.Name:find("EggTimer_")) then
                    guiCount = guiCount + 1
                end
            end
            if guiCount > count then count = guiCount end
        end
    end)
    return count
end

local function hasSpaceToPlace()
    local currentCount = getPlacedItemCount()
    local maxLimit = getMaxPlacementLimit()
    return currentCount < maxLimit, currentCount, maxLimit
end

local function findPlayerBase()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local pbi = pg:FindFirstChild("PlayerBaseIndicator", true)
        if pbi and pbi:IsA("BillboardGui") and pbi.Adornee then
            local ad = pbi.Adornee
            return ad:IsA("Model") and ad or ad.Parent
        end
        local hi = pg:FindFirstChild("HomeIndicator", true)
        if hi and hi:IsA("BillboardGui") and hi.Adornee then
            local ad = hi.Adornee
            return ad:IsA("Model") and ad or ad.Parent
        end
    end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("Folder") then
            if obj.Name:find(LocalPlayer.Name) or obj.Name:find(tostring(LocalPlayer.UserId)) then
                return obj
            end
            local owner = obj:FindFirstChild("Owner") or obj:FindFirstChild("Player")
            if owner and (owner.Value == LocalPlayer or owner.Value == LocalPlayer.Name or tostring(owner.Value) == tostring(LocalPlayer.UserId)) then
                return obj
            end
        end
    end
    return nil
end

local function getBaseCFrame()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local pbi = pg:FindFirstChild("PlayerBaseIndicator", true)
        if pbi and pbi:IsA("BillboardGui") and pbi.Adornee then
            local cf = getPartCFrame(pbi.Adornee)
            if cf then return cf end
        end
        local hi = pg:FindFirstChild("HomeIndicator", true)
        if hi and hi:IsA("BillboardGui") and hi.Adornee then
            local cf = getPartCFrame(hi.Adornee)
            if cf then return cf end
        end
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("BillboardGui") and (g.Name:find("LootboxTimer_") or g.Name:find("EggTimer_")) and g.Adornee then
                local cf = getPartCFrame(g.Adornee)
                if cf then return cf end
            end
        end
    end
    local base = findPlayerBase()
    if base then
        return getPartCFrame(base)
    end
    return nil
end

local function getAuctionHouseCFrame()
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local dot = pg:FindFirstChild("IndicatorDotBgui_AuctionHousePart", true)
        if dot and dot:IsA("BillboardGui") and dot.Adornee then
            local cf = getPartCFrame(dot.Adornee)
            if cf then return cf, dot.Adornee end
        end
    end
    for _, tagged in ipairs(CollectionService:GetTagged("AuctionHouse")) do
        local cf = getPartCFrame(tagged)
        if cf then return cf, tagged end
        if tagged:IsA("ProximityPrompt") and tagged.Parent then
            local pcf = getPartCFrame(tagged.Parent)
            if pcf then return pcf, tagged.Parent end
        end
    end
    local part = workspace:FindFirstChild("AuctionHousePart", true)
    if part then
        local cf = getPartCFrame(part)
        if cf then return cf, part end
    end
    local configCf = nil
    pcall(function()
        local AHC = Shared:FindFirstChild("config") and Shared.config:FindFirstChild("AuctionHouseConfig")
        local mod = AHC and require(AHC)
        if mod and mod.Guide and mod.Guide.Position then
            configCf = CFrame.new(mod.Guide.Position)
        end
    end)
    if configCf then return configCf, nil end
    return nil, nil
end

local function getFreeBaseSlot()
    local s = getState()
    local occupied = {}
    for _, d in pairs(s.placedEggs or {}) do
        if type(d) == "table" then
            local sl = d.Slot or d.slot or d.Index or d.index or d.Stand or d.stand
            if sl and tonumber(sl) then occupied[tonumber(sl)] = true end
        end
    end
    for _, d in pairs(s.placedLootboxes or {}) do
        if type(d) == "table" then
            local sl = d.Slot or d.slot or d.Index or d.index or d.Stand or d.stand
            if sl and tonumber(sl) then occupied[tonumber(sl)] = true end
        end
    end
    local maxLimit = getMaxPlacementLimit()
    for i = 1, maxLimit do
        if not occupied[i] then
            return i
        end
    end
    return 1
end

local function parseTimerText(text)
    if not text or text == "" then return nil end
    local low = string.lower(text)
    if low:find("open") or low:find("ready") or low:find("claim") or low:find("hatch") or low == "0:00" or low == "00:00" or low == "0s" then
        return 0
    end
    local m, s = low:match("(%d+):(%d+)")
    if m and s then
        return tonumber(m) * 60 + tonumber(s)
    end
    local sec = low:match("(%d+)%s*s")
    if sec then return tonumber(sec) end
    local min = low:match("(%d+)%s*m")
    if min then return tonumber(min) * 60 end
    return nil
end

local function isTimerFinished(id, data, category)
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        local guiName = (category == "Egg" and "EggTimer_" or "LootboxTimer_") .. tostring(id)
        local timerGui = pg:FindFirstChild(guiName) or pg:FindFirstChild("Timer_" .. tostring(id))
        if timerGui then
            for _, desc in ipairs(timerGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Visible then
                    local remSec = parseTimerText(desc.Text)
                    if remSec ~= nil then
                        if remSec > 0 then
                            return false
                        else
                            return true
                        end
                    end
                end
            end
        end
    end
    local base = findPlayerBase()
    if base then
        for _, desc in ipairs(base:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = tostring(desc.ActionText):lower()
                if act:find("open") or act:find("hatch") or act:find("claim") then
                    if tostring(desc.Parent):find(tostring(id)) or (desc:FindFirstAncestorWhichIsA("Model") and desc:FindFirstAncestorWhichIsA("Model").Name:find(tostring(id))) then
                        return true
                    end
                end
            end
        end
    end
    if type(data) == "table" then
        if data.Ready == true or data.ready == true or data.isReady == true then
            return true
        end
        local rem = data.RemainingSeconds or data.remainingSeconds or data.remaining or data.Timer or data.timer
        if rem ~= nil and tonumber(rem) then
            if tonumber(rem) > 0 then
                return false
            else
                return true
            end
        end
        local now = workspace:GetServerTimeNow() or os.time()
        local endT = data.endTime or data.EndTime or data.readyAt or data.finishTime
        if endT and tonumber(endT) then
            if tonumber(endT) > now then
                return false
            else
                return true
            end
        end
    end
    return false
end

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

local function buyEggs()
    if not Config.AutoBuyEggs then return end
    local s = getState()
    local items = s.eggShopItems or {}
    local sold = s.eggShopSoldSlots or {}
    for slotIdx = 1, 3 do
        local eggName = items[slotIdx]
        local isSold = sold[slotIdx] == true
        if eggName and not isSold then
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
            task.wait(0.2)
        end
    end
    local decoStock = s.decorationsStoreStock or {}
    if decoStock["FunctionalObjectsCrate"] ~= 0 then
        fireRemote(Remotes.BuyDecorationsStoreItem, "FunctionalObjectsCrate")
        fireRemote(Remotes.BuyDecorationsStoreItem, 1)
        fireRemote(Remotes.BuyDecoration, "FunctionalObjectsCrate")
    end
end

local isAuctionBusy = false
local function buyAuctionHouseDirect()
    if not Config.AutoBuyAuctionHouse or isAuctionBusy then return end
    isAuctionBusy = true
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local ahCFrame, ahPart = getAuctionHouseCFrame()
        local savedCFrame = nil
        if ahCFrame and hrp then
            local dist = (hrp.Position - ahCFrame.Position).Magnitude
            if dist > 8 then
                savedCFrame = hrp.CFrame
                hrp.CFrame = ahCFrame + Vector3.new(0, 2, 0)
                task.wait(0.4)
            end
            local function checkAndTriggerPrompts(parent)
                if not parent then return end
                for _, desc in ipairs(parent:GetDescendants()) do
                    if desc:IsA("ProximityPrompt") and desc.Enabled then
                        triggerPrompt(desc)
                    end
                end
            end
            if ahPart then
                checkAndTriggerPrompts(ahPart)
            end
            for _, tagged in ipairs(CollectionService:GetTagged("AuctionHouse")) do
                if tagged:IsA("ProximityPrompt") and tagged.Enabled then
                    triggerPrompt(tagged)
                end
            end
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local pcf = desc.Parent and getPartCFrame(desc.Parent)
                    if pcf and (pcf.Position - hrp.Position).Magnitude <= 12 then
                        local act = tostring(desc.ActionText):lower()
                        local obj = tostring(desc.ObjectText):lower()
                        if act:find("open") or act:find("auction") or obj:find("auction") then
                            triggerPrompt(desc)
                        end
                    end
                end
            end
            task.wait(0.3)
        end
        if Remotes.GetAuctionHouseState and Remotes.GetAuctionHouseState.Call then
            pcall(function() Remotes.GetAuctionHouseState:Call():Await() end)
            task.wait(0.2)
        end
        for slotIdx = 1, 6 do
            if not isRunning or not Config.AutoBuyAuctionHouse then break end
            if Remotes.AuctionBuy then
                if Remotes.AuctionBuy.Call then
                    pcall(function() Remotes.AuctionBuy:Call(slotIdx):Await() end)
                    pcall(function() Remotes.AuctionBuy:Call(slotIdx, 1):Await() end)
                    pcall(function() Remotes.AuctionBuy:Call(tostring(slotIdx)):Await() end)
                    pcall(function() Remotes.AuctionBuy:Call({ Slot = slotIdx }):Await() end)
                    pcall(function() Remotes.AuctionBuy:Call({ slot = slotIdx }):Await() end)
                    pcall(function() Remotes.AuctionBuy:Call({ Slot = slotIdx, Amount = 1 }):Await() end)
                end
                if Remotes.AuctionBuy.Fire then
                    pcall(function() Remotes.AuctionBuy:Fire(slotIdx) end)
                    pcall(function() Remotes.AuctionBuy:Fire(slotIdx, 1) end)
                    pcall(function() Remotes.AuctionBuy:Fire(tostring(slotIdx)) end)
                    pcall(function() Remotes.AuctionBuy:Fire({ Slot = slotIdx }) end)
                    pcall(function() Remotes.AuctionBuy:Fire({ slot = slotIdx }) end)
                    pcall(function() Remotes.AuctionBuy:Fire({ Slot = slotIdx, Amount = 1 }) end)
                end
            end
            pcall(function()
                local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
                if pg then
                    local ahGui = pg:FindFirstChild("AuctionHouse", true)
                    if ahGui then
                        for _, desc in ipairs(ahGui:GetDescendants()) do
                            if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                                local txt = tostring(desc.Text or desc.Name):lower()
                                if txt:find("buy") or txt:find("purchase") or txt:find("claim") then
                                    if firesignal then
                                        pcall(function() firesignal(desc.MouseButton1Click) end)
                                        pcall(function() firesignal(desc.Activated) end)
                                    end
                                end
                            end
                        end
                    end
                end
            end)
            task.wait(0.85)
        end
        if savedCFrame and hrp and hrp.Parent then
            hrp.CFrame = savedCFrame
            task.wait(0.2)
        end
    end)
    isAuctionBusy = false
end

local function processOpenReadyItems()
    if not Config.AutoOpen then return end
    local s = getState()
    local placedEggs = s.placedEggs or {}
    for eggId, data in pairs(placedEggs) do
        if isTimerFinished(eggId, data, "Egg") then
            if Remotes.HatchEgg then
                if Remotes.HatchEgg.Call then
                    pcall(function() Remotes.HatchEgg:Call(eggId):Await() end)
                    pcall(function() Remotes.HatchEgg:Call(tostring(eggId)):Await() end)
                end
                if Remotes.HatchEgg.Fire then
                    pcall(function() Remotes.HatchEgg:Fire(eggId) end)
                    pcall(function() Remotes.HatchEgg:Fire(tostring(eggId)) end)
                end
            end
            task.wait(0.2)
        end
    end
    local placedBoxes = s.placedLootboxes or {}
    for boxId, data in pairs(placedBoxes) do
        if isTimerFinished(boxId, data, "Box") then
            if Remotes.OpenFloatLootbox then
                if Remotes.OpenFloatLootbox.Call then
                    pcall(function() Remotes.OpenFloatLootbox:Call(boxId):Await() end)
                    pcall(function() Remotes.OpenFloatLootbox:Call(tostring(boxId)):Await() end)
                end
                if Remotes.OpenFloatLootbox.Fire then
                    pcall(function() Remotes.OpenFloatLootbox:Fire(boxId) end)
                    pcall(function() Remotes.OpenFloatLootbox:Fire(tostring(boxId)) end)
                end
            end
            fireRemote(Remotes.ClaimFloatLootboxReward, boxId)
            task.wait(0.2)
        end
    end
    local base = findPlayerBase()
    if base and fireproximityprompt then
        for _, desc in ipairs(base:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local act = tostring(desc.ActionText):lower()
                if act:find("open") or act:find("hatch") or act:find("claim") then
                    triggerPrompt(desc)
                end
            end
        end
    end
end

local RarityScore = {
    ["MythicFloatCrate"] = 100,
    ["OceanEgg"] = 90,
    ["LegendaryFloatCrate"] = 80,
    ["EpicFloatCrate"] = 70,
    ["ForestEgg"] = 60,
    ["RareFloatCrate"] = 50,
    ["FarmEgg"] = 40,
    ["CommonFloatCrate"] = 30,
    ["FunctionalObjectsCrate"] = 25,
    ["CatFloatCrate"] = 20
}

local lastPlaceTime = 0
local function processPlaceItemsIfSpace()
    if not Config.AutoPlace then return end
    if os.clock() - lastPlaceTime < 1.4 then return end
    local hasSpace = hasSpaceToPlace()
    if not hasSpace then return end
    local freeSlot = getFreeBaseSlot()
    local s = getState()
    local inv = s.inventory or {}
    local candidates = {}
    for key, item in pairs(inv) do
        if type(item) == "table" then
            local name = item.ConfigName or tostring(key)
            local count = tonumber(item.Stack) or 1
            if count > 0 then
                local isEgg = (item.Category == "Egg") or name:find("Egg")
                local isBox = (item.Category == "FloatLootbox") or name:find("Crate") or name:find("Lootbox")
                if isEgg and name ~= "MythicEgg" then
                    table.insert(candidates, { Name = name, Type = "Egg", Score = RarityScore[name] or 35 })
                elseif isBox then
                    table.insert(candidates, { Name = name, Type = "Box", Score = RarityScore[name] or 25 })
                end
            end
        end
    end
    if #candidates == 0 then return end
    if Config.OpenPriority == "HighTierFirst" then
        table.sort(candidates, function(a, b) return a.Score > b.Score end)
    elseif Config.OpenPriority == "EggsFirst" then
        table.sort(candidates, function(a, b)
            if a.Type == b.Type then return a.Score > b.Score end
            return a.Type == "Egg"
        end)
    elseif Config.OpenPriority == "BoxesFirst" then
        table.sort(candidates, function(a, b)
            if a.Type == b.Type then return a.Score > b.Score end
            return a.Type == "Box"
        end)
    end
    local chosen = candidates[1]
    lastPlaceTime = os.clock()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local baseCf = getBaseCFrame()
    local savedCFrame = nil
    if baseCf and hrp then
        local dist = (hrp.Position - baseCf.Position).Magnitude
        if dist > 12 then
            savedCFrame = hrp.CFrame
            hrp.CFrame = baseCf + Vector3.new(0, 3, 0)
            task.wait(0.4)
        end
    end
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack and char then
        local tool = backpack:FindFirstChild(chosen.Name)
        if tool and tool:IsA("Tool") then
            pcall(function() tool.Parent = char end)
            task.wait(0.2)
        end
    end
    if baseCf then
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") and desc.Enabled then
                local pPos = desc.Parent and getPartCFrame(desc.Parent)
                if pPos and (pPos.Position - baseCf.Position).Magnitude <= 30 then
                    local act = tostring(desc.ActionText):lower()
                    local obj = tostring(desc.ObjectText):lower()
                    if act:find("place") or act:find("put") or act:find("add") or act:find("incub") or
                       obj:find("egg") or obj:find("crate") or obj:find("lootbox") or obj:find("stand") then
                        triggerPrompt(desc)
                        task.wait(0.1)
                    end
                end
            end
        end
    end
    if chosen.Type == "Egg" then
        local remote = Remotes.PlaceEgg
        if remote then
            if remote.Call then
                pcall(function() remote:Call(chosen.Name, freeSlot):Await() end)
                pcall(function() remote:Call(freeSlot, chosen.Name):Await() end)
                pcall(function() remote:Call(chosen.Name):Await() end)
                pcall(function() remote:Call({ ConfigName = chosen.Name, Slot = freeSlot }):Await() end)
                pcall(function() remote:Call({ ConfigName = chosen.Name }):Await() end)
            end
            if remote.Fire then
                pcall(function() remote:Fire(chosen.Name, freeSlot) end)
                pcall(function() remote:Fire(freeSlot, chosen.Name) end)
                pcall(function() remote:Fire(chosen.Name) end)
                pcall(function() remote:Fire({ ConfigName = chosen.Name, Slot = freeSlot }) end)
            end
        end
    else
        local remote = Remotes.PlaceFloatLootbox
        if remote then
            if remote.Call then
                pcall(function() remote:Call(chosen.Name, freeSlot):Await() end)
                pcall(function() remote:Call(freeSlot, chosen.Name):Await() end)
                pcall(function() remote:Call(chosen.Name):Await() end)
                pcall(function() remote:Call({ ConfigName = chosen.Name, Slot = freeSlot }):Await() end)
                pcall(function() remote:Call({ ConfigName = chosen.Name }):Await() end)
            end
            if remote.Fire then
                pcall(function() remote:Fire(chosen.Name, freeSlot) end)
                pcall(function() remote:Fire(freeSlot, chosen.Name) end)
                pcall(function() remote:Fire(chosen.Name) end)
                pcall(function() remote:Fire({ ConfigName = chosen.Name, Slot = freeSlot }) end)
            end
        end
        fireRemote(Remotes.OpenLuckyblock, chosen.Name)
    end
    task.wait(0.3)
    if savedCFrame and hrp and hrp.Parent then
        hrp.CFrame = savedCFrame
        task.wait(0.2)
    end
end

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK and VirtualUser then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end))

task.spawn(function()
    local auctionTimer = 0
    while isRunning and _G.__SAKURA_MAIN == CURRENT_SESSION do
        if Config.AutoCollectCash then pcall(collectCash) end
        if Config.AutoBuyEggs then pcall(buyEggs) end
        if Config.AutoBuyBoxes then pcall(buyBoxes) end
        pcall(processOpenReadyItems)
        pcall(processPlaceItemsIfSpace)
        auctionTimer = auctionTimer + 1.5
        if auctionTimer >= 60 then
            auctionTimer = 0
            if Config.AutoBuyAuctionHouse then pcall(buyAuctionHouseDirect) end
        end
        task.wait(1.5)
    end
end)

local Theme = {
    Background = Color3.fromRGB(18, 14, 22),
    Sidebar    = Color3.fromRGB(24, 18, 28),
    Card       = Color3.fromRGB(28, 21, 33),
    CardSub    = Color3.fromRGB(38, 28, 45),
    CardActive = Color3.fromRGB(50, 36, 60),
    Accent     = Color3.fromRGB(255, 107, 139),
    AccentSoft = Color3.fromRGB(255, 180, 200),
    AccentGlow = Color3.fromRGB(255, 140, 168),
    Text       = Color3.fromRGB(255, 245, 248),
    TextDim    = Color3.fromRGB(200, 168, 185),
    Green      = Color3.fromRGB(115, 230, 155),
    Red        = Color3.fromRGB(255, 95, 120),
    Stroke     = Color3.fromRGB(255, 107, 139),
    StrokeSub  = Color3.fromRGB(60, 44, 68)
}

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SakuraLuckyFish_Main"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

table.insert(connections, ScreenGui.Destroying:Connect(cleanShutdown))

local Main = Instance.new("Frame")
Main.Name = "SakuraMain"
Main.Size = UDim2.new(0, 580, 0, 430)
Main.Position = UDim2.new(0.5, -290, 0.5, -215)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.Active = true
Main.ClipsDescendants = true
Main.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = Main

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Stroke
MainStroke.Thickness = 1.4
MainStroke.Parent = Main

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
        local camera = workspace.CurrentCamera
        local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local newX = math.clamp(startPos.X.Offset + delta.X, -vp.X * 0.5 + 20, vp.X * 0.5 - 20)
        local newY = math.clamp(startPos.Y.Offset + delta.Y, -vp.Y * 0.5 + 20, vp.Y * 0.5 - 20)
        Main.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
    end
end))

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 42)
TopBar.BackgroundColor3 = Theme.Sidebar
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local TopCorner = Instance.new("UICorner")
TopCorner.CornerRadius = UDim.new(0, 14)
TopCorner.Parent = TopBar

local TopTitle = Instance.new("TextLabel")
TopTitle.Size = UDim2.new(1, -140, 1, 0)
TopTitle.Position = UDim2.new(0, 16, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "🌸 SAKURA • Pull A Lucky Fish"
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13
TopTitle.TextColor3 = Theme.Text
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.Parent = TopBar

local StatusPill = Instance.new("Frame")
StatusPill.Size = UDim2.new(0, 70, 0, 22)
StatusPill.Position = UDim2.new(1, -156, 0.5, -11)
StatusPill.BackgroundColor3 = Theme.CardSub
StatusPill.Parent = TopBar

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(1, 0)
StatusCorner.Parent = StatusPill

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.new(0, 6, 0, 6)
StatusDot.Position = UDim2.new(0, 8, 0.5, -3)
StatusDot.BackgroundColor3 = Theme.Green
StatusDot.BorderSizePixel = 0
StatusDot.Parent = StatusPill

local StatusDotCorner = Instance.new("UICorner")
StatusDotCorner.CornerRadius = UDim.new(1, 0)
StatusDotCorner.Parent = StatusDot

local StatusText = Instance.new("TextLabel")
StatusText.Size = UDim2.new(1, -18, 1, 0)
StatusText.Position = UDim2.new(0, 18, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "ACTIVE"
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 9
StatusText.TextColor3 = Theme.Green
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusPill

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = Theme.CardSub
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.TextColor3 = Theme.AccentSoft
CloseBtn.AutoButtonColor = false
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
MinBtn.AutoButtonColor = false
MinBtn.Parent = TopBar
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(0, 6)
MinCorner.Parent = MinBtn

local FloatBtn = Instance.new("TextButton")
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0, 16, 0.5, -22)
FloatBtn.BackgroundColor3 = Theme.Background
FloatBtn.Text = "🌸"
FloatBtn.TextSize = 22
FloatBtn.Visible = false
FloatBtn.Active = true
FloatBtn.Parent = ScreenGui

local FloatCorner = Instance.new("UICorner")
FloatCorner.CornerRadius = UDim.new(1, 0)
FloatCorner.Parent = FloatBtn

local FloatStroke = Instance.new("UIStroke")
FloatStroke.Color = Theme.Accent
FloatStroke.Thickness = 1.6
FloatStroke.Parent = FloatBtn

local fDragging, fDragStart, fStartPos
table.insert(connections, FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fDragging = true
        fDragStart = input.Position
        fStartPos = FloatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then fDragging = false end
        end)
    end
end))

table.insert(connections, UserInputService.InputChanged:Connect(function(input)
    if fDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - fDragStart
        FloatBtn.Position = UDim2.new(fStartPos.X.Scale, fStartPos.X.Offset + delta.X, fStartPos.Y.Scale, fStartPos.Y.Offset + delta.Y)
    end
end))

local function toggleUI(visible)
    if visible == nil then visible = not Main.Visible end
    if visible then
        FloatBtn.Visible = false
        Main.Visible = true
        Main.Size = UDim2.new(0, 500, 0, 370)
        TweenService:Create(Main, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 580, 0, 430)
        }):Play()
    else
        local tween = TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 500, 0, 370)
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not Main.Visible then return end
            Main.Visible = false
            FloatBtn.Visible = true
        end)
    end
end

FloatBtn.MouseButton1Click:Connect(function() toggleUI(true) end)
MinBtn.MouseButton1Click:Connect(function() toggleUI(false) end)

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        toggleUI()
    end
end))

local Toast = Instance.new("Frame")
Toast.Size = UDim2.new(0, 240, 0, 28)
Toast.Position = UDim2.new(0.5, -120, 1, -38)
Toast.BackgroundColor3 = Theme.CardActive
Toast.BorderSizePixel = 0
Toast.Visible = false
Toast.ZIndex = 10
Toast.Parent = Main

local ToastCorner = Instance.new("UICorner")
ToastCorner.CornerRadius = UDim.new(0, 8)
ToastCorner.Parent = Toast

local ToastStroke = Instance.new("UIStroke")
ToastStroke.Color = Theme.Accent
ToastStroke.Thickness = 1
ToastStroke.Parent = Toast

local ToastLabel = Instance.new("TextLabel")
ToastLabel.Size = UDim2.new(1, 0, 1, 0)
ToastLabel.BackgroundTransparency = 1
ToastLabel.Font = Enum.Font.GothamSemibold
ToastLabel.TextSize = 11
ToastLabel.TextColor3 = Theme.Text
ToastLabel.ZIndex = 11
ToastLabel.Parent = Toast

local toastThread
local function notify(msg)
    if toastThread then task.cancel(toastThread) end
    toastThread = task.spawn(function()
        ToastLabel.Text = msg
        Toast.Position = UDim2.new(0.5, -120, 1, -20)
        Toast.BackgroundTransparency = 1
        ToastLabel.TextTransparency = 1
        Toast.Visible = true
        TweenService:Create(Toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0.5, -120, 1, -38),
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(ToastLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            TextTransparency = 0
        }):Play()
        task.wait(1.6)
        local out = TweenService:Create(Toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, -120, 1, -20),
            BackgroundTransparency = 1
        })
        TweenService:Create(ToastLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            TextTransparency = 1
        }):Play()
        out:Play()
        out.Completed:Connect(function()
            Toast.Visible = false
        end)
    end)
end

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 144, 1, -50)
Sidebar.Position = UDim2.new(0, 8, 0, 46)
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

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -168, 1, -50)
Container.Position = UDim2.new(0, 160, 0, 46)
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
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = Theme.Card
    btn.Text = title
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.TextDim
    btn.AutoButtonColor = false
    btn.Parent = Sidebar

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Theme.Accent
    btnStroke.Thickness = 0.8
    btnStroke.Transparency = 0.8
    btnStroke.Parent = btn

    Tabs[id] = page
    TabBtns[id] = { Button = btn, Stroke = btnStroke }

    btn.MouseButton1Click:Connect(function()
        for tId, p in pairs(Tabs) do
            local isTarget = (tId == id)
            p.Visible = isTarget
            local b = TabBtns[tId]
            if isTarget then
                TweenService:Create(b.Button, TweenInfo.new(0.18), { BackgroundColor3 = Theme.CardActive, TextColor3 = Theme.AccentSoft }):Play()
                TweenService:Create(b.Stroke, TweenInfo.new(0.18), { Transparency = 0 }):Play()
            else
                TweenService:Create(b.Button, TweenInfo.new(0.18), { BackgroundColor3 = Theme.Card, TextColor3 = Theme.TextDim }):Play()
                TweenService:Create(b.Stroke, TweenInfo.new(0.18), { Transparency = 0.8 }):Play()
            end
        end
    end)

    return page
end

local PageFarm  = createTab("Farm", "💰 Farm & Cash")
local PageShop  = createTab("Shop", "🛍️ Shop & Auction")
local PageOpen  = createTab("Open", "⏳ Place & Hatch")
local PageExtra = createTab("Extra", "⚙️ Settings")

local function makeCard(parent, title)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -6, 0, 0)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card

    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.StrokeSub
    stroke.Thickness = 0.8
    stroke.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
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

local function makeToggle(card, title, configKey, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 28)
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

    local defaultVal = Config[configKey] or false
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
        local targetColor = val and Theme.Accent or Theme.CardSub
        local targetPos = val and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundColor3 = targetColor }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = targetPos }):Play()
        if callback then callback(val) end
        notify(title .. ": " .. (val and "ON" or "OFF"))
    end)
    return row
end

local function makeButton(card, text, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Theme.CardSub
    btn.Text = text
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 11
    btn.TextColor3 = Theme.Text
    btn.AutoButtonColor = false
    btn.Parent = card

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = btn

    local bStroke = Instance.new("UIStroke")
    bStroke.Color = Theme.Accent
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
        TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = Theme.Accent }):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Theme.CardActive }):Play()
        onClick()
    end)
    return btn
end

local BalanceCard = makeCard(PageFarm, "Live Balance")
local BalLabel = Instance.new("TextLabel")
BalLabel.Size = UDim2.new(1, 0, 0, 20)
BalLabel.BackgroundTransparency = 1
BalLabel.Font = Enum.Font.GothamBold
BalLabel.TextSize = 13
BalLabel.TextColor3 = Theme.Green
BalLabel.TextXAlignment = Enum.TextXAlignment.Left
BalLabel.Text = "💰 Cash: Loading..."
BalLabel.Parent = BalanceCard

local CashAutoCard = makeCard(PageFarm, "Auto Cash Collection")
makeToggle(CashAutoCard, "Auto Collect Cash (All Base Slots)", "AutoCollectCash")
makeButton(CashAutoCard, "⚡ Force Collect Now", function()
    collectCash()
    notify("Collected cash from all slots!")
end)

local EggCard = makeCard(PageShop, "Egg Shop (Skips Mythic Robux)")
makeToggle(EggCard, "Auto Buy Eggs in Stock", "AutoBuyEggs")
local EggStockLabel = Instance.new("TextLabel")
EggStockLabel.Size = UDim2.new(1, 0, 0, 16)
EggStockLabel.BackgroundTransparency = 1
EggStockLabel.Font = Enum.Font.Gotham
EggStockLabel.TextSize = 10
EggStockLabel.TextColor3 = Theme.TextDim
EggStockLabel.TextXAlignment = Enum.TextXAlignment.Left
EggStockLabel.Text = "Stock: Scanning..."
EggStockLabel.Parent = EggCard

local BoxCard = makeCard(PageShop, "Box Shop (Floats & Functional Crates)")
makeToggle(BoxCard, "Auto Buy Boxes & Functional Crates", "AutoBuyBoxes")
local BoxStockLabel = Instance.new("TextLabel")
BoxStockLabel.Size = UDim2.new(1, 0, 0, 16)
BoxStockLabel.BackgroundTransparency = 1
BoxStockLabel.Font = Enum.Font.Gotham
BoxStockLabel.TextSize = 10
BoxStockLabel.TextColor3 = Theme.TextDim
BoxStockLabel.TextXAlignment = Enum.TextXAlignment.Left
BoxStockLabel.Text = "Stock: Scanning..."
BoxStockLabel.Parent = BoxCard

local AuctionCard = makeCard(PageShop, "Auction House (1-Hour Direct Buy, No Bids)")
makeToggle(AuctionCard, "Auto Buy Hourly Direct-Buy Items", "AutoBuyAuctionHouse", function(v)
    if v then task.spawn(buyAuctionHouseDirect) end
end)
local AuctionStatusLabel = Instance.new("TextLabel")
AuctionStatusLabel.Size = UDim2.new(1, 0, 0, 16)
AuctionStatusLabel.BackgroundTransparency = 1
AuctionStatusLabel.Font = Enum.Font.Gotham
AuctionStatusLabel.TextSize = 10
AuctionStatusLabel.TextColor3 = Theme.TextDim
AuctionStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
AuctionStatusLabel.Text = "Stock: Ready (checks hourly restock, direct buy only)"
AuctionStatusLabel.Parent = AuctionCard

makeButton(AuctionCard, "⚡ Buy Auction House Stock Now", function()
    notify("Attempting Auction House direct buy...")
    task.spawn(buyAuctionHouseDirect)
end)

local OpenMasterCard = makeCard(PageOpen, "Automation Controls")
makeToggle(OpenMasterCard, "Auto Place (Checks Space & Base)", "AutoPlace")
makeToggle(OpenMasterCard, "Auto Open/Hatch (Checks Timer Finished)", "AutoOpen")

local SpaceStatusCard = makeCard(PageOpen, "Base Incubation Capacity & Timers")
local SlotStatusLabel = Instance.new("TextLabel")
SlotStatusLabel.Size = UDim2.new(1, 0, 0, 18)
SlotStatusLabel.BackgroundTransparency = 1
SlotStatusLabel.Font = Enum.Font.GothamBold
SlotStatusLabel.TextSize = 11
SlotStatusLabel.TextColor3 = Theme.Green
SlotStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
SlotStatusLabel.Text = "Slots: Checking base capacity..."
SlotStatusLabel.Parent = SpaceStatusCard

local TimerStatusLabel = Instance.new("TextLabel")
TimerStatusLabel.Size = UDim2.new(1, 0, 0, 16)
TimerStatusLabel.BackgroundTransparency = 1
TimerStatusLabel.Font = Enum.Font.Gotham
TimerStatusLabel.TextSize = 10
TimerStatusLabel.TextColor3 = Theme.TextDim
TimerStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
TimerStatusLabel.Text = "Timers: Monitoring placed items..."
TimerStatusLabel.Parent = SpaceStatusCard

makeButton(SpaceStatusCard, "⚡ Force Open Ready Items Now (Timer = 0s only)", function()
    processOpenReadyItems()
    notify("Checked and opened all ready items!")
end)

local PriorityCard = makeCard(PageOpen, "Placement Priority Order")
local PriorityLabel = Instance.new("TextLabel")
PriorityLabel.Size = UDim2.new(1, 0, 0, 18)
PriorityLabel.BackgroundTransparency = 1
PriorityLabel.Font = Enum.Font.GothamSemibold
PriorityLabel.TextSize = 11
PriorityLabel.TextColor3 = Theme.AccentSoft
PriorityLabel.TextXAlignment = Enum.TextXAlignment.Left
local function getPriorityTitle(p)
    if p == "EggsFirst" then return "Eggs First" end
    if p == "BoxesFirst" then return "Boxes First" end
    return "High Tier First"
end
PriorityLabel.Text = "Current Priority: " .. getPriorityTitle(Config.OpenPriority)
PriorityLabel.Parent = PriorityCard

makeButton(PriorityCard, "⭐ Priority: High Tier First (Mythic > Rare)", function()
    Config.OpenPriority = "HighTierFirst"
    saveSettings()
    PriorityLabel.Text = "Current Priority: High Tier First"
    notify("Priority saved: High Tier First")
end)
makeButton(PriorityCard, "🥚 Priority: Eggs First (All Eggs > Boxes)", function()
    Config.OpenPriority = "EggsFirst"
    saveSettings()
    PriorityLabel.Text = "Current Priority: Eggs First"
    notify("Priority saved: Eggs First")
end)
makeButton(PriorityCard, "📦 Priority: Boxes First (All Boxes > Eggs)", function()
    Config.OpenPriority = "BoxesFirst"
    saveSettings()
    PriorityLabel.Text = "Current Priority: Boxes First"
    notify("Priority saved: Boxes First")
end)

local PrefCard = makeCard(PageExtra, "Preferences & Storage")
makeToggle(PrefCard, "Soft Anti-AFK (VirtualUser)", "AntiAFK")
makeButton(PrefCard, "💾 Save Settings to Workspace", function()
    saveSettings()
    notify("Config saved to PullALuckyFish_Config.json")
end)
makeButton(PrefCard, "🛑 Unload Script Cleanly", function()
    cleanShutdown()
end)

task.spawn(function()
    while isRunning and _G.__SAKURA_MAIN == CURRENT_SESSION do
        pcall(function()
            local s = getState()
            local m = s.money or 0
            local g = s.gems or 0
            BalLabel.Text = string.format("💰 Cash: %s  |  💎 Gems: %s", formatNumber(m), formatNumber(g))

            local eItems = s.eggShopItems or {}
            local eSold = s.eggShopSoldSlots or {}
            local eTxt = {}
            for i = 1, 3 do
                table.insert(eTxt, string.format("#%d: %s (%s)", i, eItems[i] or "-", eSold[i] and "Sold" or "Ready"))
            end
            EggStockLabel.Text = table.concat(eTxt, " | ")

            local bItems = s.lootboxShopItems or {}
            local bSold = s.lootboxShopSoldSlots or {}
            local bTxt = {}
            for i = 1, 3 do
                table.insert(bTxt, string.format("#%d: %s (%s)", i, bItems[i] or "-", bSold[i] and "Sold" or "Ready"))
            end
            BoxStockLabel.Text = table.concat(bTxt, " | ")

            local hasSpace, currentCount, maxLimit = hasSpaceToPlace()
            if hasSpace then
                SlotStatusLabel.Text = string.format("Slots: %d / %d Used  ✔ (%d Free Space)", currentCount, maxLimit, maxLimit - currentCount)
                SlotStatusLabel.TextColor3 = Theme.Green
            else
                SlotStatusLabel.Text = string.format("Slots: %d / %d Full  ⛔ (No Free Space)", currentCount, maxLimit)
                SlotStatusLabel.TextColor3 = Theme.Red
            end

            local placedEggs = s.placedEggs or {}
            local placedBoxes = s.placedLootboxes or {}
            local readyCount = 0
            local runningCount = 0

            for id, d in pairs(placedEggs) do
                if isTimerFinished(id, d, "Egg") then readyCount = readyCount + 1 else runningCount = runningCount + 1 end
            end
            for id, d in pairs(placedBoxes) do
                if isTimerFinished(id, d, "Box") then readyCount = readyCount + 1 else runningCount = runningCount + 1 end
            end

            TimerStatusLabel.Text = string.format("Timers: %d Still Ticking  |  %d Finished & Ready to Open", runningCount, readyCount)
        end)
        task.wait(1.4)
    end
end)

Tabs["Farm"].Visible = true
TweenService:Create(TabBtns["Farm"].Button, TweenInfo.new(0.18), { BackgroundColor3 = Theme.CardActive, TextColor3 = Theme.AccentSoft }):Play()
TweenService:Create(TabBtns["Farm"].Stroke, TweenInfo.new(0.18), { Transparency = 0 }):Play()
