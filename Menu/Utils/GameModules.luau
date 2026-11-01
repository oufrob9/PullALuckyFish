local GameModules = {}
function GameModules.init(Services)
    local ReplicatedStorage = Services.ReplicatedStorage
    pcall(function()
        local sharedDir = ReplicatedStorage:WaitForChild("shared", 5)
        if sharedDir and sharedDir:FindFirstChild("Remotes") then
            GameModules.Remotes = require(sharedDir.Remotes)
        end
    end)
    pcall(function()
        local sharedDir = ReplicatedStorage:FindFirstChild("shared")
        local cfg = sharedDir and sharedDir:FindFirstChild("config")
        if cfg then
            if cfg:FindFirstChild("CauldronDiveConfig") then
                GameModules.CauldronDiveConfig = require(cfg.CauldronDiveConfig)
            end
            if cfg:FindFirstChild("HalloweenUpgradesConfig") then
                GameModules.HalloweenUpgradesConfig = require(cfg.HalloweenUpgradesConfig)
            end
            if cfg:FindFirstChild("HalloweenEventShopConfig") then
                GameModules.HalloweenEventShopConfig = require(cfg.HalloweenEventShopConfig)
            end
            if cfg:FindFirstChild("HalloweenEventConfig") then
                GameModules.HalloweenEventConfig = require(cfg.HalloweenEventConfig)
            end
            if cfg:FindFirstChild("EggConfig") then
                GameModules.EggConfig = require(cfg.EggConfig)
            end
            if cfg:FindFirstChild("FishConfig") then
                GameModules.FishConfig = require(cfg.FishConfig)
            end
        end
    end)
    pcall(function()
        local client = ReplicatedStorage:FindFirstChild("client")
        if client and client:FindFirstChild("ClientPlayerData") then
            GameModules.ClientPlayerData = require(client.ClientPlayerData)
        end
    end)
    pcall(function()
        local sharedDir = ReplicatedStorage:FindFirstChild("shared")
        local util = sharedDir and sharedDir:FindFirstChild("util")
        if util and util:FindFirstChild("CauldronDiveSim") then
            GameModules.CauldronDiveSim = require(util.CauldronDiveSim)
        end
    end)
end
function GameModules.getState()
    local CPD = GameModules.ClientPlayerData
    if CPD then
        local sources = { CPD.serverProfile, CPD.clientProducer }
        for _, src in ipairs(sources) do
            if type(src) == "table" and type(src.getState) == "function" then
                local ok, s = pcall(src.getState, src)
                if ok and type(s) == "table" and (s.decorationsStoreStock ~= nil or s.money ~= nil or s.events ~= nil) then
                    return s
                end
            end
        end
        if CPD.serverProfile and type(CPD.serverProfile.getState) == "function" then
            local ok, s = pcall(CPD.serverProfile.getState, CPD.serverProfile)
            if ok and type(s) == "table" then return s end
        end
        if type(CPD.getState) == "function" then
            local ok, s = pcall(CPD.getState, CPD)
            if ok and type(s) == "table" then return s end
        end
    end
    return {}
end
function GameModules.stackOf(s, name)
    if not s or type(s) ~= "table" then return 0 end
    local it = (s.inventory or {})[name]
    return (type(it) == "table" and (tonumber(it.Stack) or 0)) or 0
end
return GameModules
