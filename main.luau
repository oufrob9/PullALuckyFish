--[[
    🌸 SAKURA • Pull A Lucky Fish — v2 (réécriture complète)

    Principes de cette version :
      • Aucun appel bloquant : chaque remote est appelé avec un timeout, chaque fonctionnalité
        tourne dans sa propre boucle (une fonction qui plante ne bloque plus les autres).
      • Plus de spam de variantes : le script teste les formats d'arguments UNE fois, vérifie le
        résultat dans l'état du jeu (argent, stock, items placés…) puis mémorise la variante qui marche.
      • Plus de GetDescendants() sur tout le workspace (source principale des lags).
      • Les timers sont lus d'abord dans l'UI du jeu (LootboxTimer_<id>), puis déduits des données.
      • Onglet Logs + bouton Diagnostic (console F9) pour affiner si une variante n'est pas trouvée.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Session (une seule instance à la fois)
---------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G
if type(ENV.__SAKURA_SHUTDOWN) == "function" then
    pcall(ENV.__SAKURA_SHUTDOWN)
end
ENV.__SAKURA_SESSION = (ENV.__SAKURA_SESSION or 0) + 1
local SESSION = ENV.__SAKURA_SESSION
local GUI_NAME = "SakuraLuckyFish_Main"

local running = true
local connections = {}
local ScreenGui

local function track(conn)
    connections[#connections + 1] = conn
    return conn
end

local function alive()
    return running and ENV.__SAKURA_SESSION == SESSION
end

local function shutdown()
    if not running then return end
    running = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    table.clear(connections)
    if ScreenGui then pcall(function() ScreenGui:Destroy() end) end
end
ENV.__SAKURA_SHUTDOWN = shutdown

local function guiRoot()
    local ok, root = pcall(function() return gethui and gethui() end)
    if ok and root then return root end
    return PlayerGui
end

for _, root in ipairs({ guiRoot(), PlayerGui }) do
    local old = root:FindFirstChild(GUI_NAME)
    if old then pcall(function() old:Destroy() end) end
end

---------------------------------------------------------------------
-- Logs
---------------------------------------------------------------------
local logLines, onLog = {}, nil
local function log(...)
    local parts = table.pack(...)
    for i = 1, parts.n do parts[i] = tostring(parts[i]) end
    local line = os.date("%H:%M:%S") .. "  " .. table.concat(parts, " ")
    print("[Sakura] " .. line)
    logLines[#logLines + 1] = line
    if #logLines > 80 then table.remove(logLines, 1) end
    if onLog then pcall(onLog) end
end

---------------------------------------------------------------------
-- Configuration persistante
---------------------------------------------------------------------
local CONFIG_FILE = "PullALuckyFish_Config.json"
local DEFAULTS = {
    AutoCollectCash = false,
    AutoBuyEggs = false,
    AutoBuyBoxes = false,
    AutoBuyDecoCrate = false,
    AutoBuyAuction = false,
    AutoPlace = false,
    AutoOpen = false,
    AntiAFK = false,
    AllowTeleport = true,
    OpenPriority = "HighTierFirst",
    CollectInterval = 5,
    Learned = {},
    Modes = {},
}

local Config = {}
for k, v in pairs(DEFAULTS) do Config[k] = v end

local function saveSettings()
    pcall(function()
        if writefile then writefile(CONFIG_FILE, HttpService:JSONEncode(Config)) end
    end)
end

pcall(function()
    if isfile and readfile and isfile(CONFIG_FILE) then
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        if type(data) == "table" then
            for k, v in pairs(DEFAULTS) do
                if data[k] ~= nil and type(data[k]) == type(v) then Config[k] = data[k] end
            end
        end
    end
end)

local Learned = Config.Learned     -- clé -> index de la variante d'arguments validée
local remoteMode = Config.Modes    -- nom du remote -> "call" | "fire"

---------------------------------------------------------------------
-- Modules du jeu
---------------------------------------------------------------------
local Shared = ReplicatedStorage:WaitForChild("shared", 15)
local ClientFolder = ReplicatedStorage:WaitForChild("client", 15)
if not (Shared and ClientFolder) then
    warn("[Sakura] ReplicatedStorage.shared / client introuvables — mauvais jeu ?")
    return
end

local okR, Remotes = pcall(function() return require(Shared:WaitForChild("Remotes", 15)) end)
local okC, CPD = pcall(function() return require(ClientFolder:WaitForChild("ClientPlayerData", 15)) end)
if not (okR and okC and Remotes and CPD) then
    warn("[Sakura] Impossible de charger Remotes / ClientPlayerData")
    return
end

do
    local t0 = os.clock()
    while alive() and not CPD.isPlayerDataLoaded and os.clock() - t0 < 30 do task.wait(0.25) end
end

local function getState()
    local sources = { CPD.serverProfile, CPD.clientProducer }
    for _, src in ipairs(sources) do
        if type(src) == "table" and type(src.getState) == "function" then
            local ok, s = pcall(src.getState, src)
            if ok and type(s) == "table" and s.money ~= nil then return s end
        end
    end
    if type(CPD.getState) == "function" then
        local ok, s = pcall(CPD.getState, CPD)
        if ok and type(s) == "table" then return s end
    end
    return {}
end

local configCache = {}
local function loadConfig(name)
    if configCache[name] == nil then
        local ok, mod = pcall(function()
            return require(Shared:WaitForChild("config", 5):WaitForChild(name, 5))
        end)
        configCache[name] = (ok and mod) or false
    end
    return configCache[name] or nil
end

---------------------------------------------------------------------
-- Utilitaires
---------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local function formatNumber(n)
    n = tonumber(n) or 0
    if n ~= n then return "NaN" end
    if math.abs(n) < 1000 then return tostring(math.floor(n)) end
    local i = 1
    while math.abs(n) >= 1000 and i < #SUFFIXES do
        n = n / 1000
        i += 1
    end
    if math.abs(n) >= 1000 then return string.format("%.2e", n * 1000 ^ (i - 1)) end
    return string.format("%.2f %s", n, SUFFIXES[i])
end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n += 1 end end
    return n
end

local function at(t, i)
    if type(t) ~= "table" then return nil end
    local v = t[i]
    if v == nil then v = t[tostring(i)] end
    return v
end

local function deepSig(v, depth)
    depth = depth or 3
    if type(v) ~= "table" then return tostring(v) end
    if depth <= 0 then return "{…}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. deepSig(v[k], depth - 1) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function stackOf(s, name)
    local it = (s.inventory or {})[name]
    return type(it) == "table" and (tonumber(it.Stack) or 0) or 0
end

local function totalStacks(s)
    local n = 0
    for _, it in pairs(s.inventory or {}) do
        if type(it) == "table" then n += tonumber(it.Stack) or 0 end
    end
    return n
end

local function moneyNow() return tonumber(getState().money) or 0 end
local function serverNow() return workspace:GetServerTimeNow() end

local function dumpLines(value, maxDepth, maxLines)
    local out, seen = {}, {}
    local function walk(val, depth, indent, label)
        if #out >= maxLines then return end
        if type(val) == "table" then
            if seen[val] then out[#out + 1] = indent .. label .. " = <cycle>" return end
            if depth >= maxDepth then out[#out + 1] = indent .. label .. " = {… " .. countKeys(val) .. " clés}" return end
            seen[val] = true
            out[#out + 1] = indent .. label .. " = {"
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do walk(val[k], depth + 1, indent .. "  ", tostring(k)) end
            out[#out + 1] = indent .. "}"
            seen[val] = nil
        else
            out[#out + 1] = indent .. label .. " = " .. tostring(val) .. " (" .. typeof(val) .. ")"
        end
    end
    walk(value, 0, "", "root")
    return out
end

local function printDump(title, value, maxDepth, maxLines)
    print("[Sakura] ===== " .. title .. " =====")
    for _, l in ipairs(dumpLines(value, maxDepth or 3, maxLines or 120)) do print(l) end
end

---------------------------------------------------------------------
-- Couche remotes (timeouts + apprentissage des arguments)
---------------------------------------------------------------------
local CALL_TIMEOUT = 3

local function runWithTimeout(timeout, fn)
    local done, packed = false, nil
    local thread = task.spawn(function()
        packed = table.pack(pcall(fn))
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do task.wait(0.03) end
    if not done then
        pcall(task.cancel, thread)
        return "timeout"
    end
    if packed[1] then return "ok", table.unpack(packed, 2, packed.n) end
    return "error", packed[2]
end

-- Envoie une requête. Retourne true si elle est partie (pas forcément acceptée par le serveur).
local function invoke(name, ...)
    local okGet, remote = pcall(function() return Remotes[name] end)
    if not okGet or remote == nil then return false, "remote introuvable: " .. tostring(name) end
    local args = table.pack(...)

    if typeof(remote) == "Instance" then
        if remote:IsA("RemoteFunction") then
            local status, a = runWithTimeout(CALL_TIMEOUT, function()
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            end)
            return status == "ok", a
        end
        local ok, err = pcall(function() remote:FireServer(table.unpack(args, 1, args.n)) end)
        return ok, err
    end

    local function fire()
        local status, err = runWithTimeout(2, function()
            local f = remote.Fire or remote.fire
            if not f then error("pas de méthode Fire") end
            f(remote, table.unpack(args, 1, args.n))
        end)
        return status == "ok", err
    end

    local function call()
        return runWithTimeout(CALL_TIMEOUT, function()
            local c = remote.Call or remote.call
            if not c then error("pas de méthode Call") end
            local p = c(remote, table.unpack(args, 1, args.n))
            if typeof(p) == "table" and type(p.Await) == "function" then return p:Await() end
            return p
        end)
    end

    local mode = remoteMode[name]
    if mode == "fire" then return fire() end

    local status, a, b = call()
    if status == "ok" then
        remoteMode[name] = "call"
        return true, a, b
    end
    if status == "timeout" then
        if mode == "call" then return false, "timeout" end
        remoteMode[name] = "fire" -- requête partie mais jamais de réponse : remote de type événement
        return true
    end
    if mode == "call" then return false, a end
    local okFire, err = fire()
    if okFire then remoteMode[name] = "fire" end
    return okFire, err
end

-- Teste des formats d'arguments jusqu'à ce que l'état du jeu change, puis mémorise le bon.
local failures, cooldownUntil = {}, {}
local function probe(key, remoteName, variants, snap, changed, opts)
    opts = opts or {}
    local settle = opts.settle or 1.2
    if os.clock() < (cooldownUntil[key] or 0) then return false, "cooldown" end

    local function attempt(i)
        local build = variants[i]
        local args = build and build()
        if not args then return false end
        local before = snap()
        if not invoke(remoteName, table.unpack(args, 1, args.n or #args)) then return false end
        local t0 = os.clock()
        while alive() and os.clock() - t0 < settle do
            task.wait(0.15)
            if changed(before, snap()) then return true end
        end
        return false
    end

    local idx = Learned[key]
    if idx and variants[idx] then
        if attempt(idx) then failures[key] = 0 return true end
        failures[key] = (failures[key] or 0) + 1
        if failures[key] >= 8 then
            Learned[key] = nil
            failures[key] = 0
            log("Variante oubliée pour", key, "(trop d'échecs) — nouvel apprentissage au prochain essai")
        elseif failures[key] % 3 == 0 then
            cooldownUntil[key] = os.clock() + 60
        end
        return false
    end

    for i = 1, #variants do
        if not alive() then return false end
        if attempt(i) then
            Learned[key] = i
            failures[key] = 0
            saveSettings()
            log("✔ " .. key .. ": variante #" .. i .. " validée")
            return true
        end
    end
    local cd = opts.cooldown
    if cd == nil then cd = 45 end
    if cd > 0 then cooldownUntil[key] = os.clock() + cd end
    return false
end

---------------------------------------------------------------------
-- Monde : positions, téléportation, prompts
---------------------------------------------------------------------
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getPartCFrame(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.CFrame end
    if inst:IsA("Attachment") then return inst.WorldCFrame end
    if inst:IsA("Model") then return inst:GetPivot() end
    if inst:IsA("ProximityPrompt") and inst.Parent then return getPartCFrame(inst.Parent) end
    return nil
end

local function triggerPrompt(prompt)
    if not (prompt and prompt.Enabled) then return end
    if type(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end

local teleportBusy = false
local function withTeleport(cf, radius, fn)
    local hrp = getHRP()
    if not (hrp and cf) or (hrp.Position - cf.Position).Magnitude <= radius then return fn() end
    if teleportBusy then return false end
    teleportBusy = true
    local saved = hrp.CFrame
    hrp.CFrame = cf + Vector3.new(0, 3, 0)
    task.wait(0.4)
    local ok, res = pcall(fn)
    local again = getHRP()
    if again then again.CFrame = saved end
    teleportBusy = false
    if not ok then log("Erreur pendant la téléportation:", res) return false end
    return res
end

local function getBaseCFrame()
    local home = PlayerGui:FindFirstChild("HomeIndicator")
    if home and home:IsA("BillboardGui") and home.Adornee then
        local cf = getPartCFrame(home.Adornee)
        if cf then return cf end
    end
    for _, g in ipairs(PlayerGui:GetChildren()) do
        if g:IsA("BillboardGui") and g.Adornee and (g.Name:find("LootboxTimer_", 1, true) or g.Name:find("EggTimer_", 1, true)) then
            local cf = getPartCFrame(g.Adornee)
            if cf then return cf end
        end
    end
    local pbi = PlayerGui:FindFirstChild("PlayerBaseIndicator")
    if pbi and pbi:IsA("BillboardGui") and pbi.Adornee then return getPartCFrame(pbi.Adornee) end
    return nil
end

local function auctionTarget()
    local dot = PlayerGui:FindFirstChild("IndicatorDotBgui_AuctionHousePart")
    if dot and dot:IsA("BillboardGui") and dot.Adornee then
        local cf = getPartCFrame(dot.Adornee)
        if cf then return cf, dot.Adornee end
    end
    for _, inst in ipairs(CollectionService:GetTagged("AuctionHouse")) do
        local cf = getPartCFrame(inst)
        if cf then return cf, inst end
    end
    local mod = loadConfig("AuctionHouseConfig")
    if mod and mod.Guide and mod.Guide.Position then return CFrame.new(mod.Guide.Position), nil end
    return nil, nil
end

local function equipTool(name)
    local char = LocalPlayer.Character
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not (char and bp) then return end
    local tool = bp:FindFirstChild(name)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if tool and tool:IsA("Tool") and hum then
        pcall(function() hum:EquipTool(tool) end)
        task.wait(0.15)
    end
end

---------------------------------------------------------------------
-- Fonctionnalité : collecte d'argent
---------------------------------------------------------------------
local Status = { collect = "En attente", auction = "En attente", lastAction = "" }
local Cash = { busy = false, session = nil }

local function slotKeys()
    local out = {}
    for k in pairs(getState().baseSlots or {}) do out[#out + 1] = k end
    table.sort(out, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
    return out
end

local CollectRunners = {
    function() invoke("RequestCollectCash") end,
    function() for _, k in ipairs(slotKeys()) do invoke("RequestCollectCash", tonumber(k) or k) end end,
    function() for _, k in ipairs(slotKeys()) do invoke("RequestCollectCash", tostring(k)) end end,
}

local function ensureCollectVariant()
    if Learned.CollectCash and CollectRunners[Learned.CollectCash] then return Learned.CollectCash end
    Status.collect = "Apprentissage de la méthode de collecte…"
    local m0 = moneyNow()
    task.wait(1.5)
    local passive = math.max(0, moneyNow() - m0) -- gain passif mesuré sur 1,5 s
    for i, run in ipairs(CollectRunners) do
        if not alive() then return nil end
        local a = moneyNow()
        run()
        task.wait(1.5)
        if moneyNow() - a > passive * 2 + 1 then
            Learned.CollectCash = i
            saveSettings()
            log("✔ Collecte: méthode #" .. i .. " validée")
            return i
        end
    end
    log("Collecte: aucun gain mesurable, méthode #1 utilisée par défaut (relance l'apprentissage via Réglages si besoin)")
    return 1
end

local function collectCash()
    if Cash.busy then return end
    Cash.busy = true
    local ok, err = pcall(function()
        local v = Cash.session or ensureCollectVariant()
        Cash.session = v
        if v then
            CollectRunners[v]()
            Status.collect = "Méthode #" .. v .. " • dernière collecte " .. os.date("%H:%M:%S")
        end
    end)
    Cash.busy = false
    if not ok then log("Collecte:", err) end
end

---------------------------------------------------------------------
-- Fonctionnalité : achats (œufs, boîtes, caisse déco)
---------------------------------------------------------------------
local SKIP_ITEMS = { MythicEgg = true }

local function buyShopSlots(itemsKey, soldKey, remoteName, skip)
    local s = getState()
    for slot = 1, 3 do
        if not alive() then return end
        local name = at(s[itemsKey], slot)
        if name and at(s[soldKey], slot) ~= true and not (skip and skip[name]) then
            probe(remoteName, remoteName, {
                function() return { slot } end,
                function() return { name } end,
                function() return { slot, name } end,
                function() return { { Slot = slot } } end,
            }, function()
                local ss = getState()
                return { sold = at(ss[soldKey], slot) == true, stack = stackOf(ss, name) }
            end, function(b, a)
                return (a.sold and not b.sold) or a.stack > b.stack
            end)
            task.wait(0.25)
        end
    end
end

local function buyDecoCrate()
    local id = "FunctionalObjectsCrate"
    local function stock() return tonumber((getState().decorationsStoreStock or {})[id]) or 0 end
    if stock() <= 0 then return end
    probe("BuyDecorationsStoreItem", "BuyDecorationsStoreItem", {
        function() return { id } end,
        function() return { id, 1 } end,
        function() return { { ItemId = id } } end,
    }, function()
        return { stock = stock(), stack = stackOf(getState(), id) }
    end, function(b, a)
        return a.stock < b.stock or a.stack > b.stack
    end)
end

---------------------------------------------------------------------
-- Fonctionnalité : placement / ouverture
---------------------------------------------------------------------
local RarityScore = {
    MythicFloatCrate = 100, OceanEgg = 90, LegendaryFloatCrate = 80, EpicFloatCrate = 70,
    ForestEgg = 60, RareFloatCrate = 50, FarmEgg = 40, CommonFloatCrate = 30,
    FunctionalObjectsCrate = 25, CatFloatCrate = 20,
}

local function placementLimit(s)
    local level = s.placementLimitLevel or 0
    local mod = loadConfig("PlacementLimitConfig")
    if mod then
        if type(mod.GetLimit) == "function" then
            local ok, v = pcall(mod.GetLimit, level)
            if ok and type(v) == "number" and v >= 1 then return v end
            ok, v = pcall(mod.GetLimit, s)
            if ok and type(v) == "number" and v >= 1 then return v end
        end
        if tonumber(mod.BaseLimit) then return mod.BaseLimit + level end
    end
    return 3 + level
end

local function placedCount(s)
    return countKeys(s.placedEggs) + countKeys(s.placedLootboxes)
end

local function freeSlotIndex(s, limit)
    local used = {}
    for _, group in ipairs({ s.placedEggs or {}, s.placedLootboxes or {} }) do
        for _, d in pairs(group) do
            if type(d) == "table" then
                for _, k in ipairs({ "Slot", "slot", "Index", "index", "Stand", "stand", "Spot", "spot" }) do
                    local v = tonumber(d[k])
                    if v then used[v] = true end
                end
            end
        end
    end
    for i = 1, limit do if not used[i] then return i end end
    return placedCount(s) + 1
end

local function pickCandidate(s)
    local list = {}
    for key, item in pairs(s.inventory or {}) do
        if type(item) == "table" and (tonumber(item.Stack) or 0) > 0 then
            local name = item.ConfigName or tostring(key)
            if item.Category == "Egg" and not SKIP_ITEMS[name] then
                list[#list + 1] = { Name = name, Type = "Egg", Score = RarityScore[name] or 35 }
            elseif item.Category == "FloatLootbox" then
                list[#list + 1] = { Name = name, Type = "Box", Score = RarityScore[name] or 25 }
            end
        end
    end
    if #list == 0 then return nil end
    local prio = Config.OpenPriority
    table.sort(list, function(a, b)
        if prio == "EggsFirst" and a.Type ~= b.Type then return a.Type == "Egg" end
        if prio == "BoxesFirst" and a.Type ~= b.Type then return a.Type == "Box" end
        if a.Score ~= b.Score then return a.Score > b.Score end
        return a.Name < b.Name
    end)
    return list[1]
end

local Place = { last = 0 }
local function placeOne()
    if os.clock() - Place.last < 2 then return false end
    local s = getState()
    local limit = placementLimit(s)
    if placedCount(s) >= limit then return false end
    local cand = pickCandidate(s)
    if not cand then return false end
    Place.last = os.clock()

    local name = cand.Name
    local slot = freeSlotIndex(s, limit)
    local remoteName = cand.Type == "Egg" and "PlaceEgg" or "PlaceFloatLootbox"
    local baseCF = getBaseCFrame()
    equipTool(name)

    local variants = {
        function() return { name } end,
        function() return { name, slot } end,
        function() return { slot, name } end,
        function() return { { ConfigName = name, Slot = slot } } end,
        function() return baseCF and { name, baseCF } or nil end,
    }
    local function snap()
        local ss = getState()
        return { n = placedCount(ss), stack = stackOf(ss, name) }
    end
    local function changed(b, a) return a.n > b.n or a.stack < b.stack end

    local ok = probe(remoteName, remoteName, variants, snap, changed, { cooldown = 0 })
    if not ok and Config.AllowTeleport and baseCF then
        ok = withTeleport(baseCF, 15, function()
            return (probe(remoteName, remoteName, variants, snap, changed))
        end)
    end
    if ok then Status.lastAction = "Placé: " .. name end
    return ok
end

-- Timers ---------------------------------------------------------------
local function parseTimerText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local low = text:lower()
    local a, b, c = low:match("(%d+):(%d+):(%d+)")
    if a then return tonumber(a) * 3600 + tonumber(b) * 60 + tonumber(c) end
    a, b = low:match("(%d+):(%d+)")
    if a then return tonumber(a) * 60 + tonumber(b) end
    local total, found = 0, false
    for n, unit in low:gmatch("(%d+)%s*([dhms])%f[%A]") do
        found = true
        n = tonumber(n)
        if unit == "d" then total += n * 86400
        elseif unit == "h" then total += n * 3600
        elseif unit == "m" then total += n * 60
        else total += n end
    end
    if found then return total end
    if low:find("ready") or low:find("open") or low:find("claim") or low:find("hatch") or low:find("done") then
        return 0
    end
    return nil
end

local function guiRemaining(prefixes, id)
    for _, prefix in ipairs(prefixes) do
        local gui = PlayerGui:FindFirstChild(prefix .. tostring(id))
        if gui then
            local positive, zero = nil, false
            for _, d in ipairs(gui:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then
                    local sec = parseTimerText(d.Text)
                    if sec then
                        if sec > 0 then positive = math.min(positive or math.huge, sec) else zero = true end
                    end
                end
            end
            if positive then return positive end
            if zero then return 0 end
            return nil
        end
    end
    return nil
end

local END_KEYS = { "readyat", "endtime", "endsat", "endat", "finishat", "finishtime", "finishedat",
    "opensat", "openat", "hatchat", "completeat", "completedat", "unlockat", "expiresat", "readytime" }
local REMAIN_KEYS = { "remaining", "timeleft", "secondsleft" }
local START_KEYS = { "startedat", "starttime", "placedat", "placetime", "createdat" }
local DURATION_KEYS = { "duration", "hatchduration", "opentime", "hatchtime", "seconds" }

local function matchAny(key, list)
    for _, p in ipairs(list) do if key:find(p, 1, true) then return true end end
    return false
end

local function normalizeTs(v)
    if v > 1e11 then v = v / 1000 end
    if v > 1.5e9 and v < 3e9 then return v end
    return nil
end

-- Retourne true / false / nil (inconnu) à partir des données d'état de l'item placé.
local function readyFromData(data)
    if type(data) ~= "table" then return nil end
    if data.Ready == true or data.ready == true or data.isReady == true then return true end
    local endAt, remaining, startAt, duration
    for k, v in pairs(data) do
        if type(k) == "string" and type(v) == "number" then
            local lk = k:lower()
            if matchAny(lk, END_KEYS) then endAt = endAt or normalizeTs(v)
            elseif matchAny(lk, REMAIN_KEYS) then remaining = v
            elseif matchAny(lk, START_KEYS) then startAt = startAt or normalizeTs(v)
            elseif matchAny(lk, DURATION_KEYS) then duration = v end
        end
    end
    if endAt then return serverNow() >= endAt end
    if startAt and duration then return serverNow() >= startAt + duration end
    if remaining and remaining <= 0 then return true end
    return nil
end

local function isReady(kind, id, data)
    local prefixes = (kind == "Egg") and { "EggTimer_", "Timer_" } or { "LootboxTimer_", "Timer_" }
    local sec = guiRemaining(prefixes, id)
    if sec ~= nil then return sec <= 0 end
    return readyFromData(data)
end

local function promptFallback(kind, id)
    if not Config.AllowTeleport then return false end
    local gui = PlayerGui:FindFirstChild((kind == "Egg" and "EggTimer_" or "LootboxTimer_") .. tostring(id))
    local ad = gui and gui:IsA("BillboardGui") and gui.Adornee
    if not ad then return false end
    local root = ad:FindFirstAncestorOfClass("Model") or ad
    local cf = getPartCFrame(ad)
    return withTeleport(cf, 12, function()
        local fired = false
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local act = tostring(d.ActionText):lower()
                if act:find("open") or act:find("hatch") or act:find("claim") then
                    triggerPrompt(d)
                    fired = true
                    task.wait(0.1)
                end
            end
        end
        return fired
    end)
end

local lastTry, tryCount = {}, {}
local function openPlaced(kind, id)
    local remoteName = (kind == "Egg") and "HatchEgg" or "OpenFloatLootbox"
    local groupKey = (kind == "Egg") and "placedEggs" or "placedLootboxes"

    local function snap()
        local d = (getState()[groupKey] or {})[id]
        return { exists = d ~= nil, sig = d ~= nil and deepSig(d, 2) or "" }
    end
    local function changed(b, a)
        return (b.exists and not a.exists) or (a.exists and a.sig ~= b.sig)
    end

    local ok = probe(remoteName, remoteName, {
        function() return { id } end,
        function() return { { Id = id } } end,
        function() return { { id = id } } end,
    }, snap, changed, { cooldown = 0 })

    tryCount[id] = (tryCount[id] or 0) + 1
    if not ok and tryCount[id] >= 2 then ok = promptFallback(kind, id) end

    if kind == "Box" and (ok or tryCount[id] % 2 == 0) then
        invoke("ClaimFloatLootboxReward", id)
    end
    if ok then
        tryCount[id] = nil
        Status.lastAction = (kind == "Egg" and "Éclos: " or "Ouvert: ") .. tostring(id):sub(1, 8)
    end
    return ok
end

local function processOpen(force)
    local s = getState()
    for kind, key in pairs({ Egg = "placedEggs", Box = "placedLootboxes" }) do
        for id in pairs(s[key] or {}) do
            if not alive() then return end
            local data = s[key][id]
            local ready = isReady(kind, id, data)
            if ready ~= false then
                -- prêt : on réessaie toutes les 6 s ; indéterminé : toutes les 45 s (3 s si bouton manuel)
                local interval = (ready == true) and 6 or (force and 3 or 45)
                if os.clock() - (lastTry[id] or -1e9) >= interval then
                    lastTry[id] = os.clock()
                    openPlaced(kind, id)
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Fonctionnalité : Auction House (achat direct)
---------------------------------------------------------------------
local Auction = { busy = false, last = 0, lastTp = -1e9 }

local function auctionSnap()
    local s = getState()
    return table.concat({
        deepSig(s.auctionPurchases, 3), deepSig(s.auctionEscrow, 2),
        tostring(s.gems), tostring(totalStacks(s)),
    }, "#")
end

local function buyAuctionSlot(slot)
    return probe("AuctionBuy", "AuctionBuy", {
        function() return { slot } end,
        function() return { { Slot = slot } } end,
        function() return { slot, 1 } end,
        function() return { tostring(slot) } end,
    }, auctionSnap, function(b, a) return a ~= b end, { cooldown = 0 })
end

local function auctionPass(force)
    local bought = 0
    for slot = 1, 6 do
        for _ = 1, 5 do
            if not alive() or not (force or Config.AutoBuyAuction) then return bought end
            if buyAuctionSlot(slot) then bought += 1 task.wait(0.4) else break end
        end
    end
    return bought
end

local function buyAuction(force)
    if Auction.busy then return end
    Auction.busy = true
    Auction.last = os.clock()
    local ok, err = pcall(function()
        invoke("GetAuctionHouseState")
        task.wait(0.3)
        local needsTp = Learned.AuctionNeedsTp == true
        local got = 0
        local cf, inst = auctionTarget()

        local function pass()
            if inst then
                local prompts = inst:IsA("ProximityPrompt") and { inst } or {}
                if #prompts == 0 then
                    for _, d in ipairs(inst:GetDescendants()) do
                        if d:IsA("ProximityPrompt") then prompts[#prompts + 1] = d end
                    end
                end
                for _, p in ipairs(prompts) do triggerPrompt(p) end
                task.wait(0.3)
            end
            return auctionPass(force)
        end

        if needsTp and Config.AllowTeleport and cf then
            got = withTeleport(cf, 10, pass) or 0
        else
            got = auctionPass(force)
            local canTp = Config.AllowTeleport and cf and Learned.AuctionBuy == nil
                and (os.clock() - Auction.lastTp > 600)
            if got == 0 and canTp then
                Auction.lastTp = os.clock()
                got = withTeleport(cf, 10, pass) or 0
                if got > 0 then Learned.AuctionNeedsTp = true saveSettings() end
            end
        end
        Status.auction = string.format("%s • %d achat(s)", os.date("%H:%M:%S"), got)
    end)
    Auction.busy = false
    if not ok then log("Auction:", err) end
end

---------------------------------------------------------------------
-- Diagnostic
---------------------------------------------------------------------
local function runDiagnostic()
    local s = getState()
    print("[Sakura] ================= DIAGNOSTIC =================")
    printDump("Variantes apprises", Config.Learned, 2, 40)
    printDump("Modes des remotes", Config.Modes, 2, 40)
    print("[Sakura] Limite de placement:", placementLimit(s), "| placés:", placedCount(s))
    for kind, key in pairs({ Egg = "placedEggs", Box = "placedLootboxes" }) do
        for id, data in pairs(s[key] or {}) do
            local prefixes = (kind == "Egg") and { "EggTimer_" } or { "LootboxTimer_" }
            print(string.format("[Sakura] %s %s | prêt(gui)=%s | prêt(data)=%s",
                kind, tostring(id), tostring(guiRemaining(prefixes, id)), tostring(readyFromData(data))))
            printDump("données " .. tostring(id), data, 2, 30)
        end
    end
    task.spawn(function()
        local ok, a, b = invoke("GetAuctionHouseState")
        print("[Sakura] GetAuctionHouseState ok =", ok, "mode =", remoteMode.GetAuctionHouseState)
        if ok then
            printDump("Auction retour #1", a, 4, 120)
            printDump("Auction retour #2", b, 4, 120)
        end
        print("[Sakura] ================= FIN DIAGNOSTIC =================")
    end)
    log("Diagnostic envoyé dans la console (F9)")
end

---------------------------------------------------------------------
-- Anti-AFK
---------------------------------------------------------------------
track(LocalPlayer.Idled:Connect(function()
    if not alive() or not Config.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local Theme = {
    Background = Color3.fromRGB(18, 14, 22), Sidebar = Color3.fromRGB(24, 18, 28),
    Card = Color3.fromRGB(28, 21, 33), CardSub = Color3.fromRGB(38, 28, 45),
    CardActive = Color3.fromRGB(50, 36, 60), Accent = Color3.fromRGB(255, 107, 139),
    AccentSoft = Color3.fromRGB(255, 180, 200), Text = Color3.fromRGB(255, 245, 248),
    TextDim = Color3.fromRGB(200, 168, 185), Green = Color3.fromRGB(115, 230, 155),
    Red = Color3.fromRGB(255, 95, 120), StrokeSub = Color3.fromRGB(60, 44, 68),
}

local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(inst, r) return new("UICorner", { CornerRadius = UDim.new(0, r) }, inst) end
local function stroke(inst, color, thickness, transparency)
    return new("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0 }, inst)
end

ScreenGui = new("ScreenGui", {
    Name = GUI_NAME, ResetOnSpawn = false, DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
pcall(function() ScreenGui.Parent = guiRoot() end)
if not ScreenGui.Parent then ScreenGui.Parent = PlayerGui end

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
local WIN_W = math.clamp(vp.X - 24, 340, 620)
local WIN_H = math.clamp(vp.Y - 24, 290, 430)
local SIDE_W = WIN_W < 480 and 96 or 130

local Main = new("Frame", {
    Name = "SakuraMain", AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2), Size = UDim2.fromOffset(WIN_W, WIN_H),
    BackgroundColor3 = Theme.Background, BorderSizePixel = 0, ClipsDescendants = true,
}, ScreenGui)
corner(Main, 14)
stroke(Main, Theme.Accent, 1.4)

local TopBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0, Active = true,
}, Main)
new("TextLabel", {
    Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
    Text = "🌸 SAKURA • Pull A Lucky Fish", Font = Enum.Font.GothamBold, TextSize = 13,
    TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, TopBar)

local function topButton(text, xOffset)
    local b = new("TextButton", {
        Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, xOffset, 0.5, -13),
        BackgroundColor3 = Theme.CardSub, Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = Theme.AccentSoft, AutoButtonColor = false,
    }, TopBar)
    corner(b, 6)
    return b
end
local CloseBtn = topButton("✕", -34)
local MinBtn = topButton("—", -66)

local FloatBtn = new("TextButton", {
    Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromOffset(40, vp.Y / 2), BackgroundColor3 = Theme.Background,
    Text = "🌸", TextSize = 22, Visible = false, Active = true, AutoButtonColor = false,
}, ScreenGui)
corner(FloatBtn, 23)
stroke(FloatBtn, Theme.Accent, 1.6)

local function makeDraggable(handle, target, onClick)
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart = input.Position
            startPos = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    c:Disconnect()
                    if not moved and onClick then onClick() end
                end
            end)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            local v = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or vp
            target.Position = UDim2.fromOffset(
                math.clamp(startPos.X + d.X, 30, v.X - 30),
                math.clamp(startPos.Y + d.Y, 30, v.Y - 30))
        end
    end))
end

local function setUIVisible(visible)
    Main.Visible = visible
    FloatBtn.Visible = not visible
end
makeDraggable(TopBar, Main)
makeDraggable(FloatBtn, FloatBtn, function() setUIVisible(true) end)
MinBtn.MouseButton1Click:Connect(function() setUIVisible(false) end)
CloseBtn.MouseButton1Click:Connect(shutdown)
track(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not alive() then return end
    if input.KeyCode == Enum.KeyCode.RightShift then setUIVisible(not Main.Visible) end
end))

-- Toast
local Toast = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(260, 30),
    BackgroundColor3 = Theme.CardActive, BorderSizePixel = 0, Visible = false, ZIndex = 20,
}, ScreenGui)
corner(Toast, 8)
stroke(Toast, Theme.Accent, 1)
local ToastLabel = new("TextLabel", {
    Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromOffset(5, 0), BackgroundTransparency = 1,
    Font = Enum.Font.GothamSemibold, TextSize = 11, TextColor3 = Theme.Text, ZIndex = 21, TextTruncate = Enum.TextTruncate.AtEnd,
}, Toast)
local toastToken = 0
local function notify(msg)
    toastToken += 1
    local mine = toastToken
    ToastLabel.Text = msg
    Toast.Visible = true
    task.delay(2, function()
        if toastToken == mine and Toast.Parent then Toast.Visible = false end
    end)
end

-- Sidebar / pages
local Sidebar = new("Frame", {
    Size = UDim2.new(0, SIDE_W, 1, -52), Position = UDim2.fromOffset(8, 46),
    BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0,
}, Main)
corner(Sidebar, 10)
new("UIListLayout", { Padding = UDim.new(0, 6) }, Sidebar)
new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, Sidebar)

local Container = new("Frame", {
    Size = UDim2.new(1, -(SIDE_W + 24), 1, -52), Position = UDim2.fromOffset(SIDE_W + 16, 46),
    BackgroundTransparency = 1,
}, Main)

local Pages, TabButtons = {}, {}
local function showTab(id)
    for tid, page in pairs(Pages) do
        local on = tid == id
        page.Visible = on
        local b = TabButtons[tid]
        b.btn.BackgroundColor3 = on and Theme.CardActive or Theme.Card
        b.btn.TextColor3 = on and Theme.AccentSoft or Theme.TextDim
        b.stroke.Transparency = on and 0 or 0.8
    end
end

local function createTab(id, title)
    local page = new("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = Theme.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Visible = false,
    }, Container)
    new("UIListLayout", { Padding = UDim.new(0, 8) }, page)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Theme.Card, Text = title,
        Font = Enum.Font.GothamSemibold, TextSize = 11, TextColor3 = Theme.TextDim, AutoButtonColor = false,
    }, Sidebar)
    corner(btn, 8)
    local st = stroke(btn, Theme.Accent, 0.8, 0.8)
    btn.MouseButton1Click:Connect(function() showTab(id) end)
    Pages[id] = page
    TabButtons[id] = { btn = btn, stroke = st }
    return page
end

local PageFarm = createTab("Farm", "💰 Farm")
local PageShop = createTab("Shop", "🛍️ Boutiques")
local PageOpen = createTab("Open", "⏳ Placer & Ouvrir")
local PageLogs = createTab("Logs", "📜 Logs")
local PageSettings = createTab("Settings", "⚙️ Réglages")

-- Composants
local function makeCard(parent, title)
    local card = new("Frame", {
        Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
    }, parent)
    corner(card, 10)
    stroke(card, Theme.StrokeSub, 0.8)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
    }, card)
    new("UIListLayout", { Padding = UDim.new(0, 6) }, card)
    if title then
        new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = string.upper(title),
            Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = Theme.AccentSoft,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, card)
    end
    return card
end

local function makeLabel(card, text, color, size, bold)
    return new("TextLabel", {
        Size = UDim2.new(1, 0, 0, size + 4), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1,
        Text = text, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham, TextSize = size,
        TextColor3 = color or Theme.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    }, card)
end

local function makeToggle(card, title, key, onChange)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, card)
    new("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = title, Font = Enum.Font.Gotham,
        TextSize = 11, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
    }, row)
    local trackBtn = new("TextButton", {
        Size = UDim2.fromOffset(40, 20), Position = UDim2.new(1, -40, 0.5, -10), Text = "", AutoButtonColor = false,
    }, row)
    corner(trackBtn, 10)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, trackBtn)
    corner(knob, 8)
    local function render(animate)
        local on = Config[key] == true
        local color = on and Theme.Accent or Theme.CardSub
        local pos = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        if animate then
            local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(trackBtn, info, { BackgroundColor3 = color }):Play()
            TweenService:Create(knob, info, { Position = pos }):Play()
        else
            trackBtn.BackgroundColor3 = color
            knob.Position = pos
        end
    end
    trackBtn.MouseButton1Click:Connect(function()
        Config[key] = not Config[key]
        render(true)
        saveSettings()
        notify(title .. " : " .. (Config[key] and "ON" or "OFF"))
        if onChange then task.spawn(onChange, Config[key]) end
    end)
    render(false)
end

local function makeButton(card, text, onClick)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.CardSub, Text = text,
        Font = Enum.Font.GothamSemibold, TextSize = 11, TextColor3 = Theme.Text, AutoButtonColor = false,
    }, card)
    corner(btn, 8)
    local st = stroke(btn, Theme.Accent, 0.8, 0.6)
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.CardActive }):Play()
        st.Transparency = 0.2
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = Theme.CardSub }):Play()
        st.Transparency = 0.6
    end)
    btn.MouseButton1Click:Connect(function() task.spawn(onClick) end)
    return btn
