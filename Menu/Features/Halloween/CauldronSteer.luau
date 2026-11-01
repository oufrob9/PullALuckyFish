local CauldronSteer = {}
function CauldronSteer.init(
    Services,
    State,
    Executor,
    Helpers,
    Cleanup
)
    local Workspace = Services.Workspace
    local RunService = Services.RunService
    local VirtualInputManager = Services.VirtualInputManager
    local camera = Workspace.CurrentCamera
    local function getCauldronCandidates()
        local candidates = {}
        local debris = Workspace:FindFirstChild("Debris")
        local container = debris or Workspace
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") or obj:IsA("BasePart") then
                local name = obj.Name
                local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position) or obj.Position
                local b = Helpers.CAULDRON_BOUNDS
                if (pos.X >= b.MIN_X - 10 and pos.X <= b.MAX_X + 10) and (pos.Z >= b.MIN_Z - 10 and pos.Z <= b.MAX_Z + 10) then
                    local isMonster = Helpers.isBlacklistedMonster(name)
                    local isEgg = Helpers.isEggItem(name)
                    local isLoot = Helpers.isHighValueLoot(name)
                    local rarity = "Common"
                    if isEgg then
                        rarity = (string.find(string.lower(name), "mythic") and "Mythic") or "Legendary"
                    elseif isLoot then
                        rarity = "Rare"
                    end
                    table.insert(candidates, {
                        Instance = obj,
                        Position = pos,
                        Name = name,
                        IsMonster = isMonster,
                        IsEgg = isEgg,
                        IsMythicEgg = (isEgg and string.find(string.lower(name), "mythic") ~= nil),
                        Rarity = rarity,
                        Score = Helpers.getRarityScore(rarity),
                    })
                end
            end
        end
        return candidates
    end
    Executor.hookMouseLocation(function()
        if State.AutoSteer and State.CurrentDiveActive and State.CurrentTargetScreenPos then
            return State.CurrentTargetScreenPos
        end
        return nil
    end)
    local steerConnection = RunService.RenderStepped:Connect(function()
        if not State.Running or not State.AutoSteer then
            State.CurrentTargetScreenPos = nil
            State.CurrentTargetCand = nil
            return
        end
        local hookPos = Helpers.getHookPosition(Services)
        if not hookPos then
            State.CurrentDiveActive = false
            State.CurrentTargetScreenPos = nil
            return
        end
        State.HookPos = hookPos
        State.CurrentDiveActive = true
        local candidates = getCauldronCandidates()
        local bestTarget = nil
        local highestScore = -math.huge
        local mythicCandidate = nil
        for _, cand in ipairs(candidates) do
            if cand.IsMythicEgg then
                mythicCandidate = cand
                break
            end
        end
        State.MythicEggInShaft = (mythicCandidate ~= nil)
        State.MythicEggCand = mythicCandidate
        if State.MythicEggMaxPriority and mythicCandidate then
            bestTarget = mythicCandidate
        else
            if State.MythicEggFocusOnly then
                bestTarget = nil
            else
                for _, cand in ipairs(candidates) do
                    if not cand.IsMonster then
                        local dist = (cand.Position - hookPos).Magnitude
                        local score = cand.Score - (dist * 1.5)
                        if State.SteerPriorityMode == "CandyMax" and cand.IsLoot then
                            score = score + 200
                        elseif State.SteerPriorityMode == "RarityMax" then
                            score = cand.Score
                        end
                        if score > highestScore then
                            highestScore = score
                            bestTarget = cand
                        end
                    end
                end
            end
        end
        local steerVector = Vector3.new(0, 0, 0)
        if bestTarget then
            steerVector = (bestTarget.Position - hookPos)
        end
        if State.AvoidMonsters then
            for _, cand in ipairs(candidates) do
                if cand.IsMonster then
                    local dPos = cand.Position - hookPos
                    local horizontalDist = Vector2.new(dPos.X, dPos.Z).Magnitude
                    local verticalDist = math.abs(dPos.Y)
                    if horizontalDist < State.MonsterDangerRadius and verticalDist < State.MonsterVerticalGrace then
                        local avoidDir = -Vector3.new(dPos.X, 0, dPos.Z).Unit
                        steerVector = steerVector + (avoidDir * 25)
                    end
                end
            end
        end
        if camera then
            local targetWorldPos = hookPos + steerVector
            local screenPos, onScreen = camera:WorldToViewportPoint(targetWorldPos)
            if onScreen then
                State.CurrentTargetScreenPos = Vector2.new(screenPos.X, screenPos.Y)
                State.CurrentTargetCand = bestTarget
            end
            if VirtualInputManager and steerVector.Magnitude > 0.5 then
                local camRight = camera.CFrame.RightVector
                local dot = steerVector.Unit:Dot(camRight)
                if dot > 0.25 then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.D, false, game)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.A, false, game)
                elseif dot < -0.25 then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.A, false, game)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.D, false, game)
                else
                    Cleanup.releaseSteerKeys()
                end
            end
        end
    end)
    Cleanup.addConnection(steerConnection)
end
return CauldronSteer
