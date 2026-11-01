local Remotes = {}
local CALL_TIMEOUT = 3
local remoteMode = {}
local probeFailures = {}
local probeCooldownUntil = {}
local probeLearned = {}
function Remotes.runWithTimeout(timeout, fn)
    local done, packed = false, nil
    local thread = task.spawn(function()
        packed = table.pack(pcall(fn))
        done = true
    end)
    local t0 = os.clock()
    while not done and os.clock() - t0 < timeout do
        task.wait(0.03)
    end
    if not done then
        pcall(task.cancel, thread)
        return "timeout"
    end
    if packed[1] then
        return "ok", table.unpack(packed, 2, packed.n)
    end
    return "error", packed[2]
end
function Remotes.invoke(GameModules, name, ...)
    local remoteCollection = GameModules.Remotes
    if not remoteCollection then
        return false, "collection Remotes introuvable"
    end
    local okGet, remote = pcall(function() return remoteCollection[name] end)
    if not okGet or remote == nil then
        return false, "remote introuvable: " .. tostring(name)
    end
    local args = table.pack(...)
    if typeof(remote) == "Instance" then
        if remote:IsA("RemoteFunction") then
            local status, a = Remotes.runWithTimeout(CALL_TIMEOUT, function()
                return remote:InvokeServer(table.unpack(args, 1, args.n))
            end)
            return status == "ok", a
        end
        local ok, err = pcall(function()
            remote:FireServer(table.unpack(args, 1, args.n))
        end)
        return ok, err
    end
    local function fire()
        local status, err = Remotes.runWithTimeout(2, function()
            local f = remote.Fire or remote.fire
            if not f then error("pas de methode Fire") end
            f(remote, table.unpack(args, 1, args.n))
        end)
        return status == "ok", err
    end
    local function call()
        return Remotes.runWithTimeout(CALL_TIMEOUT, function()
            local c = remote.Call or remote.call
            if not c then error("pas de methode Call") end
            local p = c(remote, table.unpack(args, 1, args.n))
            if typeof(p) == "table" and type(p.Await) == "function" then
                return p:Await()
            end
            return p
        end)
    end
    local mode = remoteMode[name]
    if mode == "fire" then
        return fire()
    end
    local status, a, b = call()
    if status == "ok" then
        remoteMode[name] = "call"
        return true, a, b
    end
    if status == "timeout" then
        if mode == "call" then return false, "timeout" end
        remoteMode[name] = "fire"
        return true
    end
    if mode == "call" then
        return false, a
    end
    local okFire, err = fire()
    if okFire then
        remoteMode[name] = "fire"
    end
    return okFire, err
end
function Remotes.probe(State, GameModules, Logger, key, remoteName, variants, snap, changed, opts)
    opts = opts or {}
    local settle = (opts and opts.settle) or 1.2
    if os.clock() < (probeCooldownUntil[key] or 0) then
        return false
    end
    local function attempt(i)
        local build = variants[i]
        local args = build and build()
        if not args then return false end
        local before = snap()
        local len = args.n or #args
        if not Remotes.invoke(GameModules, remoteName, table.unpack(args, 1, len)) then
            return false
        end
        local t0 = os.clock()
        while State.Running and os.clock() - t0 < settle do
            task.wait(0.15)
            if changed(before, snap()) then
                return true
            end
        end
        return false
    end
    local idx = probeLearned[key]
    if idx and variants[idx] then
        if attempt(idx) then
            probeFailures[key] = 0
            return true
        end
        probeFailures[key] = (probeFailures[key] or 0) + 1
        if probeFailures[key] >= 8 then
            probeLearned[key] = nil
            probeFailures[key] = 0
            Logger.warn(string.format("Variante oubliee pour %s", key))
        elseif probeFailures[key] % 3 == 0 then
            probeCooldownUntil[key] = os.clock() + 60
        end
        return false
    end
    for i = 1, #variants do
        if not State.Running then return false end
        if attempt(i) then
            probeLearned[key] = i
            probeFailures[key] = 0
            Logger.info(string.format("Variante #%d validee pour %s", i, key))
            return true
        end
    end
    local cd = (opts and opts.cooldown) or 45
    if cd > 0 then
        probeCooldownUntil[key] = os.clock() + cd
    end
    return false
end
function Remotes.resetLearned()
    table.clear(probeLearned)
    table.clear(probeFailures)
    table.clear(probeCooldownUntil)
    table.clear(remoteMode)
end
return Remotes