end

local function makeSegment(card, options, get, set)
    local row = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 }, card)
    new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, row)
    local n, pad = #options, 4
    local buttons = {}
    local function refresh()
        for id, b in pairs(buttons) do
            local on = get() == id
            b.BackgroundColor3 = on and Theme.Accent or Theme.CardSub
            b.TextColor3 = on and Theme.Background or Theme.Text
        end
    end
    for i, opt in ipairs(options) do
        local b = new("TextButton", {
            Size = UDim2.new(1 / n, -(pad * (n - 1)) / n, 1, 0), LayoutOrder = i, Text = opt.label,
            Font = Enum.Font.GothamSemibold, TextSize = 10, AutoButtonColor = false, BackgroundColor3 = Theme.CardSub,
            TextColor3 = Theme.Text,
        }, row)
        corner(b, 7)
        b.MouseButton1Click:Connect(function() set(opt.id) refresh() end)
        buttons[opt.id] = b
    end
    refresh()
end

-- Page Farm
local BalanceCard = makeCard(PageFarm, "Solde en direct")
local BalLabel = makeLabel(BalanceCard, "💰 Cash : …", Theme.Green, 13, true)
local StatsLabel = makeLabel(BalanceCard, "", Theme.TextDim, 10)

local CashCard = makeCard(PageFarm, "Collecte automatique")
makeToggle(CashCard, "Auto-collecte du cash", "AutoCollectCash")
makeSegment(CashCard, {
    { id = 3, label = "toutes les 3 s" }, { id = 5, label = "5 s" }, { id = 10, label = "10 s" },
}, function() return Config.CollectInterval end, function(v) Config.CollectInterval = v saveSettings() end)
local CollectStatus = makeLabel(CashCard, "", Theme.TextDim, 10)
makeButton(CashCard, "⚡ Collecter maintenant", function()
    collectCash()
    notify("Collecte envoyée")
end)

