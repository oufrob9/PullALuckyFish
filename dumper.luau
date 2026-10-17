local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MarketPlaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

_G.__LUMEN_DUMPER = (_G.__LUMEN_DUMPER or 0) + 1
local CURRENT_SESSION = _G.__LUMEN_DUMPER

local isRunning = true
local connections = {}

local function cleanShutdown()
    if not isRunning then return end
    isRunning = false
    _G.__LUMEN_DUMPER = (_G.__LUMEN_DUMPER or 0) + 1
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(connections)
    local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
    local oldGui = targetParent and targetParent:FindFirstChild("LumenGameDumper_UI")
    if oldGui then
        oldGui:Destroy()
    end
end

local function getExecutorName()
    local name = "Unknown Executor"
    pcall(function()
        if identifyexecutor then
            name = identifyexecutor()
        elseif getexecutorname then
            name = getexecutorname()
        end
    end)
    return name
end

local function getGameTitle()
    local title = "Game_" .. tostring(game.PlaceId)
    pcall(function()
        local info = MarketPlaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then
            title = info.Name
        end
    end)
    return title
end

local function sanitizeFilename(str)
    return (str:gsub("[%s%p%c]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

local function formatBytes(bytes)
    bytes = tonumber(bytes) or 0
    if bytes < 1024 then
        return string.format("%d B", bytes)
    elseif bytes < 1024 * 1024 then
        return string.format("%.2f KB", bytes / 1024)
    else
        return string.format("%.2f MB", bytes / (1024 * 1024))
    end
end

local function getInstancePath(inst)
    if not inst then return "nil" end
    local parts = {}
    local curr = inst
    while curr and curr ~= game do
        table.insert(parts, 1, curr.Name)
        curr = curr.Parent
    end
    return table.concat(parts, ".")
end

local function serializeValue(val, depth, visited, maxDepth)
    depth = depth or 0
    maxDepth = maxDepth or 5
    visited = visited or {}

    local valType = typeof(val)
    if val == nil then
        return "nil"
    elseif valType == "string" then
        return string.format("%q", val)
    elseif valType == "number" or valType == "boolean" then
        return tostring(val)
    elseif valType == "Vector2" then
        return string.format("Vector2.new(%.2f, %.2f)", val.X, val.Y)
    elseif valType == "Vector3" then
        return string.format("Vector3.new(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif valType == "CFrame" then
        local x, y, z = val.Position.X, val.Position.Y, val.Position.Z
        return string.format("CFrame.new(%.2f, %.2f, %.2f)", x, y, z)
    elseif valType == "Color3" then
        return string.format("Color3.fromRGB(%d, %d, %d)", math.floor(val.R * 255), math.floor(val.G * 255), math.floor(val.B * 255))
    elseif valType == "BrickColor" then
        return string.format("BrickColor.new(%q)", val.Name)
    elseif valType == "EnumItem" then
        return tostring(val)
    elseif valType == "Instance" then
        return string.format("Instance(%s: %s)", val.ClassName, getInstancePath(val))
    elseif valType == "function" then
        local info = nil
        pcall(function()
            if debug and debug.info then
                local a, b = debug.info(val, "na")
                info = (a and a ~= "" and a) or (b and "args:" .. tostring(b)) or nil
            end
        end)
        return info and string.format("[function: %s]", info) or "[function]"
    elseif valType == "table" then
        if visited[val] then
            return string.format("[CircularReference %s]", tostring(val))
        end
        if depth >= maxDepth then
            local count = 0
            for _ in pairs(val) do count = count + 1 end
            return string.format("{ ... %d keys }", count)
        end

        visited[val] = true
        local isArray = true
        local maxIdx = 0
        local keyCount = 0
        for k, _ in pairs(val) do
            keyCount = keyCount + 1
            if type(k) == "number" and k > 0 and math.floor(k) == k then
                if k > maxIdx then maxIdx = k end
            else
                isArray = false
            end
        end
        if isArray and maxIdx == keyCount and keyCount > 0 then
            local items = {}
            local indent = string.rep("  ", depth + 1)
            for i = 1, maxIdx do
                table.insert(items, indent .. serializeValue(val[i], depth + 1, visited, maxDepth))
            end
            visited[val] = nil
            if keyCount <= 4 and not string.find(table.concat(items, ""), "\n") then
                local inline = {}
                for i = 1, maxIdx do table.insert(inline, serializeValue(val[i], depth + 1, visited, maxDepth)) end
                return "{ " .. table.concat(inline, ", ") .. " }"
            end
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. string.rep("  ", depth) .. "}"
        else
            local sortedKeys = {}
            for k in pairs(val) do table.insert(sortedKeys, k) end
            table.sort(sortedKeys, function(a, b) return tostring(a) < tostring(b) end)

            local entries = {}
            local indent = string.rep("  ", depth + 1)
            for _, k in ipairs(sortedKeys) do
                local formattedKey = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or string.format("[%s]", serializeValue(k, depth + 1, visited, maxDepth))
                local formattedVal = serializeValue(val[k], depth + 1, visited, maxDepth)
                table.insert(entries, string.format("%s%s = %s", indent, formattedKey, formattedVal))
            end
            visited[val] = nil
            if keyCount == 0 then return "{}" end
            return "{\n" .. table.concat(entries, ",\n") .. "\n" .. string.rep("  ", depth) .. "}"
        end
    end
    return tostring(val)
end

local function safeRequire(mod)
    if not mod or not mod:IsA("ModuleScript") then return false, nil end
    local ok, res = pcall(function()
        return require(mod)
    end)
    return ok, res
end

local function generateFullGameDump(onProgress)
    local lines = {}
    local function add(text)
        table.insert(lines, text or "")
    end
    local function addHeader(title)
        add("")
        add("================================================================================")
        add("  " .. string.upper(title))
        add("================================================================================")
        add("")
    end

    local stats = {
        Remotes = 0,
        Modules = 0,
        Configs = 0,
        States = 0,
        WorkspaceObjects = 0,
        TaggedObjects = 0,
        TotalLines = 0,
        FileSize = 0,
        FilePath = ""
    }

    if onProgress then onProgress("Starting full game introspection...", 0.05) end

    local gameTitle = getGameTitle()
    local execName = getExecutorName()
    local timestamp = os.date("!%Y-%m-%d %H:%M:%S UTC")

    add("================================================================================")
    add(string.format("  LUMEN FULL GAME INTROSPECTION DUMP: %s", gameTitle))
    add(string.format("  Generated: %s | Executor: %s", timestamp, execName))
    add("================================================================================")
    add("")
    add(string.format("PlaceId       : %d", game.PlaceId))
    add(string.format("JobId         : %s", game.JobId ~= "" and game.JobId or "SinglePlayer/Local"))
    add(string.format("GameId        : %d", game.GameId))
    add(string.format("PlaceVersion  : %d", game.PlaceVersion))
    add(string.format("ServerTimeNow : %.2f", (workspace:GetServerTimeNow() or os.time())))
    add(string.format("LocalPlayer   : %s (DisplayName: %s, UserId: %d, AccountAge: %d days)", LocalPlayer.Name, LocalPlayer.DisplayName, LocalPlayer.UserId, LocalPlayer.AccountAge))

    if onProgress then onProgress("Scanning Network & Remote Events...", 0.15) end
    addHeader("1. NETWORK & REMOTE INSTANCES")

    local remoteTypes = {
        ["RemoteEvent"] = true,
        ["RemoteFunction"] = true,
        ["UnreliableRemoteEvent"] = true,
        ["BindableEvent"] = true,
        ["BindableFunction"] = true
    }

    local foundRemotes = {}
    local servicesToScan = { ReplicatedStorage, Workspace, Lighting, Players, game:GetService("StarterGui"), game:GetService("StarterPack") }

    for _, srv in ipairs(servicesToScan) do
        pcall(function()
            for _, desc in ipairs(srv:GetDescendants()) do
                if remoteTypes[desc.ClassName] then
                    table.insert(foundRemotes, desc)
                end
            end
        end)
    end

    table.sort(foundRemotes, function(a, b) return a:GetFullName() < b:GetFullName() end)
    stats.Remotes = #foundRemotes

    add(string.format("Total Native Remotes Discovered: %d", #foundRemotes))
    add("================================================================================")
    for idx, rem in ipairs(foundRemotes) do
        add(string.format("[%03d] %-22s : %s", idx, rem.ClassName, getInstancePath(rem)))
    end

    pcall(function()
        local shared = ReplicatedStorage:FindFirstChild("shared") or ReplicatedStorage:FindFirstChild("Shared")
        local remotesMod = shared and (shared:FindFirstChild("Remotes") or shared:FindFirstChild("Network"))
        if not remotesMod then
            remotesMod = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:FindFirstChild("Network")
        end
        if remotesMod and remotesMod:IsA("ModuleScript") then
            local ok, remTable = safeRequire(remotesMod)
            if ok and type(remTable) == "table" then
                add("")
                add("*** Custom Remotes Module Map (e.g. Red Network / Knit) ***")
                local rKeys = {}
                for k in pairs(remTable) do table.insert(rKeys, tostring(k)) end
                table.sort(rKeys)
                for _, k in ipairs(rKeys) do
                    local v = remTable[k]
                    local vType = typeof(v)
                    local extra = ""
                    if vType == "table" then
                        local methods = {}
                        if v.Fire then table.insert(methods, "Fire") end
                        if v.fire then table.insert(methods, "fire") end
                        if v.Call then table.insert(methods, "Call") end
                        if v.call then table.insert(methods, "call") end
                        if v.Listen then table.insert(methods, "Listen") end
                        if v.listen then table.insert(methods, "listen") end
                        if #methods > 0 then extra = " [Methods: " .. table.concat(methods, ", ") .. "]" end
                    end
                    add(string.format("  - %-32s : %s%s", k, vType, extra))
                end
            end
        end
    end)

    if onProgress then onProgress("Extracting Client Player Data & State...", 0.35) end
    addHeader("2. CLIENT PLAYER DATA & REAL-TIME STATE")

    local stateFound = false
    local candidateModules = {}

    pcall(function()
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                local low = desc.Name:lower()
                if low:find("playerdata") or low:find("clientdata") or low:find("profile") or low:find("state") or low:find("store") then
                    table.insert(candidateModules, desc)
                end
            end
        end
    end)

    for _, mod in ipairs(candidateModules) do
        local ok, res = safeRequire(mod)
        if ok and type(res) == "table" then
            local stateObj = nil
            if res.serverProfile and res.serverProfile.getState then
                pcall(function() stateObj = res.serverProfile:getState() end)
            end
            if not stateObj and res.getState then
                pcall(function() stateObj = res:getState() end)
            end
            if not stateObj and res.GetData then
                pcall(function() stateObj = res:GetData() end)
            end
            if not stateObj and res.getData then
                pcall(function() stateObj = res:getData() end)
            end
            if not stateObj and res.GetProfile then
                pcall(function() stateObj = res:GetProfile() end)
            end

            if stateObj and type(stateObj) == "table" then
                stateFound = true
                stats.States = stats.States + 1
                add(string.format("*** STATE EXTRACTED FROM: %s ***", getInstancePath(mod)))
                add(serializeValue(stateObj, 0, {}, 6))
                add("")
            end
        end
    end

    if not stateFound then
        add("No standard centralized client state producer found.")
    end

    if onProgress then onProgress("Requiring & Serializing Config Modules...", 0.55) end
    addHeader("3. REPLICATEDSTORAGE CONFIGURATION MODULES")

    local allModules = {}
    pcall(function()
        for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                table.insert(allModules, desc)
            end
        end
    end)

    table.sort(allModules, function(a, b) return a:GetFullName() < b:GetFullName() end)
    stats.Modules = #allModules

    add(string.format("Total ModuleScripts in ReplicatedStorage: %d", #allModules))
    add("================================================================================")

    for idx, mod in ipairs(allModules) do
        local ok, res = safeRequire(mod)
        local modPath = getInstancePath(mod)
        if ok then
            stats.Configs = stats.Configs + 1
            add("")
            add(string.format("[MOD-%03d] %s", idx, modPath))
            if type(res) == "table" then
                add(serializeValue(res, 0, {}, 5))
            else
                add(string.format("  Return: %s (%s)", tostring(res), typeof(res)))
            end
        else
            add(string.format("[MOD-%03d] %s [REQUIRE_FAILED: %s]", idx, modPath, tostring(res)))
        end
        if idx % 15 == 0 and onProgress then
            onProgress(string.format("Inspecting Modules (%d/%d)...", idx, #allModules), 0.55 + 0.25 * (idx / #allModules))
        end
    end

    if onProgress then onProgress("Scanning Workspace Architecture & Prompts...", 0.85) end
    addHeader("4. WORKSPACE STRUCTURE & INTERACTION PROMPTS")

    add("*** Top-Level Workspace Entities ***")
    pcall(function()
        for _, child in ipairs(workspace:GetChildren()) do
            if child ~= LocalPlayer.Character and not child:IsA("Terrain") and not child:IsA("Camera") then
                local cCount = #child:GetChildren()
                add(string.format("  - %-28s [%s] (Children: %d)", child.Name, child.ClassName, cCount))
                stats.WorkspaceObjects = stats.WorkspaceObjects + 1
            end
        end
    end)

    add("")
    add("*** CollectionService Tags Map ***")
    pcall(function()
        local tags = CollectionService:GetAllTags()
        table.sort(tags)
        for _, tag in ipairs(tags) do
            local tagged = CollectionService:GetTagged(tag)
            stats.TaggedObjects = stats.TaggedObjects + #tagged
            add(string.format("  Tag: %-26s | Count: %d", tag, #tagged))
            for i = 1, math.min(#tagged, 5) do
                add(string.format("     [%d] %s (%s)", i, getInstancePath(tagged[i]), tagged[i].ClassName))
            end
            if #tagged > 5 then
                add(string.format("     ... and %d more items", #tagged - 5))
            end
        end
    end)

    add("")
    add("*** ProximityPrompts in Workspace ***")
    pcall(function()
        local count = 0
        for _, desc in ipairs(workspace:GetDescendants()) do
            if desc:IsA("ProximityPrompt") then
                count = count + 1
                local parentPath = desc.Parent and getInstancePath(desc.Parent) or "nil"
                local promptLine = string.format("  [%02d] Action: %q | Object: %q | MaxDist: %.1f | Hold: %.2fs | Enabled: %s | Parent: %s",
                    count, desc.ActionText, desc.ObjectText, desc.MaxDistance, desc.HoldDuration, tostring(desc.Enabled), parentPath)
                add(promptLine)
            end
        end
        if count == 0 then add("  No ProximityPrompts found in Workspace.") end
    end)

    if onProgress then onProgress("Inspecting PlayerGui & Windows...", 0.92) end
    addHeader("5. PLAYERGUI WINDOWS & INTERFACE ARCHITECTURE")

    pcall(function()
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pg then
            for _, gui in ipairs(pg:GetChildren()) do
                if gui:IsA("LayerCollector") and gui.Name ~= "LumenGameDumper_UI" then
                    local adorneeStr = ""
                    if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
                        if gui.Adornee then
                            adorneeStr = string.format(" (Adornee: %s)", getInstancePath(gui.Adornee))
                        end
                    end
                    add(string.format("  - %-30s [%s] Enabled: %s%s", gui.Name, gui.ClassName, tostring(gui.Enabled), adorneeStr))
                end
            end
        end
    end)

    addHeader("6. PLAYER STATS & ATTRIBUTES")
    pcall(function()
        add("*** LocalPlayer Attributes ***")
        local attrs = LocalPlayer:GetAttributes()
        for k, v in pairs(attrs) do
            add(string.format("  %s = %s", k, serializeValue(v, 0, {}, 2)))
        end

        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if leaderstats then
            add("")
            add("*** Leaderstats ***")
            for _, val in ipairs(leaderstats:GetChildren()) do
                add(string.format("  %-20s = %s (%s)", val.Name, tostring(val.Value), val.ClassName))
            end
        end

        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            add("")
            add("*** Backpack Items ***")
            for _, tool in ipairs(backpack:GetChildren()) do
                add(string.format("  - %-24s [%s]", tool.Name, tool.ClassName))
            end
        end
    end)

    if onProgress then onProgress("Finalizing & Writing Dump File...", 0.98) end

    local fullContent = table.concat(lines, "\n")
    stats.TotalLines = #lines
    stats.FileSize = #fullContent

    local safeTitle = sanitizeFilename(gameTitle)
    local fileName = string.format("GameDump_%d_%s.txt", game.PlaceId, safeTitle)
    stats.FilePath = fileName

    pcall(function()
        if writefile then
            writefile(fileName, fullContent)
            writefile("game_dump.txt", fullContent)
        end
    end)

    pcall(function()
        if setclipboard then
            setclipboard(fullContent)
        end
    end)

    if onProgress then onProgress("Dump complete! Saved & copied to clipboard.", 1.0) end
    return fullContent, stats
end

local Theme = {
    Background = Color3.fromRGB(16, 12, 20),
    Sidebar    = Color3.fromRGB(22, 16, 26),
    Card       = Color3.fromRGB(26, 19, 31),
    CardSub    = Color3.fromRGB(36, 26, 43),
    CardActive = Color3.fromRGB(48, 34, 58),
    Accent     = Color3.fromRGB(255, 95, 135),
    AccentSoft = Color3.fromRGB(255, 175, 195),
    AccentGlow = Color3.fromRGB(255, 130, 160),
    Text       = Color3.fromRGB(255, 245, 248),
    TextDim    = Color3.fromRGB(195, 165, 182),
    Green      = Color3.fromRGB(115, 230, 155),
    Yellow     = Color3.fromRGB(255, 200, 85),
    Stroke     = Color3.fromRGB(255, 95, 135),
    StrokeSub  = Color3.fromRGB(55, 40, 62)
}

local targetParent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LumenGameDumper_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = targetParent

table.insert(connections, ScreenGui.Destroying:Connect(cleanShutdown))

local Main = Instance.new("Frame")
Main.Name = "LumenMain"
Main.Size = UDim2.new(0, 560, 0, 420)
Main.Position = UDim2.new(0.5, -280, 0.5, -210)
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
TopTitle.Size = UDim2.new(1, -120, 1, 0)
TopTitle.Position = UDim2.new(0, 16, 0, 0)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "🌸 LUMEN • Universal Game Dumper"
TopTitle.Font = Enum.Font.GothamBold
TopTitle.TextSize = 13
TopTitle.TextColor3 = Theme.Text
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.Parent = TopBar

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
FloatBtn.Text = "📊"
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
        Main.Size = UDim2.new(0, 480, 0, 360)
        TweenService:Create(Main, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 560, 0, 420)
        }):Play()
    else
        local tween = TweenService:Create(Main, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 480, 0, 360)
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

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -32, 1, -58)
ContentFrame.Position = UDim2.new(0, 16, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = Main

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 8)
ContentLayout.Parent = ContentFrame

local GameInfoCard = Instance.new("Frame")
GameInfoCard.Size = UDim2.new(1, 0, 0, 54)
GameInfoCard.BackgroundColor3 = Theme.Card
GameInfoCard.BorderSizePixel = 0
GameInfoCard.Parent = ContentFrame

local GameInfoCorner = Instance.new("UICorner")
GameInfoCorner.CornerRadius = UDim.new(0, 10)
GameInfoCorner.Parent = GameInfoCard

local GameInfoStroke = Instance.new("UIStroke")
GameInfoStroke.Color = Theme.StrokeSub
GameInfoStroke.Thickness = 0.8
GameInfoStroke.Parent = GameInfoCard

local GameTitleLabel = Instance.new("TextLabel")
GameTitleLabel.Size = UDim2.new(1, -20, 0, 20)
GameTitleLabel.Position = UDim2.new(0, 12, 0, 8)
GameTitleLabel.BackgroundTransparency = 1
GameTitleLabel.Font = Enum.Font.GothamBold
GameTitleLabel.TextSize = 13
GameTitleLabel.TextColor3 = Theme.AccentSoft
GameTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
GameTitleLabel.Text = "🎮 " .. getGameTitle()
GameTitleLabel.Parent = GameInfoCard

local GameSubLabel = Instance.new("TextLabel")
GameSubLabel.Size = UDim2.new(1, -20, 0, 16)
GameSubLabel.Position = UDim2.new(0, 12, 0, 28)
GameSubLabel.BackgroundTransparency = 1
GameSubLabel.Font = Enum.Font.Gotham
GameSubLabel.TextSize = 10
GameSubLabel.TextColor3 = Theme.TextDim
GameSubLabel.TextXAlignment = Enum.TextXAlignment.Left
GameSubLabel.Text = string.format("PlaceId: %d  |  Saved in: workspace/game_dump.txt", game.PlaceId)
GameSubLabel.Parent = GameInfoCard

local ProgressCard = Instance.new("Frame")
ProgressCard.Size = UDim2.new(1, 0, 0, 56)
ProgressCard.BackgroundColor3 = Theme.Card
ProgressCard.BorderSizePixel = 0
ProgressCard.Parent = ContentFrame

local ProgCorner = Instance.new("UICorner")
ProgCorner.CornerRadius = UDim.new(0, 10)
ProgCorner.Parent = ProgressCard

local ProgStroke = Instance.new("UIStroke")
ProgStroke.Color = Theme.StrokeSub
ProgStroke.Thickness = 0.8
ProgStroke.Parent = ProgressCard

local StatusMsgLabel = Instance.new("TextLabel")
StatusMsgLabel.Size = UDim2.new(1, -24, 0, 18)
StatusMsgLabel.Position = UDim2.new(0, 12, 0, 8)
StatusMsgLabel.BackgroundTransparency = 1
StatusMsgLabel.Font = Enum.Font.GothamSemibold
StatusMsgLabel.TextSize = 11
StatusMsgLabel.TextColor3 = Theme.Text
StatusMsgLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusMsgLabel.Text = "Starting automatic introspection..."
StatusMsgLabel.Parent = ProgressCard

local BarBg = Instance.new("Frame")
BarBg.Size = UDim2.new(1, -24, 0, 12)
BarBg.Position = UDim2.new(0, 12, 0, 32)
BarBg.BackgroundColor3 = Theme.CardSub
BarBg.BorderSizePixel = 0
BarBg.Parent = ProgressCard

local BarBgCorner = Instance.new("UICorner")
BarBgCorner.CornerRadius = UDim.new(1, 0)
BarBgCorner.Parent = BarBg

local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Theme.Accent
BarFill.BorderSizePixel = 0
BarFill.Parent = BarBg

local BarFillCorner = Instance.new("UICorner")
BarFillCorner.CornerRadius = UDim.new(1, 0)
BarFillCorner.Parent = BarFill

local StatsGrid = Instance.new("Frame")
StatsGrid.Size = UDim2.new(1, 0, 0, 124)
StatsGrid.BackgroundColor3 = Theme.Card
StatsGrid.BorderSizePixel = 0
StatsGrid.Parent = ContentFrame

local GridCorner = Instance.new("UICorner")
GridCorner.CornerRadius = UDim.new(0, 10)
GridCorner.Parent = StatsGrid

local GridStroke = Instance.new("UIStroke")
GridStroke.Color = Theme.StrokeSub
GridStroke.Thickness = 0.8
GridStroke.Parent = StatsGrid

local function createStatBox(parent, title, defaultVal, xIndex, yIndex)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0.31, 0, 0, 50)
    box.Position = UDim2.new(0.02 + xIndex * 0.325, 0, 0.08 + yIndex * 0.44, 0)
    box.BackgroundColor3 = Theme.CardSub
    box.BorderSizePixel = 0
    box.Parent = parent

    local bCorner = Instance.new("UICorner")
    bCorner.CornerRadius = UDim.new(0, 8)
    bCorner.Parent = box

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(1, -8, 0, 22)
    valLbl.Position = UDim2.new(0, 8, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 14
    valLbl.TextColor3 = Theme.AccentSoft
    valLbl.TextXAlignment = Enum.TextXAlignment.Left
    valLbl.Text = defaultVal
    valLbl.Parent = box

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -8, 0, 16)
    titleLbl.Position = UDim2.new(0, 8, 0, 28)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.Gotham
    titleLbl.TextSize = 9
    titleLbl.TextColor3 = Theme.TextDim
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Text = title
    titleLbl.Parent = box

    return valLbl
end

local StatRemotes   = createStatBox(StatsGrid, "📡 REMOTES SCANNED", "0", 0, 0)
local StatModules   = createStatBox(StatsGrid, "📦 MODULES READ", "0", 1, 0)
local StatConfigs   = createStatBox(StatsGrid, "⚙️ CONFIGS DUMPED", "0", 2, 0)
local StatObjects   = createStatBox(StatsGrid, "🗺️ WORKSPACE ENTITIES", "0", 0, 1)
local StatLines     = createStatBox(StatsGrid, "📄 OUTPUT LINES", "0", 1, 1)
local StatSize      = createStatBox(StatsGrid, "💾 FILE SIZE", "0 KB", 2, 1)

local ActionsFrame = Instance.new("Frame")
ActionsFrame.Size = UDim2.new(1, 0, 0, 80)
ActionsFrame.BackgroundTransparency = 1
ActionsFrame.Parent = ContentFrame

local StartDumpBtn = Instance.new("TextButton")
StartDumpBtn.Size = UDim2.new(1, 0, 0, 38)
StartDumpBtn.Position = UDim2.new(0, 0, 0, 0)
StartDumpBtn.BackgroundColor3 = Theme.Accent
StartDumpBtn.Text = "🚀 DUMP COMPLETE GAME TO TXT FILE"
StartDumpBtn.Font = Enum.Font.GothamBold
StartDumpBtn.TextSize = 12
StartDumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StartDumpBtn.AutoButtonColor = false
StartDumpBtn.Parent = ActionsFrame

local DumpCorner = Instance.new("UICorner")
DumpCorner.CornerRadius = UDim.new(0, 10)
DumpCorner.Parent = StartDumpBtn

local CopyBtn = Instance.new("TextButton")
CopyBtn.Size = UDim2.new(0.49, 0, 0, 32)
CopyBtn.Position = UDim2.new(0, 0, 0, 44)
CopyBtn.BackgroundColor3 = Theme.CardSub
CopyBtn.Text = "📋 Copy Filename / Path"
CopyBtn.Font = Enum.Font.GothamSemibold
CopyBtn.TextSize = 11
CopyBtn.TextColor3 = Theme.Text
CopyBtn.AutoButtonColor = false
CopyBtn.Parent = ActionsFrame
local CopyCorner = Instance.new("UICorner")
CopyCorner.CornerRadius = UDim.new(0, 8)
CopyCorner.Parent = CopyBtn

local ClipboardDumpBtn = Instance.new("TextButton")
ClipboardDumpBtn.Size = UDim2.new(0.49, 0, 0, 32)
ClipboardDumpBtn.Position = UDim2.new(0.51, 0, 0, 44)
ClipboardDumpBtn.BackgroundColor3 = Theme.CardSub
ClipboardDumpBtn.Text = "📄 Copy TXT to Clipboard"
ClipboardDumpBtn.Font = Enum.Font.GothamSemibold
ClipboardDumpBtn.TextSize = 11
ClipboardDumpBtn.TextColor3 = Theme.Text
ClipboardDumpBtn.AutoButtonColor = false
ClipboardDumpBtn.Parent = ActionsFrame
local ClipCorner = Instance.new("UICorner")
ClipCorner.CornerRadius = UDim.new(0, 8)
ClipCorner.Parent = ClipboardDumpBtn

local lastDumpContent = nil
local lastFilePath = ""
local isDumping = false

local function runDumpTask()
    if isDumping then return end
    isDumping = true
    StartDumpBtn.BackgroundColor3 = Theme.CardActive
    StartDumpBtn.Text = "⏳ DUMPING IN PROGRESS..."

    task.spawn(function()
        local content, stats = generateFullGameDump(function(msg, pct)
            StatusMsgLabel.Text = msg
            TweenService:Create(BarFill, TweenInfo.new(0.15), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
        end)

        lastDumpContent = content
        lastFilePath = stats.FilePath

        StatRemotes.Text = tostring(stats.Remotes)
        StatModules.Text = tostring(stats.Modules)
        StatConfigs.Text = tostring(stats.Configs)
        StatObjects.Text = tostring(stats.WorkspaceObjects + stats.TaggedObjects)
        StatLines.Text   = tostring(stats.TotalLines)
        StatSize.Text    = formatBytes(stats.FileSize)

        StatusMsgLabel.Text = string.format("✔ Saved: %s (Also copied to Clipboard!)", stats.FilePath)
        StatusMsgLabel.TextColor3 = Theme.Green
        StartDumpBtn.BackgroundColor3 = Theme.Accent
        StartDumpBtn.Text = "🚀 RE-RUN FULL GAME DUMP"
        isDumping = false
    end)
end

StartDumpBtn.MouseButton1Click:Connect(runDumpTask)

CopyBtn.MouseButton1Click:Connect(function()
    if lastFilePath ~= "" then
        pcall(function()
            if setclipboard then
                setclipboard(lastFilePath)
                StatusMsgLabel.Text = "✔ Copied filename to clipboard!"
            end
        end)
    else
        StatusMsgLabel.Text = "Run a dump first to get the filename."
    end
end)

ClipboardDumpBtn.MouseButton1Click:Connect(function()
    if lastDumpContent and #lastDumpContent > 0 then
        pcall(function()
            if setclipboard then
                setclipboard(lastDumpContent)
                StatusMsgLabel.Text = "✔ Entire dump copied to clipboard (Ctrl+V)!"
            end
        end)
    else
        StatusMsgLabel.Text = "Run a dump first before copying."
    end
end)

task.spawn(runDumpTask)
