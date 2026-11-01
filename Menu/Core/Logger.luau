local Logger = {}
local logsHistory = {}
local onNotifyCallback = nil
function Logger.setNotifyHandler(fn)
    onNotifyCallback = fn
end
local function formatMessage(...)
    local parts = table.pack(...)
    for i = 1, parts.n do
        parts[i] = tostring(parts[i])
    end
    local timeStr = os.date("%H:%M:%S")
    return string.format("[%s] [AutoCauldron] %s", timeStr, table.concat(parts, " "))
end
function Logger.info(...)
    local msg = formatMessage(...)
    print(msg)
    table.insert(logsHistory, msg)
    if #logsHistory > 100 then
        table.remove(logsHistory, 1)
    end
end
function Logger.warn(...)
    local msg = formatMessage(...)
    warn(msg)
    table.insert(logsHistory, "[WARN] " .. msg)
    if #logsHistory > 100 then
        table.remove(logsHistory, 1)
    end
end
function Logger.notify(title, message, duration)
    Logger.info(string.format("[%s] %s", title, message))
    if onNotifyCallback then
        pcall(onNotifyCallback, title, message, duration or 3)
    end
end
function Logger.getHistory()
    return logsHistory
end
return Logger