-- Page Boutiques
local EggCard = makeCard(PageShop, "Boutique d'œufs (ignore MythicEgg)")
makeToggle(EggCard, "Auto-achat des œufs en stock", "AutoBuyEggs")
local EggLabel = makeLabel(EggCard, "", Theme.TextDim, 10)

local BoxCard = makeCard(PageShop, "Boutique de caisses flottantes")
makeToggle(BoxCard, "Auto-achat des caisses en stock", "AutoBuyBoxes")
local BoxLabel = makeLabel(BoxCard, "", Theme.TextDim, 10)

local DecoCard = makeCard(PageShop, "Boutique déco")
makeToggle(DecoCard, "Auto-achat des Functional Objects Crate", "AutoBuyDecoCrate")
local DecoLabel = makeLabel(DecoCard, "", Theme.TextDim, 10)

local AuctionCard = makeCard(PageShop, "Auction House (achat direct, sans enchères)")
makeToggle(AuctionCard, "Auto-achat toutes les 60 s", "AutoBuyAuction", function(v)
    if v then buyAuction(false) end
end)
local AuctionLabel = makeLabel(AuctionCard, "", Theme.TextDim, 10)
makeButton(AuctionCard, "⚡ Acheter maintenant", function()
    notify("Tentative d'achat Auction House…")
    buyAuction(true)
end)

