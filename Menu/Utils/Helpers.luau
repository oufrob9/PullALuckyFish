local Helpers = {}
Helpers.CAULDRON_BOUNDS = {
    MIN_X = 22.0,
    MAX_X = 38.0,
    MIN_Z = 16.0,
    MAX_Z = 32.0,
    MIN_Y = 120.0,
    MAX_Y = 138.0,
}
Helpers.CAULDRON_TP_TARGET = Vector3.new(30, 126, 24)
local RARITY_SCORES = {
    Mythic = 1000,
    Legendary = 500,
    Epic = 200,
    Rare = 100,
    Uncommon = 50,
    Common = 10,
}
local NUMBER_SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Helpers.formatNumber(n)
    n = tonumber(n) or 0
    if n ~= n then return "NaN" end
    if math.abs(n) < 1000 then return tostring(math.floor(n)) end
    local i = 1
    while math.abs(n) >= 1000 and i < #NUMBER_SUFFIXES do
        n = n / 1000
        i = i + 1
    end
    if math.abs(n) >= 1000 then
        return string.format("%.2e", n * 1000 ^ (i - 1))
    end
    return string.format("%.2f %s", n, NUMBER_SUFFIXES[i])
end
function Helpers.isPlayerInZone(Services)
    local hrp = Services.getHRP()
    if not hrp then return false end
    local p = hrp.Position
    local b = Helpers.CAULDRON_BOUNDS
    return (p.X >= b.MIN_X and p.X <= b.MAX_X)
        and (p.Z >= b.MIN_Z and p.Z <= b.MAX_Z)
        and (p.Y >= b.MIN_Y and p.Y <= b.MAX_Y)
end
function Helpers.teleportToCauldron(Services)
    local hrp = Services.getHRP()
    if not hrp then return end
    pcall(function()
        hrp.CFrame = CFrame.new(Helpers.CAULDRON_TP_TARGET)
    end)
end
function Helpers.findHookModel(Services)
    local debris = Services.Workspace:FindFirstChild("Debris")
    if debris then
        local hook = debris:FindFirstChild("CauldronDiveHook") or debris:FindFirstChild("FishingHook")
        if hook and hook:IsA("Model") then
            return hook
        end
    end
    local char = Services.getCharacter()
    if char then
        local hook = char:FindFirstChild("CauldronDiveHook") or char:FindFirstChild("FishingHook")
        if hook and hook:IsA("Model") then
            return hook
        end
    end
    for _, desc in ipairs(Services.Workspace:GetChildren()) do
        if desc.Name == "CauldronDiveHook" and desc:IsA("Model") then
            return desc
        end
    end
    return nil
end
function Helpers.getHookPosition(Services)
    local hook = Helpers.findHookModel(Services)
    if not hook then return nil end
    local prim = hook.PrimaryPart or hook:FindFirstChild("Handle") or hook:FindFirstChildWhichIsA("BasePart")
    return prim and prim.Position
end
function Helpers.getRarityScore(rarity)
    return (rarity and RARITY_SCORES[rarity]) or 0
end
function Helpers.isBlacklistedMonster(name)
    local lower = string.lower(name)
    return string.find(lower, "megalodon") ~= nil
        or string.find(lower, "doodle") ~= nil
        or string.find(lower, "backroom") ~= nil
        or string.find(lower, "mine") ~= nil
        or string.find(lower, "bomb") ~= nil
end
function Helpers.isHighValueLoot(name)
    local lower = string.lower(name)
    return string.find(lower, "mythic") ~= nil
        or string.find(lower, "egg") ~= nil
        or string.find(lower, "candy") ~= nil
        or string.find(lower, "lucky") ~= nil
        or string.find(lower, "crate") ~= nil
end
function Helpers.isEggItem(name)
    local lower = string.lower(name)
    return string.find(lower, "egg") ~= nil
end
return Helpers
