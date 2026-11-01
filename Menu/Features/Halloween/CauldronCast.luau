local CauldronCast = {}
local currentServices = nil
local currentGameModules = nil
local currentHelpers = nil
local currentLogger = nil
function CauldronCast.findCastButton(Services)
    local playerGui = (Services and Services.getPlayerGui()) or (currentServices and currentServices.getPlayerGui())
    if not playerGui then return nil end
    local keywords = { "cast", "throw", "dive", "cauldrondive", "plonger", "lancer" }
    for _, desc in ipairs(playerGui:GetDescendants()) do
        if desc:IsA("GuiButton") and desc.Visible then
            local name = string.lower(desc.Name)
            local text = desc:IsA("TextButton") and string.lower(desc.Text) or ""
            for _, kw in ipairs(keywords) do
                if string.find(name, kw) or string.find(text, kw) then
                    return desc
                end
            end
        end
    end
    return nil
end
function CauldronCast.triggerDiveFinish()
    pcall(function()
        local remotes = currentGameModules and currentGameModules.Remotes
        if remotes and remotes.CauldronDiveFinish then
            remotes.CauldronDiveFinish:Call({
                interrupted = false,
                forced = true,
            })
            if currentLogger then
                currentLogger.info("Signal CauldronDiveFinish transmis.")
            end
        end
    end)
end
function CauldronCast.unblockStuckDive()
    if currentLogger then
        currentLogger.warn("Procedure de deblocage activee...")
    end
    CauldronCast.triggerDiveFinish()
    task.wait(0.2)
    if currentHelpers and currentServices then
        currentHelpers.teleportToCauldron(currentServices)
    end
end
function CauldronCast.init(
    Services,
    State,
    Executor,
    GameModules,
    Helpers,
    Logger,
    Cleanup
)
    currentServices = Services
    currentGameModules = GameModules
    currentHelpers = Helpers
    currentLogger = Logger
    local isCasting = false
    local castThread = task.spawn(function()
        while State.Running do
            if State.AutoCast and not isCasting then
                local inZone = Helpers.isPlayerInZone(Services)
                State.InZone = inZone
                if inZone then
                    local castBtn = CauldronCast.findCastButton(Services)
                    State.CastButtonInstance = castBtn
                    State.CastDetected = (castBtn ~= nil)
                    if castBtn and (tick() - State.LastCastTime >= 2.5) then
                        isCasting = true
                        State.LastCastTime = tick()
                        Logger.info("Bouton de lancer repere. Execution de l'Auto-Cast...")
                        local success = Executor.activateGuiButton(castBtn)
                        if success then
                            State.CurrentDiveActive = true
                            State.Stats.DivesCompleted = State.Stats.DivesCompleted + 1
                        else
                            Logger.warn("Echec d'activation du bouton de Cast.")
                        end
                        task.wait(1.5)
                        isCasting = false
                    end
                elseif State.AutoTpToCauldron and (tick() - State.LastOutOfZoneTp >= State.AutoTpInterval) then
                    State.LastOutOfZoneTp = tick()
                    Helpers.teleportToCauldron(Services)
                end
            end
            task.wait(0.4)
        end
    end)
    Cleanup.addThread(castThread)
end
return CauldronCast
