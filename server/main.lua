local vpnDetectionCache = {}

local config = {
    vpnApis = {
        "http://ip-api.com/json/%s?fields=proxy,hosting",
        "https://ipqualityscore.com/api/json/ip/pPbiVMogvKoqUVJA/%s",
        "https://ipapi.co/%s/json/",
        "https://ipinfo.io/%s/json/"
    },
    cacheTime = 86400, 
    debug = false, 
    kickMessage = "You are not allowed to connect using a VPN or proxy."
}

-- Debug logging function
local function DebugLog(message)
    if config.debug then
        print("[Starlight AntiVPN] " .. message)
    end
 end

local function IsVPN(ip, callback)
    if vpnDetectionCache[ip] and vpnDetectionCache[ip].time > os.time() then
        DebugLog("Using cached result for IP: " .. ip)
        callback(vpnDetectionCache[ip].isVPN)
        return
    end
    
    local apiUrl = string.format(config.vpnApis[1], ip)
    DebugLog("Checking IP: " .. ip .. " with API")
    
    PerformHttpRequest(apiUrl, function(errorCode, resultData, resultHeaders)
        if errorCode ~= 200 then
            DebugLog("API error: " .. tostring(errorCode) .. ". Trying fallback API.")
            
            local fallbackUrl = string.format(config.vpnApis[2], ip)
            PerformHttpRequest(fallbackUrl, function(errorCode2, resultData2, resultHeaders2)
                if errorCode2 ~= 200 then
                    DebugLog("Fallback API error: " .. tostring(errorCode2) .. ". Allowing connection.")
                    callback(false)
                    return
                end
                
                local result = json.decode(resultData2)
                local isVPN = result and (result.proxy == true or result.vpn == true)
                
                vpnDetectionCache[ip] = {
                    isVPN = isVPN,
                    time = os.time() + config.cacheTime
                }
                
                callback(isVPN)
            end)
            return
        end
        
        local result = json.decode(resultData)
        local isVPN = result and (result.proxy == true or result.hosting == true)
        
        -- Cache the result
        vpnDetectionCache[ip] = {
            isVPN = isVPN,
            time = os.time() + config.cacheTime
        }
        
        callback(isVPN)
    end)
end

-- When a player connects
AddEventHandler('playerConnecting', function(playerName, setKickReason, deferrals)
    local source = source
    local ip = GetPlayerEndpoint(source) or ''
    local identifiers = GetPlayerIdentifiers(source)
    
    deferrals.defer()
    
    deferrals.update("AntiVPN - Checking your connection...")
    
    Citizen.Wait(500)
    
    if ip == '' then
        DebugLog("Could not retrieve IP for player: " .. playerName)
        deferrals.done("Could not retrieve your IP address. Please try again.")
        return
    end
    
    DebugLog("Player connecting: " .. playerName .. " with IP: " .. ip)
    
    IsVPN(ip, function(isVPN)
        if isVPN then
            DebugLog("VPN detected for player: " .. playerName .. " with IP: " .. ip)
            deferrals.done(config.kickMessage)
        else
            DebugLog("No VPN detected for player: " .. playerName .. ". Allowing connection.")
            deferrals.done()
        end
    end)
end)

RegisterCommand("clearvpncache", function(source, args, rawCommand)
    if source == 0 then 
        vpnDetectionCache = {}
        print("[Starlight AntiVPN] Cache cleared successfully.")
    end
end, true)

RegisterCommand("vpndebug", function(source, args, rawCommand)
    if source == 0 then
        config.debug = not config.debug
        print("[Starlight AntiVPN] Debug mode: " .. (config.debug and "enabled" or "disabled") .. ".")
    end
end, true)

print("[Starlight AntiVPN] System loaded successfully.")
