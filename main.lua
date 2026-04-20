local Backend = require("Backend")

-- --- CONFIGURATION ---
local SCOPE_FL, EYEPIECE_FL, EYEPIECE_AFOV = 900, 9, 66
local MAGNIFICATION = SCOPE_FL / EYEPIECE_FL
local TFOV_ARCSEC = (EYEPIECE_AFOV / MAGNIFICATION) * 3600

local planets_data, queue = {}, {}
local is_fetching, time_offset, selected_planet = false, 0, "Jupiter"
local night_mode = false

function love.load()
    love.window.setTitle("Hadley 114/900 Mission Control")
    love.window.setMode(1200, 800, {resizable=true})
    font_bold = love.graphics.newFont(16)
    font_small = love.graphics.newFont(12)
    font_tiny = love.graphics.newFont(10)
    refresh_data()
end

function refresh_data()
    if is_fetching then return end
    queue = {}
    for i, p in ipairs(Backend.planets) do table.insert(queue, p) end
    is_fetching = true
    process_next_in_queue()
end

function process_next_in_queue()
    if #queue == 0 then is_fetching = false return end
    local planet = table.remove(queue, 1)
    Backend.fetch_planet(planet, os.time() + time_offset, function(data, err)
        if data then planets_data[data.planet.name] = data end
        process_next_in_queue()
    end)
end

function love.update(dt) Backend.poll() end

-- HELPER: Apply Red Filter for Night Mode
local function set_color(r, g, b, a)
    if night_mode then
        -- Convert brightness to red-only
        local avg = (r + g + b) / 3
        love.graphics.setColor(avg, 0, 0, a or 1)
    else
        love.graphics.setColor(r, g, b, a or 1)
    end
end

