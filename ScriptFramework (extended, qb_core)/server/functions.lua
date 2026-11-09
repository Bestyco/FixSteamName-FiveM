-- # STEAM NAME # --
local SteamAPI = "INSERT_YOUR_STEAM_API_KEY"

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