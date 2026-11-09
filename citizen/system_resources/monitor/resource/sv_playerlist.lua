-- At Line 43 Paste This 
-- Helper to get Steam persona name via es_extended export if available
local ResourceFramework = "NAME_RESOURCE_INSERTED_FUNCTION_GetSteamName"
local function GetResolvedSteamName(src, fallbackName)
    local rawName = fallbackName or "unknown"
    if not src or tonumber(src) == nil or tonumber(src) <= 0 then
        return rawName
    end

    local success, resolvedName = pcall(function()
        if GetResourceState(ResourceFramework) == "started" then
            return exports[ResourceFramework]:GetSteamName(src)
        end
        return nil
    end)

    if success and resolvedName and resolvedName ~= "" then
        return resolvedName
    end
    return rawName
end

-- At Line 136 Replace AddEventHandler('playerJoining') With This
AddEventHandler('playerJoining', function(srcString, _oldID)
    local src = tonumber(source)
    if not src or src <= 0 then
        logError('playerJoining event with invalid source ' .. json.encode(source))
        return
    end

    -- Recupero iniziale protetto del nome FiveM
    local okName, fivemName = pcall(GetPlayerName, src)
    if not okName or type(fivemName) ~= 'string' or fivemName == '' then
        fivemName = "unknown"
    end

    -- Recupero protetto degli identificatori
    local okIds, identifiers = pcall(GetPlayerIdentifiers, src)
    if not okIds or type(identifiers) ~= 'table' then
        identifiers = {}
    end

    -- Recupero protetto dei tokens hwid
    local okTokens, tokens = pcall(GetPlayerTokens, src)
    if not okTokens or type(tokens) ~= 'table' then
        tokens = {}
    end

    -- 1. Risolvi subito il nome Steam se presente o usa il nome FiveM come fallback iniziale
    local initialSteamName = GetResolvedSteamName(src, fivemName)

    local playerData = {
        name = sub(initialSteamName or fivemName, 1, 128),
        ids = identifiers,
        hwids = tokens,
    }

    -- 2. Registra e invia IMMEDIATAMENTE a txAdmin così il giocatore compare nei player online
    PrintStructuredTrace(json.encode({
        type = 'txAdminPlayerlistEvent',
        event = 'playerJoining',
        id = src,
        player = playerData
    }))

    for adminID, _ in pairs(TX_ADMINS) do
        TriggerClientEvent('txcl:plist:updatePlayer', adminID, src, playerData.name)
    end

    -- 3. In asincrono (thread separato), se il nome Steam richiede tempo via API, aggiorna il playerData
    CreateThread(function()
        Wait(500)
        local updatedSteamName = GetResolvedSteamName(src, fivemName)
        if updatedSteamName and updatedSteamName ~= playerData.name and updatedSteamName ~= "unknown" then
            playerData.name = sub(updatedSteamName, 1, 128)
            if TX_PLAYERLIST[src] then
                TX_PLAYERLIST[src].name = sub(updatedSteamName, 1, 75)
            end
            for adminID, _ in pairs(TX_ADMINS) do
                TriggerClientEvent('txcl:plist:updatePlayer', adminID, src, playerData.name)
            end
        end
    end)
end)