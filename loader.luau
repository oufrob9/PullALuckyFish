--!nocheck
--[[
  ========================================================================================
  🌸 PULL A LUCKY FISH — UNIFIED LOADER
  ========================================================================================
  Auteur : oufrob9 (https://github.com/oufrob9/PullALuckyFish)
  Charge facilement le script UI Sakura ou le Diagnostic Probe selon vos besoins.
  ========================================================================================
]]

local REPO_URL = "https://raw.githubusercontent.com/oufrob9/PullALuckyFish/main"

local function loadScript(filename)
    local fullUrl = string.format("%s/%s", REPO_URL, filename)
    local success, content = pcall(function()
        return game:HttpGet(fullUrl)
    end)
    if success and content and #content > 0 then
        local fn, err = loadstring(content)
        if fn then
            fn()
            print("🌸 [LOADER] " .. filename .. " lancé avec succès !")
        else
            warn("❌ [LOADER] Erreur de compilation : " .. tostring(err))
        end
    else
        warn("❌ [LOADER] Impossible de télécharger : " .. fullUrl)
    end
end

-- Par défaut, charge l'interface Sakura UI :
loadScript("ui_sakura.luau")

-- Pour charger le Probe de diagnostic sécurisé à la place, utilisez :
-- loadScript("debug_probe.luau")
