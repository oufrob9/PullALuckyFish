local HttpService = game:GetService("HttpService")
local Settings = {}
local PS_SAVE_FILE = "autocauldron_ps_link.txt"
local CONFIG_FILE = "AutoCauldron_Settings.json"
Settings.Defaults = {
    AutoCast = true,
    AutoSteer = true,
    MythicEggMaxPriority = true,
    MythicEggFocusOnly = false,
    SteerPriorityMode = "MythicEggFirst",
    AvoidMonsters = true,
    DescentPreAlign = true,
    MonsterDangerRadius = 7.5,
    MonsterVerticalGrace = 4.5,
    AutoBuyHalloweenShop = true,
    AutoBuyCheckInterval = 2.0,
    AutoBuyEggA = true,
    AutoBuyEggB = true,
    AutoBuyPetEgg = true,
    AutoBuyGodlyFloat = true,
    AutoBuyHauntedBase = true,
    AutoBuyWitchBroom = false,
    AutoBuyDeathScythe = false,
    AutoBuyDecoCrate = true,
    AutoUpgradeMachine = true,
    AutoUpgradeLuck = true,
    AutoUpgradeCapacity = true,
    AutoUpgradeHeavier = true,
    MinCandyReserve = 0,
    EspEnabled = true,
    EspShowZone = true,
    EspShowLoot = true,
    EspShowMonsters = true,
    EspMinRarity = "Common",
    EspChams = true,
    EspShowMythicEggAlert = true,
    PrivateServerLink = _G.AutoCauldronPrivateServerLink or "",
    AutoReconnect = true,
    ReconnectDelay = 2.5,
    AutoTpToCauldron = true,
    AutoTpInterval = 2.0,
    AutoTpOnSpawn = true,
    AntiAfk = true,
}
function Settings.load(State, Executor)
    for k, v in pairs(Settings.Defaults) do
        if State[k] == nil then
            State[k] = v
        end
    end
    local savedPs = Executor.safeReadFile(PS_SAVE_FILE)
    if savedPs and #savedPs > 0 then
        State.PrivateServerLink = string.gsub(savedPs, "%s+", "")
    end
    local rawConfig = Executor.safeReadFile(CONFIG_FILE)
    if rawConfig and #rawConfig > 0 then
        local ok, data = pcall(function() return HttpService:JSONDecode(rawConfig) end)
        if ok and type(data) == "table" then
            for k, v in pairs(data) do
                State[k] = v
            end
        end
    end
end
function Settings.save(State, Executor)
    if State.PrivateServerLink and #State.PrivateServerLink > 0 then
        Executor.safeWriteFile(PS_SAVE_FILE, State.PrivateServerLink)
    end
    local saveTable = {}
    for k in pairs(Settings.Defaults) do
        saveTable[k] = State[k]
    end
    local okEncode, encoded = pcall(function() return HttpService:JSONEncode(saveTable) end)
    if okEncode and encoded then
        Executor.safeWriteFile(CONFIG_FILE, encoded)
    end
end
return Settings
