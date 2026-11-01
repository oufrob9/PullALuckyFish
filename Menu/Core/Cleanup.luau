local VirtualInputManager = game:GetService("VirtualInputManager")
local Cleanup = {}
local activeConnections = {}
local activeThreads = {}
local cleanupCallbacks = {}
function Cleanup.addConnection(conn)
    if conn then
        table.insert(activeConnections, conn)
    end
    return conn
end
function Cleanup.addThread(th)
    if th then
        table.insert(activeThreads, th)
    end
    return th
end
function Cleanup.onCleanup(callback)
    table.insert(cleanupCallbacks, callback)
end
function Cleanup.releaseSteerKeys()
    pcall(function()
        if VirtualInputManager then
            local keys = { Enum.KeyCode.A, Enum.KeyCode.D, Enum.KeyCode.Left, Enum.KeyCode.Right }
            for _, k in ipairs(keys) do
                VirtualInputManager:SendKeyEvent(false, k, false, game)
            end
        end
    end)
end
function Cleanup.execute(State, Executor)
    State.Running = false
    State.AutoCast = false
    State.AutoSteer = false
    State.AutoReconnect = false
    State.AutoTpOnSpawn = false
    State.AutoBuyHalloweenShop = false
    State.AutoBuyDecoCrate = false
    Cleanup.releaseSteerKeys()
    State.CurrentTargetScreenPos = nil
    State.CurrentTargetCand = nil
    if Executor and type(Executor.unhookMouseLocation) == "function" then
        Executor.unhookMouseLocation()
    end
    for _, cb in ipairs(cleanupCallbacks) do
        pcall(cb)
    end
    table.clear(cleanupCallbacks)
    for _, conn in ipairs(activeConnections) do
        pcall(function()
            if conn and conn.Connected then
                conn:Disconnect()
            end
        end)
    end
    table.clear(activeConnections)
    for _, th in ipairs(activeThreads) do
        pcall(function()
            if th and coroutine.status(th) ~= "dead" then
                task.cancel(th)
            end
        end)
    end
    table.clear(activeThreads)
end
return Cleanup
