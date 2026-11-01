local HttpService = game:GetService("HttpService")
local Settings = {}
local PS_SAVE_FILE = "autocauldron_ps_link.txt"
local CONFIG_FILE = "AutoCauldron_Settings.json"
Settings.Defaults = {
    AutoCast = false,
    AutoSteer = false,
    MythicEggMaxPriority = false,
    MythicEggFocusOnly = false,
    SteerPriorityMode = "MythicEggFirst",
    AvoidMonsters = false,
    DescentPreAlign = false,
    MonsterDangerRadius = 7.5,
    MonsterVerticalGrace = 4.5,
    AutoBuyHalloweenShop = false,
    AutoBuyCheckInterval = 2.0,
    AutoBuyEggA = false,
    AutoBuyEggB = false,
    AutoBuyPetEgg = false,
    AutoBuyGodlyFloat = false,
    AutoBuyHauntedBase = false,
    AutoBuyWitchBroom = false,
    AutoBuyDeathScythe = false,
    AutoBuyDecoCrate = false,
    AutoUpgradeMachine = false,
    AutoUpgradeLuck = false,
    AutoUpgradeCapacity = false,
    AutoUpgradeHeavier = false,
    MinCandyReserve = 0,
    EspEnabled = false,
    EspShowZone = false,
    EspShowLoot = false,
    EspShowMonsters = false,
    EspMinRarity = "Common",
    EspChams = false,
    EspShowMythicEggAlert = false,
    PrivateServerLink = _G.AutoCauldronPrivateServerLink or "",
    AutoReconnect = false,
    ReconnectDelay = 2.5,
    AutoTpToCauldron = false,
    AutoTpInterval = 2.0,
    AutoTpOnSpawn = false,
    AntiAfk = false,
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
