local HalloweenShop = {}
function HalloweenShop.getHalloweenCoins(GameModules, State)
    local coins = 0
    pcall(function()
        local state = GameModules.getState()
        local eventCfg = GameModules.HalloweenEventConfig
        if eventCfg and type(eventCfg.GetSpendable) == "function" then
            coins = eventCfg.GetSpendable(state) or 0
        elseif state.events then
            local eventId = (eventCfg and eventCfg.EventId) or "HalloweenEvent_2026_10"
            local ev = state.events[eventId]
            if ev and typeof(ev.coins) == "number" then
                coins = ev.coins
            end
        end
    end)
    State.HalloweenCoins = coins
    return coins
end
function HalloweenShop.buyHalloweenShopItem(
    Services,
    GameModules,
    State,
    Logger,
    itemId,
    displayName,
    price
)
    if not itemId then return false end
    local remotes = GameModules.Remotes
    if not remotes or not remotes.BuyHalloweenShopItem then return false end
    local coins = HalloweenShop.getHalloweenCoins(GameModules, State)
    if coins < price or coins < (State.MinCandyReserve or 0) then
        return false
    end
    local bought = false
    pcall(function()
        if type(remotes.BuyHalloweenShopItem.Fire) == "function" then
            remotes.BuyHalloweenShopItem:Fire(itemId)
            bought = true
            Logger.info(string.format("AutoBuy Halloween: Commande envoyee pour %s (%d Coins)", displayName, price))
            State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
        end
    end)
    if not bought then
        pcall(function()
            local shopCfg = GameModules.HalloweenEventShopConfig
            local tag = (shopCfg and shopCfg.Tag) or "HalloweenEventShopPedestals"
            for _, obj in ipairs(Services.CollectionService:GetTagged(tag)) do
                local prompt = obj:FindFirstChild("BuyHalloweenShopItem", true)
                if prompt and prompt:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                    fireproximityprompt(prompt)
                    bought = true
                    State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
                end
            end
        end)
    end
    return bought
end
function HalloweenShop.getCurrentHalloweenEggShopInfo(Services, GameModules, State)
    local serverTime = 0
    pcall(function() serverTime = Services.Workspace:GetServerTimeNow() end)
    if not serverTime or serverTime <= 0 then serverTime = os.time() end
    local eggId = nil
    local windowStart = math.floor(serverTime) - (math.floor(serverTime) % 900)
    local isSoldOut = false
    local shopCfg = GameModules.HalloweenEventShopConfig
    if shopCfg and type(shopCfg.CurrentItem) == "function" then
        pcall(function()
            eggId = shopCfg.CurrentItem(3, serverTime)
        end)
    end
    if not eggId then
        local seed = windowStart + (3 * 7919)
        local rng = Random.new(seed)
        local pool = { "HalloweenEggA", "HalloweenEggB" }
        eggId = pool[rng:NextInteger(1, 2)]
    end
    if shopCfg and type(shopCfg.IsSoldOut) == "function" then
        pcall(function()
            local st = GameModules.getState()
            if st then
                isSoldOut = shopCfg.IsSoldOut(st, 3, serverTime)
            end
        end)
    end
    if State.LastEggWindowBought == windowStart then
        isSoldOut = true
    end
    local price = (eggId == "HalloweenEggB" and 75000 or 25000)
    local displayName = (eggId == "HalloweenEggB" and "Cursed Egg" or "Spooky Egg")
    if shopCfg and shopCfg.Items and eggId and shopCfg.Items[eggId] then
        local itm = shopCfg.Items[eggId]
        if itm.Price then price = itm.Price end
        if itm.DisplayName then displayName = itm.DisplayName end
    end
    return {
        eggId = eggId,
        displayName = displayName,
        price = price,
        isSoldOut = isSoldOut,
        windowStart = windowStart,
        serverTime = serverTime,
    }
