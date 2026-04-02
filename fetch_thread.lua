-- fetch_thread.lua
local http = require("socket.http")
local json = require("dkjson")

-- Get planets table from main thread
local channel = love.thread.getChannel("planets_request")
local planets = channel:demand()  -- blocks only this thread, not main thread

for _, planet in ipairs(planets) do
    local baseURL = "https://ssd.jpl.nasa.gov/api/horizons.api"
    local params = "?format=json" ..
                   "&COMMAND='" .. planet.id .. "'" ..
                   "&CENTER='@sun'" ..
                   "&EPHEM_TYPE='VECTORS'" ..
                   "&START_TIME='now'" ..
                   "&STOP_TIME='now'" ..
                   "&STEP_SIZE='1 sec'"

    local url = baseURL .. params
    local body, code = http.request(url)
    if body and code == 200 then
        local data, _, err = json.decode(body, 1, nil)
        if data then
            local x_str, y_str = data.result:match("X%s*=%s*([%-%d%.E+]+)%s*Y%s*=%s*([%-%d%.E+]+)")
            if x_str and y_str then
                planet.x = tonumber(x_str)
                planet.y = tonumber(y_str)
            end
        end
    end
end

-- Push updated planets back to main thread
local result_channel = love.thread.getChannel("planets")
result_channel:push(planets)