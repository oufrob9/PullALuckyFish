local AutoReconnect = {}
function AutoReconnect.triggerReconnect(Services, State, Logger, reason)
    if State.IsReconnecting then return end
    State.IsReconnecting = true
    Logger.warn(string.format("Deconnexion detectee (%s). Tentative de reconnexion...", reason))
    task.wait(State.ReconnectDelay or 2.5)
    pcall(function()
        local psLink = State.PrivateServerLink
        if psLink and #psLink > 0 then
            local code = string.match(psLink, "privateServerLinkCode=([%w%-]+)")
                or string.match(psLink, "code=([%w%-]+)")
                or string.match(psLink, "share%?code=([%w%-]+)")
            if code then
                Logger.info("Reconnexion via le code de serveur prive: " .. code)
                Services.TeleportService:TeleportToPrivateServer(game.PlaceId, code, { Services.LocalPlayer })
                return
            end
        end
        Logger.info("Reconnexion au serveur public standard...")
        Services.TeleportService:Teleport(game.PlaceId, Services.LocalPlayer)
    end)
end
function AutoReconnect.init(Services, State, Logger, Cleanup)
    local errorConn = Services.GuiService.ErrorMessageChanged:Connect(function()
        if State.Running and State.AutoReconnect then
            task.spawn(function()
                AutoReconnect.triggerReconnect(Services, State, Logger, "GuiService ErrorMessageChanged")
            end)
        end
    end)
    Cleanup.addConnection(errorConn)
    local networkClient = game:GetService("NetworkClient")
    if networkClient then
        local childConn = networkClient.ChildRemoved:Connect(function()
            if State.Running and State.AutoReconnect then
                task.spawn(function()
                    AutoReconnect.triggerReconnect(Services, State, Logger, "NetworkClient ChildRemoved")
                end)
            end
        end)
        Cleanup.addConnection(childConn)
    end
end
return AutoReconnect