end
function HalloweenShop.checkAndAutoBuyAllShop(Services, GameModules, State, Logger)
    if not State.AutoBuyHalloweenShop or not State.Running then return end
    local now = tick()
    if now - (State.LastShopCheckAttempt or 0) < 1.0 then return end
    State.LastShopCheckAttempt = now
    local coins = HalloweenShop.getHalloweenCoins(GameModules, State)
    local shopCfg = GameModules.HalloweenEventShopConfig
    local serverTime = 0
    pcall(function() serverTime = Services.Workspace:GetServerTimeNow() end)
    if not serverTime or serverTime <= 0 then serverTime = os.time() end
    local eggInfo = HalloweenShop.getCurrentHalloweenEggShopInfo(Services, GameModules, State)
    if eggInfo and not eggInfo.isSoldOut then
        local shouldBuy = (eggInfo.eggId == "HalloweenEggA" and State.AutoBuyEggA)
            or (eggInfo.eggId == "HalloweenEggB" and State.AutoBuyEggB)
        if shouldBuy and coins >= eggInfo.price then
            if HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, eggInfo.eggId, eggInfo.displayName, eggInfo.price) then
                State.LastEggWindowBought = eggInfo.windowStart
            end
        end
    end
    if State.AutoBuyPetEgg and shopCfg and shopCfg.Items and shopCfg.Items.HalloweenPetEgg then
        local petPrice = shopCfg.Items.HalloweenPetEgg.Price or 300000
        local remaining = 1
        pcall(function()
            local st = GameModules.getState()
            if shopCfg.RemainingStock then
                remaining = shopCfg.RemainingStock(st, "HalloweenPetEgg", serverTime) or 0
            end
        end)
        if remaining > 0 and coins >= petPrice then
            HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, "HalloweenPetEgg", "Halloween Pet Egg", petPrice)
        end
    end
    if State.AutoBuyGodlyFloat and shopCfg and shopCfg.Items and shopCfg.Items.HalloweenFloat then
        local floatPrice = shopCfg.Items.HalloweenFloat.Price or 500000
        local soldOut = false
        pcall(function()
            if shopCfg.IsSoldOut then
                soldOut = shopCfg.IsSoldOut(GameModules.getState(), 6, serverTime)
            end
        end)
        if not soldOut and coins >= floatPrice then
            HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, "HalloweenFloat", "Flotteur Divin Halloween", floatPrice)
        end
    end
    if State.AutoBuyHauntedBase and shopCfg and shopCfg.Items and shopCfg.Items.HalloweenBase then
        local basePrice = shopCfg.Items.HalloweenBase.Price or 1500000
        local soldOut = false
        pcall(function()
            if shopCfg.IsSoldOut then
                soldOut = shopCfg.IsSoldOut(GameModules.getState(), 4, serverTime)
            end
        end)
        if not soldOut and coins >= basePrice then
            HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, "HalloweenBase", "Skin Base Halloween", basePrice)
        end
    end
    if State.AutoBuyWitchBroom and shopCfg and shopCfg.Items and shopCfg.Items.HalloweenMount then
        local mountPrice = shopCfg.Items.HalloweenMount.Price or 5000000
        local soldOut = false
        pcall(function()
            if shopCfg.IsSoldOut then
                soldOut = shopCfg.IsSoldOut(GameModules.getState(), 1, serverTime)
            end
        end)
        if not soldOut and coins >= mountPrice then
            HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, "HalloweenMount", "Monture Balai de Sorciere", mountPrice)
        end
    end
    if State.AutoBuyDeathScythe and shopCfg and shopCfg.Items and shopCfg.Items.HalloweenRod then
        local rodPrice = shopCfg.Items.HalloweenRod.Price or 20000000
        local soldOut = false
        pcall(function()
            if shopCfg.IsSoldOut then
                soldOut = shopCfg.IsSoldOut(GameModules.getState(), 2, serverTime)
            end
        end)
        if not soldOut and coins >= rodPrice then
            HalloweenShop.buyHalloweenShopItem(Services, GameModules, State, Logger, "HalloweenRod", "Canne Faux de la Mort", rodPrice)
        end
    end
end
function HalloweenShop.checkAndAutoUpgrade(GameModules, State, Logger)
    local remotes = GameModules.Remotes
    local upCfg = GameModules.HalloweenUpgradesConfig
    if not remotes or not remotes.HalloweenBuyUpgrade or not upCfg or not upCfg.Upgrades then
        return
    end
    local now = tick()
    if now - (State.LastUpgradeAttempt or 0) < 1.5 then return end
    State.LastUpgradeAttempt = now
    local coins = HalloweenShop.getHalloweenCoins(GameModules, State)
    local upgradeOrder = { "Capacity", "Luck", "Machine", "HeavierFish" }
    for _, upId in ipairs(upgradeOrder) do
        local enabled = false
        if upId == "Capacity" and State.AutoUpgradeCapacity then enabled = true end
        if upId == "Luck" and State.AutoUpgradeLuck then enabled = true end
        if upId == "Machine" and State.AutoUpgradeMachine then enabled = true end
        if upId == "HeavierFish" and State.AutoUpgradeHeavier then enabled = true end
        if enabled then
            pcall(function()
                local st = GameModules.getState()
                local stage = upCfg.GetPlayerStage(st, upId)
                local cost = upCfg.GetUpgradeCost(upId, stage)
                if cost and cost > 0 and coins >= cost and coins >= (State.MinCandyReserve or 0) then
                    local ok = remotes.HalloweenBuyUpgrade:Call(upId):Await()
                    if ok then
                        Logger.info(string.format("AutoUpgrade achete: %s (Niveau %d -> %d pour %d Coins)", upId, stage, stage + 1, cost))
                        State.Stats.ItemsPurchased = State.Stats.ItemsPurchased + 1
                    end
                end
            end)
        end
    end
end
function HalloweenShop.init(
    Services,
    State,
    GameModules,
    Logger,
    Cleanup
)
    local shopThread = task.spawn(function()
        while State.Running do
            pcall(function()
                HalloweenShop.getHalloweenCoins(GameModules, State)
                HalloweenShop.checkAndAutoBuyAllShop(Services, GameModules, State, Logger)
                HalloweenShop.checkAndAutoUpgrade(GameModules, State, Logger)
            end)
            task.wait(State.AutoBuyCheckInterval or 2.0)
        end
    end)
    Cleanup.addThread(shopThread)
end
return HalloweenShop
