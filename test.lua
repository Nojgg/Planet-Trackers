-- Add LuaRocks paths so Lua can find the modules
package.path   = package.path .. ";C:/msys64/home/odin7/.luarocks/share/lua/5.4/?.lua;C:/msys64/home/odin7/.luarocks/share/lua/5.4/?/init.lua"
package.cpath  = package.cpath .. ";C:/msys64/home/odin7/.luarocks/lib/lua/5.4/?.dll"

-- Now your requires will work
local socket = require("socket")
local https = require("ssl.https")


local json   = require("dkjson")
local ltn12  = require("ltn12")
local os     = require("os")
local math   = require("math")
local io     = require("io")

-- Observer location (Le Havre)
local lat = 49.4944
local lon = 0.1079

-- Load planets JSON
local file = io.open("KeplerianElements.json", "r")
if not file then error("Cannot open KeplerianElements.json") end
local content = file:read("*a")
file:close()
local planetsData = json.decode(content)

-- Planet Horizons IDs
local planetIDs = {
    Mercury = 199,
    Venus   = 299,
    ["EM Bary"] = 399,
    Earth   = 399,
    Mars    = 499,
    Jupiter = 599,
    Saturn  = 699,
    Uranus  = 799,
    Neptune = 899
}

-- Fetch Horizons JSON via HTTPS
local function fetchHorizons(id, dateTime)
    local url = string.format(
        "https://ssd.jpl.nasa.gov/api/horizons.api?format=json" ..
        "&COMMAND=%d&MAKE_EPHEM=YES&EPHEM_TYPE=OBSERVER" ..
        "&CENTER='500@399'&START_TIME='%s'&STOP_TIME='%s'&STEP_SIZE='1 min'&QUANTITIES='1,9,20'",
        id, dateTime, dateTime
    )

    local response_body = {}
    local _, code = https.request{url=url, sink=ltn12.sink.table(response_body)}
    if code ~= 200 then return nil, "HTTP error code " .. tostring(code) end

    local body = table.concat(response_body)
    local data, _, err = json.decode(body)
    if not data then return nil, "JSON decode failed: " .. tostring(err) end
    return data
end

-- Extract RA/DEC from Horizons ephemeris line
local function extractRADec(line)
    -- Matches: "HH MM SS.s +/-DD MM SS.s"
    local h, m, s, d, dm, ds = line:match("(%d+)%s+(%d+)%s+([%d%.]+)%s+([%+%-]?%d+)%s+(%d+)%s+([%d%.]+)")
    if h and m and s and d and dm and ds then
        return string.format("%s:%s:%s", h, m, s), string.format("%s:%s:%s", d, dm, ds)
    end
    return nil, nil
end

-- Convert RA h:m:s to degrees
local function raToDeg(ra)
    local h, m, s = ra:match("(%d+):(%d+):([%d%.]+)")
    return (tonumber(h) + tonumber(m)/60 + tonumber(s)/3600) * 15
end

-- Convert DEC d:m:s to degrees
local function decToDeg(dec)
    local sign = 1
    if dec:sub(1,1) == "-" then sign = -1 end
    local d, m, s = dec:match("([%+%-]?%d+):(%d+):([%d%.]+)")
    return sign * (math.abs(tonumber(d)) + tonumber(m)/60 + tonumber(s)/3600)
end

-- Compute Alt/Az from RA/DEC, latitude, and Local Sidereal Time
local function computeAltAz(RA_deg, DEC_deg, lat_deg, LST_deg)
    local RA_rad  = math.rad(RA_deg)
    local DEC_rad = math.rad(DEC_deg)
    local lat_rad = math.rad(lat_deg)
    local HA_rad  = math.rad(LST_deg - RA_deg)

    local Alt = math.asin(math.sin(DEC_rad)*math.sin(lat_rad) +
                          math.cos(DEC_rad)*math.cos(lat_rad)*math.cos(HA_rad))
    local AZ = math.atan(-math.sin(HA_rad),
        math.tan(DEC_rad)*math.cos(lat_rad) - math.sin(lat_rad)*math.cos(HA_rad))

    Alt = math.deg(Alt)
    AZ  = math.deg(AZ)
    if AZ < 0 then AZ = AZ + 360 end
    return Alt, AZ
end

-- Compute Local Sidereal Time in degrees
local function getLST()
    local t = os.date("!*t")
    local year, month, day = t.year, t.month, t.day
    local hour, min, sec = t.hour, t.min, t.sec

    if month <= 2 then
        year = year - 1
        month = month + 12
    end

    local A = math.floor(year / 100)
    local B = 2 - A + math.floor(A / 4)
    local JD = math.floor(365.25*(year+4716)) + math.floor(30.6001*(month+1)) + day + B - 1524.5
    JD = JD + (hour + min/60 + sec/3600)/24

    local T = (JD - 2451545.0)/36525
    local GMST = (280.46061837 + 360.98564736629*(JD-2451545) + 0.000387933*T*T - T*T*T/38710000) % 360
    return (GMST + lon) % 360
end

-- Main loop
local dateTime = os.date("%Y-%m-%d %H:%M")
print("Querying Horizons at time:", dateTime)

local LST = getLST()

for _, planet in ipairs(planetsData) do
    local id = planetIDs[planet.name]
    if not id then
        print("Skipping unknown planet:", planet.name)
    else
        local data, err = fetchHorizons(id, dateTime)
        if not data then
            print("ERROR fetching", planet.name, "->", err)
        else
            local inEphem = false
            local foundRA, foundDEC

            for line in data.result:gmatch("[^\r\n]+") do
                if line:match("%$%$SOE") then inEphem = true
                elseif line:match("%$%$EOE") then break
                elseif inEphem then
                    local RA_s, DEC_s = extractRADec(line)
                    if RA_s then foundRA, foundDEC = RA_s, DEC_s; break end
                end
            end

            if not foundRA then
                print("ERROR: Could not extract RA/DEC for", planet.name)
            else
                local RA_deg = raToDeg(foundRA)
                local DEC_deg = decToDeg(foundDEC)
                local Alt, AZ = computeAltAz(RA_deg, DEC_deg, lat, LST)
                print(string.format("%s: Alt=%.2f°, Az=%.2f°  RA=%s  DEC=%s",
                    planet.name, Alt, AZ, foundRA, foundDEC))
                if Alt > 0 then
                    print("  Visible now!")
                else
                    print("  Below horizon.")
                end
            end
        end
    end
end