-- Page Placer & Ouvrir
local AutoCard = makeCard(PageOpen, "Automatisation")
makeToggle(AutoCard, "Auto-placer (vérifie la place disponible)", "AutoPlace")
makeToggle(AutoCard, "Auto-ouvrir / éclore (timer terminé)", "AutoOpen")
local SlotLabel = makeLabel(AutoCard, "", Theme.Green, 11, true)
local TimerLabel = makeLabel(AutoCard, "", Theme.TextDim, 10)
local ActionLabel = makeLabel(AutoCard, "", Theme.TextDim, 10)
makeButton(AutoCard, "⚡ Ouvrir les items prêts maintenant", function()
    processOpen(true)
    notify("Items prêts traités")
end)

local PrioCard = makeCard(PageOpen, "Priorité de placement")
makeSegment(PrioCard, {
    { id = "HighTierFirst", label = "⭐ Rareté" },
    { id = "EggsFirst", label = "🥚 Œufs" },
    { id = "BoxesFirst", label = "📦 Caisses" },
}, function() return Config.OpenPriority end, function(v) Config.OpenPriority = v saveSettings() end)

-- Page Logs
local LogCard = makeCard(PageLogs, "Journal (récent en haut)")
local LogLabel = makeLabel(LogCard, "", Theme.TextDim, 10)
onLog = function()
    local out = {}
    for i = #logLines, 1, -1 do out[#out + 1] = logLines[i] end
    LogLabel.Text = table.concat(out, "\n")
