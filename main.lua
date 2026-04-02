local json = require("dkjson")

-- Observer location
local lat = 49.4944   -- Le Havre latitude
local lon = 0.1079    -- Le Havre longitude (East positive)

-- Load JSON with planetary elements
local file = io.open("KeplerianElements.json", "r")
if not file then error("JSON file not found!") end
local content = file:read("*a")
file:close()

local planets, pos, err = json.decode(content)
if not planets then error("JSON decode error: " .. tostring(err)) end

print("Loaded "..#planets.." planets from JSON.")

-- Helper functions
local function deg2rad(d) return d * math.pi / 180 end
local function rad2deg(r) return r * 180 / math.pi end

-- Julian Date
local function julianDate()
    local t = os.date("!*t")
    local Y, M, D = t.year, t.month, t.day + (t.hour + t.min/60 + t.sec/3600)/24
    if M <= 2 then Y = Y - 1 M = M + 12 end
    local A = math.floor(Y/100)
    local B = 2 - A + math.floor(A/4)
    return math.floor(365.25*(Y+4716)) + math.floor(30.6001*(M+1)) + D + B - 1524.5
end

-- LST in radians
local function getLST(longitude)
    local JD = julianDate()
    local T = (JD - 2451545.0)/36525
    local GMST = 280.46061837 + 360.98564736629*(JD - 2451545) + 0.000387933*T*T - T*T*T/38710000
    local LST_deg = GMST + longitude
    while LST_deg < 0 do LST_deg = LST_deg + 360 end
    while LST_deg >= 360 do LST_deg = LST_deg - 360 end
    return deg2rad(LST_deg)
end

-- Solve Kepler's equation M = E - e*sin(E)
local function solveE(M, e)
    local E = M
    local delta = 1
    while delta > 1e-6 do
        local E_new = M + e * math.sin(E)
        delta = math.abs(E_new - E)
        E = E_new
    end
    return E
end

-- Compute heliocentric coordinates
local function heliocentricCoords(planet)
    local a = planet.a
    local e = planet.e
    local I = deg2rad(planet.I)
    local L = deg2rad(planet.L)
    local longPeri = deg2rad(planet.long_peri)
    local ascendingNode = deg2rad(planet.long_node)

    local M = L - longPeri
    local E = solveE(M, e)

    local xp = a * (math.cos(E) - e)
    local yp = a * math.sqrt(1 - e*e) * math.sin(E)

    local w = longPeri - ascendingNode

    local x = xp * (math.cos(ascendingNode)*math.cos(w) - math.sin(ascendingNode)*math.sin(w)*math.cos(I)) +
              yp * (-math.cos(ascendingNode)*math.sin(w) - math.sin(ascendingNode)*math.cos(w)*math.cos(I))
    local y = xp * (math.sin(ascendingNode)*math.cos(w) + math.cos(ascendingNode)*math.sin(w)*math.cos(I)) +
              yp * (-math.sin(ascendingNode)*math.sin(w) + math.cos(ascendingNode)*math.cos(w)*math.cos(I))
    local z = xp * math.sin(w)*math.sin(I) + yp * math.cos(w)*math.sin(I)

    return x, y, z
end

-- Convert heliocentric to RA/DEC
local function coordsToRADec(x, y, z)
    local r = math.sqrt(x*x + y*y + z*z)
    local RA = math.atan(y, x)
    if RA < 0 then RA = RA + 2*math.pi end
    local DEC = math.asin(z / r)
    return RA, DEC
end

-- Convert RA/DEC to Alt/Az
local function RADecToAltAz(RA, DEC, lat, LST)
    local latRad = deg2rad(lat)
    local HA = LST - RA
    while HA < -math.pi do HA = HA + 2*math.pi end
    while HA > math.pi do HA = HA - 2*math.pi end

    local Alt = math.asin(math.sin(DEC)*math.sin(latRad) + math.cos(DEC)*math.cos(latRad)*math.cos(HA))
    local AZ = math.atan(-math.sin(HA), math.tan(DEC)*math.cos(latRad) - math.sin(latRad)*math.cos(HA))
    if AZ < 0 then AZ = AZ + 2*math.pi end

    return rad2deg(Alt), rad2deg(AZ)
end

-- Main loop
local LST = getLST(lon)

for i = 1, #planets do
    local planet = planets[i]
    print("Computing "..planet.name.."...")
    local x, y, z = heliocentricCoords(planet)
    local RA, DEC = coordsToRADec(x, y, z)
    local Alt, AZ = RADecToAltAz(RA, DEC, lat, LST)

    print(string.format("%s: Alt = %.2f°, Az = %.2f°", planet.name, Alt, AZ))
    if Alt > 0 then
        print("  Visible now!")
        print(" ")
    else
        print("  Below horizon.")
        print(" ")
    end
end