local DecoCrates = {}
function DecoCrates.buyDecoCrate(RemotesUtils, GameModules, State, Logger)
    local defaultId = "FunctionalObjectsCrate"
    local s = GameModules.getState()
    local decoStock = s.decorationsStoreStock or {}
    local candidateIds = { defaultId }
    for k, v in pairs(decoStock) do
        if type(k) == "string" and string.find(k, "Crate") and not table.find(candidateIds, k) then
            table.insert(candidateIds, k)
        end
    end
    for _, id in ipairs(candidateIds) do
        local function stock()
            return tonumber((GameModules.getState().decorationsStoreStock or {})[id]) or 0
        end
        if stock() > 0 then
            RemotesUtils.probe(
                State,
                GameModules,
                Logger,
                id == defaultId and "BuyDecorationsStoreItem" or ("BuyDecorationsStoreItem_" .. id),
                "BuyDecorationsStoreItem",
                {
                    function() return { id } end,
                    function() return { id, 1 } end,
                    function() return { { ItemId = id } } end,
                },
                function()
                    return {
                        stock = stock(),
                        stack = GameModules.stackOf(GameModules.getState(), id),
                    }
                end,
                function(b, a)
                    return a.stock < b.stock or a.stack > b.stack
                end
            )
        end
    end
end
function DecoCrates.init(
    Services,
    State,
    GameModules,
    RemotesUtils,
    Logger,
    Cleanup
)
    local decoThread = task.spawn(function()
        while State.Running do
            if State.AutoBuyDecoCrate then
                pcall(function()
                    DecoCrates.buyDecoCrate(RemotesUtils, GameModules, State, Logger)
                end)
            end
            task.wait(State.AutoBuyCheckInterval or 2.0)
        end
    end)
    Cleanup.addThread(decoThread)
end
return DecoCrates
