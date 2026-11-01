local Executor = {}
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
Executor.hookfunction = hookfunction
Executor.getidentity = getthreadidentity or getidentity or (syn and syn.get_thread_identity)
Executor.setidentity = setthreadidentity or setidentity or (syn and syn.set_thread_identity)
Executor.fireproximityprompt = fireproximityprompt
Executor.firesignal = firesignal
Executor.getconnections = getconnections
Executor.gethui = gethui
Executor.readfile = readfile
Executor.writefile = writefile
Executor.isfile = isfile
Executor.makefolder = makefolder
Executor.isfolder = isfolder
function Executor.safeReadFile(path)
    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile(path) then
        local ok, data = pcall(readfile, path)
        if ok and data then return data end
    end
    return nil
end
function Executor.safeWriteFile(path, content)
    if typeof(writefile) == "function" then
        local ok = pcall(writefile, path, content)
        return ok
    end
    return false
end
function Executor.safeIsFile(path)
    if typeof(isfile) == "function" then
        local ok, res = pcall(isfile, path)
        return ok and res == true
    end
    return false
end
function Executor.bypassThrowAnimations(replicatedStorage)
    pcall(function()
        local clientDir = replicatedStorage:FindFirstChild("client")
        local throwDir = clientDir and clientDir:FindFirstChild("throw")
        local throwAnimMod = throwDir and throwDir:FindFirstChild("ThrowAnimations")
        if throwAnimMod and throwAnimMod:IsA("ModuleScript") then
            local throwAnim = require(throwAnimMod)
            if throwAnim and type(throwAnim.playShot) == "function" then
                local oldPlayShot = throwAnim.playShot
                throwAnim.playShot = function(...)
                    local oldId = nil
                    if Executor.getidentity and Executor.setidentity then
                        pcall(function()
                            oldId = Executor.getidentity()
                            Executor.setidentity(2)
                        end)
                    end
                    local results = table.pack(pcall(oldPlayShot, ...))
                    if oldId and Executor.setidentity then
                        pcall(Executor.setidentity, oldId)
                    end
                    if results[1] then
                        return table.unpack(results, 2, results.n)
                    end
                    return nil
                end
            end
        end
    end)
end
local originalGetMouseLocation = nil
local isMouseHooked = false
function Executor.hookMouseLocation(getOverridePos)
    if typeof(hookfunction) ~= "function" or isMouseHooked then return end
    pcall(function()
        originalGetMouseLocation = hookfunction(UserInputService.GetMouseLocation, function(self, ...)
            local targetPos = getOverridePos()
            if targetPos then
                return targetPos
            end
            if originalGetMouseLocation then
                return originalGetMouseLocation(self, ...)
            end
            return UserInputService:GetMouseLocation()
        end)
        isMouseHooked = true
    end)
end
function Executor.unhookMouseLocation()
    if isMouseHooked and originalGetMouseLocation and typeof(hookfunction) == "function" then
        pcall(function()
            hookfunction(UserInputService.GetMouseLocation, originalGetMouseLocation)
        end)
        isMouseHooked = false
        originalGetMouseLocation = nil
    end
end
function Executor.triggerPrompt(prompt)
    if not (prompt and prompt.Enabled) then return end
    if typeof(fireproximityprompt) == "function" then
        pcall(fireproximityprompt, prompt)
    else
        pcall(function()
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end)
    end
end
function Executor.activateGuiButton(btn)
    if not btn or not btn.Parent then return false end
    local fired = false
    if typeof(getconnections) == "function" then
        pcall(function()
            local events = { btn.MouseButton1Click, btn.MouseButton1Down, btn.Activated }
            for _, ev in ipairs(events) do
                if ev then
                    for _, conn in ipairs(getconnections(ev)) do
                        if conn.Function or conn.Fire then
                            conn:Fire()
                            fired = true
                        end
                    end
                end
            end
        end)
    end
    if not fired and typeof(firesignal) == "function" then
        pcall(function()
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
            fired = true
        end)
    end
    if not fired and typeof(btn.Activate) == "function" then
        pcall(function()
            btn:Activate()
            fired = true
        end)
    end
    if not fired and VirtualInputManager and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
        pcall(function()
            local x = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
            local y = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2 + 36
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.04)
            VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
            fired = true
        end)
    end
    if not fired and VirtualUser and btn.AbsoluteSize.X > 0 and btn.AbsoluteSize.Y > 0 then
        pcall(function()
            local x = btn.AbsolutePosition.X + btn.AbsoluteSize.X / 2
            local y = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y / 2
            VirtualUser:Button1Down(Vector2.new(x, y))
            task.wait(0.04)
            VirtualUser:Button1Up(Vector2.new(x, y))
            fired = true
        end)
    end
    return fired
end
return Executor
