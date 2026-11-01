if _G.AutoCauldronCleanup and typeof(_G.AutoCauldronCleanup) == "function" then
    pcall(_G.AutoCauldronCleanup)
end
local function initLoader()
    local moduleCache = {}
    local RAW_BASE = "https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main/Menu/"
    local function safeHttpGet(url)
        if typeof(game) == "Instance" and typeof(game.HttpGet) == "function" then
            local ok, res = pcall(game.HttpGet, game, url)
            if ok and res and #res > 0 then return res end
        end
        local req = request or http_request or (syn and syn.request)
        if typeof(req) == "function" then
            local ok, res = pcall(req, { Url = url, Method = "GET" })
            if ok and type(res) == "table" and res.Body and #res.Body > 0 then
                return res.Body
            end
        end
        return nil
    end
    local function import(path)
        if moduleCache[path] then
            return moduleCache[path]
        end
        local content = nil
        local resolved = nil
        if typeof(readfile) == "function" then
            local candidates = {}
            if _G.AutoCauldronPath and type(_G.AutoCauldronPath) == "string" then
                table.insert(candidates, _G.AutoCauldronPath .. "/" .. path .. ".luau")
                table.insert(candidates, _G.AutoCauldronPath .. "/" .. path .. ".lua")
            end
            table.insert(candidates, "Menu/" .. path .. ".luau")
            table.insert(candidates, "Menu/" .. path .. ".lua")
            table.insert(candidates, "scripts/Menu/" .. path .. ".luau")
            table.insert(candidates, "scripts/Menu/" .. path .. ".lua")
            table.insert(candidates, "workspace/Menu/" .. path .. ".luau")
            table.insert(candidates, "workspace/Menu/" .. path .. ".lua")
            table.insert(candidates, path .. ".luau")
            table.insert(candidates, path .. ".lua")
            for _, p in ipairs(candidates) do
                local okRead, text = pcall(readfile, p)
                if okRead and text and #text > 0 then
                    content = text
                    resolved = p
                    break
                end
            end
        end
        if not content then
            local url = RAW_BASE .. path .. ".luau"
            local text = safeHttpGet(url)
            if text then
                content = text
                resolved = url
            end
        end
        if not content then
            error(string.format("[AutoCauldron Loader] Fichier introuvable: %s", path), 2)
        end
        local chunk, compileErr = loadstring(content)
        if not chunk then
            error(string.format("[AutoCauldron Loader] Erreur de compilation dans %s: %s", resolved or path, tostring(compileErr)), 2)
        end
        local okExec, result = pcall(chunk)
        if not okExec then
            error(string.format("[AutoCauldron Loader] Erreur d'execution dans %s: %s", resolved or path, tostring(result)), 2)
        end
        moduleCache[path] = result
        return result
    end
    local Executor = import("Core/Executor")
    local State = import("Core/State")
    local Logger = import("Core/Logger")
    local Cleanup = import("Core/Cleanup")
    _G.AutoCauldronCleanup = function()
        Cleanup.execute(State, Executor)
        Logger.info("Nettoyage global termine.")
    end
    local Settings = import("Config/Settings")
    local Services = import("Utils/Services")
    local GameModules = import("Utils/GameModules")
    local RemotesUtils = import("Utils/Remotes")
    local Helpers = import("Utils/Helpers")
    Executor.bypassThrowAnimations(Services.ReplicatedStorage)
    GameModules.init(Services)
    Settings.load(State, Executor)
    local CauldronCast = import("Features/Halloween/CauldronCast")
    local CauldronSteer = import("Features/Halloween/CauldronSteer")
    local HalloweenShop = import("Features/Halloween/HalloweenShop")
    local ESP = import("Features/Visuals/ESP")
    local AntiAfk = import("Features/Misc/AntiAfk")
    local AutoReconnect = import("Features/Misc/AutoReconnect")
    local AutoSpawnTp = import("Features/Misc/AutoSpawnTp")
    local DecoCrates = import("Features/Misc/DecoCrates")
    CauldronCast.init(Services, State, Executor, GameModules, Helpers, Logger, Cleanup)
    CauldronSteer.init(Services, State, Executor, Helpers, Cleanup)
    HalloweenShop.init(Services, State, GameModules, Logger, Cleanup)
    ESP.init(Services, State, Helpers, Cleanup)
    AntiAfk.init(Services, State, Cleanup)
    AutoReconnect.init(Services, State, Logger, Cleanup)
    AutoSpawnTp.init(Services, State, Helpers, Logger, Cleanup)
    DecoCrates.init(Services, State, GameModules, RemotesUtils, Logger, Cleanup)
    local KyriLib = import("Libs/KyriLib")
    local Interface = import("UI/Interface")
    Interface.init(
        KyriLib,
        Services,
        State,
        Executor,
        Settings,
        Helpers,
        RemotesUtils,
        CauldronCast,
        DecoCrates,
        Logger,
        Cleanup
    )
    Logger.info("AutoCauldron pret!")
end
local ok, err = pcall(initLoader)
if not ok then
    warn("[AutoCauldron Error] " .. tostring(err))
end

