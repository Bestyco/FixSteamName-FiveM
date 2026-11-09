# FixSteamName-FiveM #
Fix GetPlayerName(source) With Getting Name Steam And Not FiveM Name

# When Installed This Fix In Your Player List On TxAdmin Is Updated With Steam Name Players And Not FiveM Name #

# Modify You Server.cfg #
Remove String: set steam_webApiKey "EGVASEGgEWGEAWG" 
Insert String: set sv_enforceSteamAuth true 

# Modify Variables # 

# ResourceFramework #
Replace local ResourceFramework: "NAME_RESOURCE_INSERTED_FUNCTION_GetSteamName" 
With Your Resource Do You Have A Function --> ESX.GetSteamName / exports("GetSteamName") 

# SteamAPI #
Replace local SteamAPI = "INSERT_YOUR_STEAM_API_KEY" With Your Steam Api Key

# If You Need Name Steam Of Player In Another Script Use This #
#- Server Side -#
exports[ResourceFramework]:GetSteamName(source)

#- Client Side -# 
ESX.TriggerServerCallback("C-GetSteamName", function(res)
    if not res then return end 

    local SteamName = res 
end)

# If You Need Ever Steam Name With Function GetPlayerName(source) Do This # 
Replace GetPlayerName(source) With exports[ResourceFramework]:GetSteamName(source)

# How To Install This Fix #

- In citizen --> system_resources --> monitor --> resource --> sv_playerlist.lua 

# Paste This Code Under #
local vTypeMap = {
    ["nil"] = -1,
    ["walking"] = 0,
    ["automobile"] = 1,
    ["bike"] = 2,
    ["boat"] = 3,
    ["heli"] = 4,
    ["plane"] = 5,
    ["submarine"] = 6,
    ["trailer"] = 7,
    ["train"] = 8,
}

```lua 
-- Helper to get Steam persona name via es_extended export if available
local ResourceFramework = "NAME_RESOURCE_INSERTED_FUNCTION_GetSteamName" -- Replace With Your Resource Implemented A ESX.GetSteamName()
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
``` 

# Paste This Code Replacing AddEventHandler('playerJoining') With This #

```lua 
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
``` 

# In ScriptFamework (es_extended, qb_core) On functions.lua *Server Side* Paste This Code #

```lua 
-- # STEAM NAME # --
local SteamAPI = "INSERT_YOUR_STEAM_API_KEY" -- Replace With Your Steam API Key 

-- Helper: convert hex string to 64-bit decimal string (SteamID64)
local function hexToSteamId64(hex)
    if not hex then return nil end
    hex = string.lower(hex):gsub("^steam:", "")
    local dec = { 0 }
    for i = 1, #hex do
        local carry = tonumber(hex:sub(i, i), 16)
        if not carry then return nil end
        for j = 1, #dec do
            local val = dec[j] * 16 + carry
            dec[j] = val % 10
            carry = math.floor(val / 10)
        end
        while carry > 0 do
            dec[#dec + 1] = carry % 10
            carry = math.floor(carry / 10)
        end
    end
    local res = ""
    for i = #dec, 1, -1 do
        res = res .. tostring(dec[i])
    end
    return res
end

local steamNameCache = {}

-- Native Player Name On Steam (Get Server Side)
function ESX.GetSteamName(source)
    local playerId = tostring(source) 
    local rawName = GetPlayerName(playerId) or "unknown"
    local steamhex = nil 

    local identifiers = GetPlayerIdentifiers(playerId)
    if not identifiers then
        return rawName
    end

    for _, id in ipairs(identifiers) do 
        if id and string.sub(id, 1, 6) == "steam:" then 
            steamhex = string.sub(id, 7)
            break 
        end
    end

    if not steamhex then 
        return rawName
    end

    if steamNameCache[steamhex] then
        return steamNameCache[steamhex]
    end

    local steamId64 = hexToSteamId64(steamhex)
    if not steamId64 then 
        return rawName
    end

    local p = promise.new()
    local endpoint = ("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s"):format(SteamAPI, steamId64)

    PerformHttpRequest(endpoint, function(stsCode, responseText, headers)
        if stsCode == 200 and responseText then 
            local success, data = pcall(json.decode, responseText)
            if success and data and data.response and data.response.players and #data.response.players > 0 then 
                local persona = data.response.players[1].personaname
                if persona and persona ~= "" then
                    steamNameCache[steamhex] = persona
                    p:resolve(persona)
                    return
                end
            end
        end

        p:resolve(rawName)
    end, "GET", "", {["Content-Type"] = "application/json"})

    -- Timeout di sicurezza
    CreateThread(function()
        Wait(2500)
        p:resolve(rawName)
    end)

    local name = Citizen.Await(p)
    return name or rawName
end

-- Native Player Name On Steam (Get Server Callback)
ESX.RegisterServerCallback('S-GetSteamName', function(source, cb)
    local src = source 
    local name = ESX.GetSteamName(src)
    cb(name)
end)

-- Native Player Name On Steam (Get Client Callback)
ESX.RegisterServerCallback('C-GetSteamName', function(source, cb)
    local src = source 
    local name = ESX.GetSteamName(src)
    cb(name)
end)

-- Native Export For TxAdmin Use
exports('GetSteamName', function(source)
    return ESX.GetSteamName(source)
end)
``` 