end

-- Page Réglages
local PrefCard = makeCard(PageSettings, "Préférences")
makeToggle(PrefCard, "Anti-AFK", "AntiAFK")
makeToggle(PrefCard, "Autoriser la téléportation (secours placement / auction)", "AllowTeleport")
makeButton(PrefCard, "💾 Sauvegarder les réglages", function()
    saveSettings()
    notify("Sauvegardé dans " .. CONFIG_FILE)
end)

local ToolCard = makeCard(PageSettings, "Outils")
makeButton(ToolCard, "🔄 Réinitialiser l'apprentissage des remotes", function()
    table.clear(Learned)
    table.clear(remoteMode)
    table.clear(failures)
    table.clear(cooldownUntil)
    Cash.session = nil
    saveSettings()
    log("Apprentissage réinitialisé")
    notify("Apprentissage réinitialisé")
end)
makeButton(ToolCard, "📋 Diagnostic (console F9)", runDiagnostic)
makeButton(ToolCard, "🛑 Décharger le script", shutdown)

---------------------------------------------------------------------
-- Rafraîchissement de l'UI
---------------------------------------------------------------------
local function restockText(windowKey, cfgName)
    local s = getState()
    local w = tonumber(s[windowKey])
    if not w then return "?" end
    local mod = loadConfig(cfgName)
    local interval = (mod and tonumber(mod.ShopRefreshInterval or mod.RestockInterval)) or 1200
    local left = math.max(0, math.floor((w + interval) - serverNow()))
    return string.format("%d:%02d", left // 60, left % 60)
end

local function shopText(s, itemsKey, soldKey)
    local parts = {}
    for i = 1, 3 do
        parts[#parts + 1] = string.format("#%d %s (%s)", i, tostring(at(s[itemsKey], i) or "-"),
            at(s[soldKey], i) == true and "vendu" or "dispo")
    end
    return table.concat(parts, " | ")
end

local function refreshUI()
    local s = getState()
    BalLabel.Text = string.format("💰 %s   💎 %s", formatNumber(s.money), formatNumber(s.gems))
    local stats = s.stats or {}
    StatsLabel.Text = string.format("Poissons pêchés : %s • Rebirth : %s", formatNumber(stats.fishCaught), tostring(s.rebirthLevel or 0))
    CollectStatus.Text = Status.collect

    EggLabel.Text = shopText(s, "eggShopItems", "eggShopSoldSlots") .. "\nRestock dans " .. restockText("eggShopWindow", "EggConfig")
    BoxLabel.Text = shopText(s, "lootboxShopItems", "lootboxShopSoldSlots") .. "\nRestock dans " .. restockText("lootboxShopWindow", "FloatLootboxConfig")
    DecoLabel.Text = string.format("Stock : %s • Restock dans %s",
        tostring((s.decorationsStoreStock or {}).FunctionalObjectsCrate or 0), restockText("decorationsStoreWindow", "DecorationsStoreConfig"))
    AuctionLabel.Text = Status.auction

    local count, limit = placedCount(s), placementLimit(s)
    if count < limit then
        SlotLabel.Text = string.format("Emplacements : %d / %d  ✔ (%d libres)", count, limit, limit - count)
        SlotLabel.TextColor3 = Theme.Green
    else
        SlotLabel.Text = string.format("Emplacements : %d / %d  ⛔ complet", count, limit)
        SlotLabel.TextColor3 = Theme.Red
    end

    local ready, running_, unknown = 0, 0, 0
    for kind, key in pairs({ Egg = "placedEggs", Box = "placedLootboxes" }) do
        for id, data in pairs(s[key] or {}) do
            local r = isReady(kind, id, data)
            if r == true then ready += 1 elseif r == false then running_ += 1 else unknown += 1 end
        end
    end
    TimerLabel.Text = string.format("Timers : %d en cours • %d prêts • %d indéterminés", running_, ready, unknown)
    ActionLabel.Text = Status.lastAction ~= "" and ("Dernière action : " .. Status.lastAction) or ""
end

---------------------------------------------------------------------
-- Boucles (une par fonctionnalité, isolées par pcall)
---------------------------------------------------------------------
local function startLoop(name, interval, fn)
    task.spawn(function()
        local fails = 0
        while alive() do
            local ok, err = pcall(fn)
            if ok then
                fails = 0
            else
                fails += 1
                log("⚠ " .. name .. " : " .. tostring(err))
                task.wait(math.min(30, 2 ^ fails))
            end
            task.wait(type(interval) == "function" and interval() or interval)
        end
    end)
end

startLoop("Collecte", function() return math.max(2, Config.CollectInterval) end, function()
    if Config.AutoCollectCash then collectCash() end
end)

startLoop("Boutiques", 2, function()
    if Config.AutoBuyEggs then buyShopSlots("eggShopItems", "eggShopSoldSlots", "BuyEgg", SKIP_ITEMS) end
    if Config.AutoBuyBoxes then buyShopSlots("lootboxShopItems", "lootboxShopSoldSlots", "BuyFloatLootbox") end
    if Config.AutoBuyDecoCrate then buyDecoCrate() end
end)

startLoop("Placement/Ouverture", 1.5, function()
    if Config.AutoOpen then processOpen(false) end
    if Config.AutoPlace then placeOne() end
end)

startLoop("Auction", 5, function()
    if Config.AutoBuyAuction and os.clock() - Auction.last >= 60 then buyAuction(false) end
end)

startLoop("Interface", 1, refreshUI)

showTab("Farm")
log("Sakura v2 chargé — RightShift pour afficher/masquer")
