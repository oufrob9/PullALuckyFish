local AutoSpawnTp = {}
function AutoSpawnTp.init(Services, State, Helpers, Logger, Cleanup)
    local LocalPlayer = Services.LocalPlayer
    if not LocalPlayer then return end
    local function onCharacterSpawn(character)
        task.spawn(function()
            local hrp = character:WaitForChild("HumanoidRootPart", 10)
            if hrp and State.AutoTpOnSpawn then
                task.wait(1.5)
                if State.Running and State.AutoTpOnSpawn and not Helpers.isPlayerInZone(Services) then
                    Helpers.teleportToCauldron(Services)
                    Logger.info("Teleportation automatique au Chaudron effectuee.")
                end
            end
        end)
    end
    if LocalPlayer.Character then
        onCharacterSpawn(LocalPlayer.Character)
    end
    local charAddedConn = LocalPlayer.CharacterAdded:Connect(onCharacterSpawn)
    Cleanup.addConnection(charAddedConn)
end
return AutoSpawnTp
