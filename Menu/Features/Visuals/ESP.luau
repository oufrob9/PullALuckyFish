local ESP = {}
local espFolder = nil
local activeHighlights = {}
local activeBillboards = {}
local RARITY_COLORS = {
    Mythic = Color3.fromRGB(255, 0, 230),
    Legendary = Color3.fromRGB(255, 215, 0),
    Epic = Color3.fromRGB(160, 32, 240),
    Rare = Color3.fromRGB(30, 144, 255),
    Uncommon = Color3.fromRGB(50, 205, 50),
    Common = Color3.fromRGB(200, 200, 200),
    Monster = Color3.fromRGB(255, 40, 40),
}
function ESP.cleanAll()
    for _, h in pairs(activeHighlights) do
        pcall(function() h:Destroy() end)
    end
    table.clear(activeHighlights)
    for _, b in pairs(activeBillboards) do
        pcall(function() b:Destroy() end)
    end
    table.clear(activeBillboards)
    if espFolder and espFolder.Parent then
        pcall(function() espFolder:Destroy() end)
        espFolder = nil
    end
end
function ESP.setupZoneESP(Services, State)
    if not State.EspShowZone then return end
    local b = {
        MIN_X = 22.0, MAX_X = 38.0,
        MIN_Z = 16.0, MAX_Z = 32.0,
        MIN_Y = 120.0, MAX_Y = 138.0,
    }
    local size = Vector3.new(b.MAX_X - b.MIN_X, b.MAX_Y - b.MIN_Y, b.MAX_Z - b.MIN_Z)
    local center = Vector3.new((b.MIN_X + b.MAX_X) / 2, (b.MIN_Y + b.MAX_Y) / 2, (b.MIN_Z + b.MAX_Z) / 2)
    local box = Instance.new("Part")
    box.Name = "CauldronZoneBox"
    box.Size = size
    box.CFrame = CFrame.new(center)
    box.Anchored = true
    box.CanCollide = false
    box.CanTouch = false
    box.CanQuery = false
    box.Transparency = 0.85
    box.Color = Color3.fromRGB(140, 50, 220)
    box.Material = Enum.Material.ForceField
    box.Parent = espFolder
end
function ESP.updateESP(Services, State, Helpers)
    if not State.Running or not State.EspEnabled then
        ESP.cleanAll()
        return
    end
    if not espFolder or not espFolder.Parent then
        espFolder = Instance.new("Folder")
        espFolder.Name = "AutoCauldron_ESP"
        espFolder.Parent = Services.Workspace
        ESP.setupZoneESP(Services, State)
    end
    local debris = Services.Workspace:FindFirstChild("Debris") or Services.Workspace
    local currentInstances = {}
    for _, obj in ipairs(debris:GetChildren()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position) or obj.Position
            local b = Helpers.CAULDRON_BOUNDS
            if (pos.X >= b.MIN_X - 12 and pos.X <= b.MAX_X + 12) and (pos.Z >= b.MIN_Z - 12 and pos.Z <= b.MAX_Z + 12) then
                local isMonster = Helpers.isBlacklistedMonster(obj.Name)
                local isEgg = Helpers.isEggItem(obj.Name)
                local isLoot = Helpers.isHighValueLoot(obj.Name)
                local rarity = "Common"
                if isEgg then
                    rarity = (string.find(string.lower(obj.Name), "mythic") and "Mythic") or "Legendary"
                elseif isLoot then
                    rarity = "Rare"
                end
                local score = Helpers.getRarityScore(rarity)
                local minScore = Helpers.getRarityScore(State.EspMinRarity)
                local showThis = false
                local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
                if isMonster and State.EspShowMonsters then
                    showThis = true
                    color = RARITY_COLORS.Monster
                elseif not isMonster and State.EspShowLoot and score >= minScore then
                    showThis = true
                end
                if showThis then
                    currentInstances[obj] = true
                    if State.EspChams then
                        local hl = activeHighlights[obj]
                        if not hl or not hl.Parent then
                            hl = Instance.new("Highlight")
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0.1
                            hl.FillColor = color
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.Adornee = obj
                            hl.Parent = espFolder
                            activeHighlights[obj] = hl
                        else
                            hl.FillColor = color
                        end
                    end
                    local bb = activeBillboards[obj]
                    if not bb or not bb.Parent then
                        bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 120, 0, 36)
                        bb.AlwaysOnTop = true
                        bb.MaxDistance = 300
                        bb.Adornee = obj
                        bb.Parent = espFolder
                        local lbl = Instance.new("TextLabel")
                        lbl.Name = "Info"
                        lbl.Size = UDim2.new(1, 0, 1, 0)
                        lbl.BackgroundTransparency = 1
                        lbl.Font = Enum.Font.GothamBold
                        lbl.TextSize = 10
                        lbl.TextColor3 = color
                        lbl.TextStrokeTransparency = 0.4
                        lbl.Parent = bb
                        activeBillboards[obj] = bb
                    end
                    local lbl = bb:FindFirstChild("Info")
                    if lbl then
                        local hrp = Services.getHRP()
                        local dist = hrp and math.floor((hrp.Position - pos).Magnitude) or 0
                        lbl.Text = string.format("%s\n[%s] (%dm)", obj.Name, isMonster and "DANGER" or rarity, dist)
                        lbl.TextColor3 = color
                    end
                end
            end
        end
    end
    for inst, hl in pairs(activeHighlights) do
        if not currentInstances[inst] or not inst.Parent then
            pcall(function() hl:Destroy() end)
            activeHighlights[inst] = nil
        end
    end
    for inst, bb in pairs(activeBillboards) do
        if not currentInstances[inst] or not inst.Parent then
            pcall(function() bb:Destroy() end)
            activeBillboards[inst] = nil
        end
    end
end
function ESP.init(Services, State, Helpers, Cleanup)
    local espThread = task.spawn(function()
        while State.Running do
            pcall(function()
                ESP.updateESP(Services, State, Helpers)
            end)
            task.wait(0.5)
        end
        ESP.cleanAll()
    end)
    Cleanup.addThread(espThread)
    Cleanup.onCleanup(ESP.cleanAll)
end
return ESP