function get_map_coords(alt, az, centerX, centerY, radius)
    if alt < 0 then return nil, nil end
    local r, theta = radius * (1 - (alt / 90)), math.rad(az - 90)
    return centerX + r * math.cos(theta), centerY + r * math.sin(theta)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    local list_w, bottom_h = 280, 180
    
    -- Background
    love.graphics.clear(0.01, 0.01, 0.03)

   -- --- 1. SIDEBAR ---
    set_color(0.05, 0.05, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, list_w, h)
    
    set_color(1, 1, 1, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("Hadley Observer Log", 20, 20)
    
    for i, p_info in ipairs(Backend.planets) do
        local data, y = planets_data[p_info.name], 60 + (i-1) * 65 -- Increased spacing to 65
        
        -- Highlight selection
        if selected_planet == p_info.name then
            set_color(1, 1, 1, 0.1)
            love.graphics.rectangle("fill", 5, y-5, list_w-10, 60, 5)
        end
        
        -- Planet Name
        set_color(p_info.color[1], p_info.color[2], p_info.color[3], 1)
        love.graphics.setFont(font_bold)
        love.graphics.print(p_info.name, 20, y)
        
        if data then
            love.graphics.setFont(font_tiny)
            -- Position Data
            set_color(0.8, 0.8, 0.8, 1)
            love.graphics.print(string.format("ALT: %.1f°  AZ: %.1f° (%s)", data.alt, data.az, data.cardinal), 20, y + 22)
            
            -- Rise/Set Times (New)
            set_color(0.5, 0.5, 0.7, 1)
            local time_info = string.format("↑ %s  ↓ %s", data.rise or "--:--", data.set or "--:--")
            love.graphics.print(time_info, 20, y + 38)
            
            -- Visibility indicator
            if data.visible then
                set_color(0.2, 1, 0.2, 1)
                love.graphics.circle("fill", list_w - 25, y + 10, 4)
            else
                set_color(0.4, 0.1, 0.1, 1)
                love.graphics.circle("fill", list_w - 25, y + 10, 4)
            end
        end
    end

    -- --- 2. PLANISPHERE (SKY MAP) ---
    -- Center the map in the remaining space above the bottom panel
    local map_cX = list_w + (w - list_w) / 2
    local map_cY = (h - bottom_h) / 2
    local map_R = math.min(w - list_w, h - bottom_h) * 0.42
    
    -- DRAW GRID CIRCLES (Altitude)
    love.graphics.setLineWidth(1)
    for a = 0, 90, 30 do
        local r = map_R * (1 - (a / 90))
        set_color(1, 1, 1, a == 0 and 0.3 or 0.1) -- Horizon is brighter
        love.graphics.circle("line", map_cX, map_cY, r)
        
        -- Altitude labels
        if a < 90 then
            set_color(0.5, 0.5, 0.5, 0.5)
            love.graphics.setFont(font_tiny)
            love.graphics.print(a .. "°", map_cX + 5, map_cY - r - 12)
        end
    end

    -- DRAW AZIMUTH SPOKES & CARDINAL DIRECTIONS
    local directions = {[0]="N", [45]="NE", [90]="E", [135]="SE", [180]="S", [225]="SW", [270]="W", [315]="NW"}
    for angle_deg = 0, 315, 45 do
        local angle_rad = math.rad(angle_deg - 90)
        local cos_a = math.cos(angle_rad)
        local sin_a = math.sin(angle_rad)
        
        -- Radial lines
        set_color(1, 1, 1, 0.05)
        love.graphics.line(map_cX, map_cY, map_cX + cos_a * map_R, map_cY + sin_a * map_R)
        
        -- Degree and Cardinal Labels
        set_color(0.8, 0.8, 0.8, 0.8)
        local label_r = map_R + 25
        local lx, ly = map_cX + cos_a * label_r, map_cY + sin_a * label_r
        
        love.graphics.setFont(font_small)
        local dir_text = directions[angle_deg] or ""
        love.graphics.printf(dir_text .. "\n" .. angle_deg .. "°", lx - 20, ly - 10, 40, "center")
    end

    -- DRAW PLANETS
    for _, p_info in ipairs(Backend.planets) do
        local data = planets_data[p_info.name]
        if data and data.visible then
            local x, y = get_map_coords(data.alt, data.az, map_cX, map_cY, map_R)
            
            -- Telrad Overlay for Selection
            if selected_planet == p_info.name then
                set_color(1, 0, 0, 0.4)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", x, y, 8)   -- Inner ring
                love.graphics.circle("line", x, y, 20)  -- Middle ring
                love.graphics.circle("line", x, y, 40)  -- Outer ring
            end

            set_color(p_info.color[1], p_info.color[2], p_info.color[3], 1)
            love.graphics.circle("fill", x, y, 5)
            love.graphics.setFont(font_small)
            love.graphics.print(p_info.name, x + 10, y - 10)
        end
    end

    -- --- 3. BOTTOM PANEL ---
    set_color(0.02, 0.02, 0.05, 1)
    love.graphics.rectangle("fill", list_w, h - bottom_h, w - list_w, bottom_h)
    set_color(1, 1, 1, 0.15)
    love.graphics.line(list_w, h - bottom_h, w, h - bottom_h)

    -- TIME AND CONTROLS
    set_color(1, 0.8, 0, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("UTC: " .. os.date("%H:%M", os.time() + time_offset), list_w + 20, h - bottom_h + 20)
    
    set_color(0.5, 0.5, 0.5, 1)
    love.graphics.setFont(font_tiny)
    love.graphics.print("N: Night Mode | Arrows: Time | Click Sidebar: Select", list_w + 20, h - bottom_h + 45)

    --

 -- --- 5. EYEPIECE VIEW (BOTTOM RIGHT) ---
    if selected_planet and planets_data[selected_planet] then
        local d = planets_data[selected_planet]
        local tx, ty, r = w - 120, h - 95, 80 -- Shifted slightly for space
        
        -- Eyepiece Background
        set_color(0.02, 0.02, 0.05, 1)
        love.graphics.circle("fill", tx, ty, r)
        set_color(1, 1, 1, 0.2)
        love.graphics.circle("line", tx, ty, r)
        
        -- Crosshair (Helps see movement/size)
        set_color(1, 1, 1, 0.05)
        love.graphics.line(tx - r, ty, tx + r, ty)
        love.graphics.line(tx, ty - r, tx, ty + r)

        -- Calculate Physical Pixel Size
        -- TFOV_ARCSEC is about 2376" for your Hadley+9mm.
        -- Jupiter is ~45", Saturn is ~18", Moon is ~1800".
        local ang_size = d.ang_size or 5
        local px_size = (ang_size / TFOV_ARCSEC) * (r * 2)
        
        -- Get Planet Color
        local p_color = {1, 1, 1}
        for _, info in ipairs(Backend.planets) do 
            if info.name == selected_planet then p_color = info.color end 
        end

        -- --- PLANET SPECIFIC FEATURES ---
        if selected_planet == "Saturn" then
            -- Draw Rings
            set_color(p_color[1], p_color[2], p_color[3], 0.6)
            love.graphics.ellipse("line", tx, ty, px_size * 1.2, px_size * 0.4)
            -- Draw Body
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", tx, ty, px_size / 2)

        elseif selected_planet == "Jupiter" then
            -- Draw Jupiter
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", tx, ty, px_size / 2)
            -- Draw Galilean Moons (Simulated positions)
            set_color(1, 1, 1, 0.8)
            local moon_offsets = {-2.5, -1.8, 1.5, 3.2} -- Distances in Jupiter-radii
            for _, offset in ipairs(moon_offsets) do
                local mx = tx + (offset * px_size)
                -- Only draw if inside the eyepiece
                if math.sqrt((mx-tx)^2) < r - 5 then
                    love.graphics.circle("fill", mx, ty + (math.random(-2,2)*0.1), 1.5)
                end
            end

        elseif selected_planet == "Mars" then
            -- Mars is tiny, let's make sure it's at least visible
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", tx, ty, math.max(2, px_size / 2))

        else
            -- Standard Body (Moon, Venus, etc)
            set_color(p_color[1], p_color[2], p_color[3], 1)
            -- Clamp size so Moon doesn't break the UI if it's too big
            local final_size = math.min(px_size, r * 1.8)
            love.graphics.circle("fill", tx, ty, final_size / 2)
        end
        
        -- Info Label
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_small)
        love.graphics.printf(selected_planet .. "\n" .. math.floor(MAGNIFICATION) .. "x\nSize: " .. string.format("%.1f\"", ang_size), tx - 70, ty + r + 10, 140, "center")
    end
end
function love.keypressed(k)
    if k == "n" then night_mode = not night_mode
    elseif k == "r" then time_offset = 0 refresh_data()
    elseif k == "right" then time_offset = time_offset + 3600 refresh_data()
    elseif k == "left" then time_offset = time_offset - 3600 refresh_data() end
end

function love.mousepressed(x, y, button)
    local list_w = 280 -- Must match the list_w used in love.draw
    local start_y = 60  -- The 'y' offset where the list begins
    local spacing = 65  -- The vertical gap between planet names

    -- Check if the click is within the sidebar width
    if x < list_w then
        -- Calculate which index was clicked based on the 65px spacing
        local index = math.floor((y - start_y) / spacing) + 1
        
        -- Bounds check: Ensure the index exists in our planet list
        if Backend.planets[index] then
            selected_planet = Backend.planets[index].name
            -- Optional: sound effect or print to console for debugging
            print("Selected: " .. selected_planet)
        end
    end
end