-- Add dkjson path if needed
package.path = package.path .. ";C:/ProgramData/chocolatey/lib/luarocks/luarocks-2.4.4-win32/systree/share/lua/5.1/?.lua"

local json = require("dkjson")
local os = require("os")
local math = require("math")
local io = require("io")

-- Observer location
local lat = 49.4944   -- Le Havre latitude
local lon = 0.1079    -- Le Havre longitude

-- Load your JSON of orbital elements (kept in case you need)
local file = io.open("KeplerianElements.json", "r")
local content = file:read("*a")
file:close()
local planetsData = json.decode(content)

-- Map planet names to Horizons IDs
local planetIDs = {
    Mercury = "199",
    Venus = "299",
    ["EM Bary"] = "399",
    Earth = "399",
    Mars = "499",
    Jupiter = "599",
    Saturn = "699",
    Uranus = "799",
    Neptune = "899"
}

-- Function to fetch Horizons JSON using curl
local function fetchHorizons(id, dateTime, lat, lon)
    local outFile = "temp.json"
    local url = string.format([[
https://ssd.jpl.nasa.gov/api/horizons.api?format=json&COMMAND='%s'&MAKE_EPHEM=YES&EPHEM_TYPE=OBSERVER&CENTER='coord@399'&SITE_COORD='0,%.4f,%.4f'&START_TIME='%s'&STOP_TIME='%s'&STEP_SIZE='1%%20min'&QUANTITIES='1,9,20'
    ]], id, lat, lon, dateTime, dateTime)

    -- Run curl command (silent, output to file)
    local cmd = string.format('curl -s "%s" -o %s', url, outFile)
    local result = os.execute(cmd)
    if result ~= 0 then
        return nil, "Failed to fetch data"
    end

    -- Read JSON file
    local f = io.open(outFile, "r")
    if not f then return nil, "Cannot open temp file" end
    local body = f:read("*a")
    f:close()

    local data, pos, err = json.decode(body)
    if not data then
        return nil, "JSON decode error: " .. tostring(err)
    end
    return data
end

-- Convert RA hms string to decimal degrees
local function raToDeg(ra)
    local h, m, s = ra:match("(%d+)h(%d+)m([%d%.]+)s")
    if h then
        return (tonumber(h) + tonumber(m)/60 + tonumber(s)/3600) * 15
    else
        return tonumber(ra) or 0
    end
end

-- Convert Dec dms string to decimal degrees
local function decToDeg(dec)
    local sign = 1
    local d, m, s = dec:match("([%-+]?%d+)d(%d+)'([%d%.]+)\"")
    if not d then
        -- Try simple format
        return tonumber(dec) or 0
    end
    if d:sub(1,1) == "-" then sign = -1 end
    return sign * (math.abs(tonumber(d)) + tonumber(m)/60 + tonumber(s)/3600)
end

-- Compute Alt/Az from RA/DEC
local function computeAltAz(RA_deg, DEC_deg, lat_deg, LST_deg)
    local RA_rad = RA_deg * math.pi / 180
    local DEC_rad = DEC_deg * math.pi / 180
    local lat_rad = lat_deg * math.pi / 180
    local HA_rad = (LST_deg - RA_deg) * math.pi / 180

    local Alt = math.asin(math.sin(DEC_rad) * math.sin(lat_rad) +
                          math.cos(DEC_rad) * math.cos(lat_rad) * math.cos(HA_rad))
    local AZ = math.atan(-math.sin(HA_rad),
                         math.tan(DEC_rad) * math.cos(lat_rad) - math.sin(lat_rad) * math.cos(HA_rad))
    Alt = Alt * 180 / math.pi
    AZ = AZ * 180 / math.pi
    if AZ < 0 then AZ = AZ + 360 end
    return Alt, AZ
end

-- Julian date and LST
local function getLST()
    local t = os.date("!*t")
    local year, month, day = t.year, t.month, t.day
    local hour, min, sec = t.hour, t.min, t.sec

    if month <= 2 then
        year = year - 1
        month = month + 12
    end

    local A = math.floor(year/100)
    local B = 2 - A + math.floor(A/4)
    local JD = math.floor(365.25*(year+4716)) + math.floor(30.6001*(month+1)) + day + B - 1524.5
    JD = JD + (hour + min/60 + sec/3600)/24

    local T = (JD - 2451545.0)/36525
    local GMST = 280.46061837 + 360.98564736629*(JD - 2451545) + 0.000387933*T*T - T*T*T/38710000
    local LST = GMST + lon
    while LST < 0 do LST = LST + 360 end
    while LST >= 360 do LST = LST - 360 end
    return LST
end

-- Main
local dateTime = os.date("%Y-%m-%d %H:%M")
print("Querying Horizons for time:\t", dateTime)
local LST = getLST()

for _, planet in ipairs(planetsData) do
    local id = planetIDs[planet.name]
    if not id then
        print("Skipping unknown planet:", planet.name)
    else
        local data, err = fetchHorizons(id, dateTime, lat, lon)
        if not data then
            print("Error for "..planet.name..":", err)
        else
            -- Extract RA/DEC
            local RA_str, DEC_str
            for line in data.result:gmatch("[^\r\n]+") do
                if line:match("RA=") then RA_str = line:match("RA=([%dshm%.]+)") end
                if line:match("DEC=") then DEC_str = line:match("DEC=([%+%-0-9dms\"']+)") end
            end

            if not RA_str or not DEC_str then
                print("Could not parse RA/DEC for "..planet.name)
            else
                local RA = raToDeg(RA_str)
                local DEC = decToDeg(DEC_str)
                local Alt, AZ = computeAltAz(RA, DEC, lat, LST)

                print(string.format("%s: Alt=%.2f°, Az=%.2f°", planet.name, Alt, AZ))
                if Alt > 0 then
                    print("  Visible now!")
                else
                    print("  Below horizon.")
                end
            end
        end
    end
end