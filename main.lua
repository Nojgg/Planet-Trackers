local Backend = require("Backend")

local SCOPE_FL = 900
local EYEPIECE_FL = 9
local EYEPIECE_AFOV = 66
app_mode = "log" 

local planets_data = {}
local queue = {}
local is_fetching = false
local time_offset = 0
local selected_planet = "Jupiter"
local night_mode = false
local loc_status = "Locating..."

local scroll_y = 0
local max_scroll = 0

-- Separate dedicated scrolling tracker for the journal viewer history list
local journal_scroll_y = 0
local journal_max_scroll = 0

local active_input = nil 
local custom_name = ""
local custom_id = ""

local log_notes = ""
local saved_logs = {}

local idle_time = 0
local is_dimmed = false

local hold_timers = { left = 0, right = 0, plus = 0, minus = 0 }
local HOLD_SPEED = 0.15 

function love.load()
    love.window.setTitle("Universal Telescope Mission Control")
    love.window.setMode(1200, 800, {resizable=true})
    
    font_bold = love.graphics.newFont(16)
    font_small = love.graphics.newFont(12)
    font_tiny = love.graphics.newFont(10)
    
    if love.filesystem.getInfo("observer_journal.txt") then
        for line in love.filesystem.lines("observer_journal.txt") do
            table.insert(saved_logs, line)
        end
    end
    
    Backend.initLocation()
    refresh_data()
end

function refresh_data()
    if is_fetching then return end
    queue = {}
    for i, p in ipairs(Backend.planets) do 
        table.insert(queue, p) 
    end
    is_fetching = true
    process_next_in_queue()
end

function process_next_in_queue()
    if #queue == 0 then 
        is_fetching = false 
        return 
    end
    local planet = table.remove(queue, 1)
    Backend.fetch_planet(planet, os.time() + time_offset, function(data, err)
        if data then 
            planets_data[data.planet.name] = data 
        end
        process_next_in_queue()
    end)
end

function love.update(dt) 
    Backend.poll() 

    idle_time = idle_time + dt
    if idle_time > 120 then 
        is_dimmed = true 
    end

    if Backend.updateLocation() then
        loc_status = string.format("Lat: %.2f Lon: %.2f", Backend.lat, Backend.lon)
        refresh_data() 
    end

    local trigger_refresh = false
    
    if love.keyboard.isDown("right") then
        hold_timers.right = hold_timers.right - dt
        if hold_timers.right <= 0 then
            time_offset = time_offset + 3600
            trigger_refresh = true
            hold_timers.right = HOLD_SPEED
        end
    else hold_timers.right = 0 end

    if love.keyboard.isDown("left") then
        hold_timers.left = hold_timers.left - dt
        if hold_timers.left <= 0 then
            time_offset = time_offset - 3600
            trigger_refresh = true
            hold_timers.left = HOLD_SPEED
        end
    else hold_timers.left = 0 end

    if not active_input then
        if love.keyboard.isDown("=", "kp+") then
            hold_timers.plus = hold_timers.plus - dt
            if hold_timers.plus <= 0 then
                EYEPIECE_FL = EYEPIECE_FL + 1
                hold_timers.plus = HOLD_SPEED
            end
        else hold_timers.plus = 0 end

        if love.keyboard.isDown(")", "kp-") then
            hold_timers.minus = hold_timers.minus - dt
            if hold_timers.minus <= 0 then
                EYEPIECE_FL = math.max(1, EYEPIECE_FL - 1)
                hold_timers.minus = HOLD_SPEED
            end
        else hold_timers.minus = 0 end
    end

    if trigger_refresh then 
        refresh_data() 
    end
end

function love.mousemoved(x, y, dx, dy)
    idle_time = 0
    is_dimmed = false
end

function love.wheelmoved(x, y)
    idle_time = 0
    is_dimmed = false
    local w, h = love.graphics.getDimensions()
    local list_w = math.max(240, math.floor(w * 0.25))

    -- Distribute wheel events dynamically depending on which tab frame the mouse is hover-focused on
    if love.mouse.getX() < list_w then
        if app_mode == "log" then
            scroll_y = scroll_y - (y * 30)
            scroll_y = math.max(0, math.min(scroll_y, max_scroll))
        elseif app_mode == "journal" then
            journal_scroll_y = journal_scroll_y - (y * 30)
            journal_scroll_y = math.max(0, math.min(journal_scroll_y, journal_max_scroll))
        end
    end
end

local function set_color(r, g, b, a)
    if night_mode then
        local luminance = (r + g + b) / 3
        love.graphics.setColor(luminance, 0, 0, a or 1)
    else
        love.graphics.setColor(r, g, b, a or 1)
    end
end

function get_map_coords(alt, az, centerX, centerY, radius)
    if alt < 0 then return nil, nil end
    local r = radius * (1 - (alt / 90))
    local theta = math.rad(az - 90)
    return centerX + r * math.cos(theta), centerY + r * math.sin(theta)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    
    -- Responsive sizing thresholds to guarantee layout visibility at small dimensions
    local list_w = math.max(240, math.floor(w * 0.25))
    local bottom_h = math.max(150, math.floor(h * 0.22))
    local header_h = 70 
    local tab_h = 40
    local tab_count = 3
    local each_tab_w = math.floor((list_w - 10) / tab_count)

    love.graphics.clear(0.01, 0.01, 0.03)

    love.graphics.push("all")
    set_color(0.05, 0.05, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, list_w, h)
    
    set_color(1, 1, 1, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("Observer Dashboard", 20, 20)
    
    set_color(0.4, 0.4, 0.6, 1)
    love.graphics.setFont(font_tiny)
    love.graphics.print(loc_status, 20, 42)

    love.graphics.setColor(0.05, 0.05, 0.1, 1) 
    love.graphics.rectangle("fill", 0, header_h, list_w, tab_h)

    -- Tab 1: LOG
    if app_mode == "log" then love.graphics.setColor(0.92, 0.72, 0.22, 1) 
    else love.graphics.setColor(0.1, 0.15, 0.25, 1) end
    love.graphics.rectangle("fill", 5, header_h + 5, each_tab_w - 4, tab_h - 10, 4)

    -- Tab 2: SPECS
    if app_mode == "specs" then love.graphics.setColor(0.92, 0.72, 0.22, 1) 
    else love.graphics.setColor(0.1, 0.15, 0.25, 1) end
    love.graphics.rectangle("fill", 5 + each_tab_w, header_h + 5, each_tab_w - 4, tab_h - 10, 4)

    -- Tab 3: JOURNAL (New feature window)
    if app_mode == "journal" then love.graphics.setColor(0.92, 0.72, 0.22, 1) 
    else love.graphics.setColor(0.1, 0.15, 0.25, 1) end
    love.graphics.rectangle("fill", 5 + (each_tab_w * 2), header_h + 5, each_tab_w - 4, tab_h - 10, 4)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font_tiny)
    love.graphics.printf("LOG", 5, header_h + 14, each_tab_w - 4, "center")
    love.graphics.printf("SPECS", 5 + each_tab_w, header_h + 14, each_tab_w - 4, "center")
    love.graphics.printf("JOURNAL", 5 + (each_tab_w * 2), header_h + 14, each_tab_w - 4, "center")
    
    local start_y = header_h + tab_h + 10
    local view_h = h - bottom_h - start_y

    if app_mode == "log" then
        local spacing = 65
        love.graphics.setScissor(0, start_y, list_w, view_h)
        love.graphics.push()
        love.graphics.translate(0, -scroll_y)

        for i, p_info in ipairs(Backend.planets) do
            local data = planets_data[p_info.name]
            local y = start_y + (i-1) * spacing 
            
            if selected_planet == p_info.name then
                set_color(1, 1, 1, 0.1)
                love.graphics.rectangle("fill", 5, y-5, list_w-10, 60, 5)
            end
            
            set_color(p_info.color[1], p_info.color[2], p_info.color[3], 1)
            love.graphics.setFont(font_bold)
            love.graphics.print(p_info.name, 20, y)
            
            if data then
                love.graphics.setFont(font_tiny)
                set_color(0.8, 0.8, 0.8, 1)
                love.graphics.print(string.format("ALT: %.1f°  AZ: %.1f° (%s)", data.alt, data.az, data.cardinal), 20, y + 22)
                set_color(0.5, 0.5, 0.7, 1)
                love.graphics.print(string.format("↑ %s  ↓ %s", data.rise or "--:--", data.set or "--:--"), 20, y + 38)
                
                if data.visible then set_color(0.2, 1, 0.2, 1) else set_color(0.4, 0.1, 0.1, 1) end
                love.graphics.circle("fill", list_w - 20, y + 10, 4)
            end
        end
        max_scroll = math.max(0, (#Backend.planets * spacing) - view_h + 20)
        love.graphics.pop()
        love.graphics.setScissor()
        
    elseif app_mode == "specs" then
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_bold)
        love.graphics.print("Equipment Profiles", 20, start_y)
        
        love.graphics.setFont(font_small)
        local box_w = math.min(100, list_w - 150)
        
        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.print("Scope FL (mm):", 20, start_y + 35)
        if active_input == "scope" then set_color(0.2, 0.4, 0.8, 1) else set_color(0.15, 0.15, 0.25, 1) end
        love.graphics.rectangle("fill", list_w - box_w - 15, start_y + 30, box_w, 24, 4)
        set_color(1, 1, 1, 1)
        love.graphics.print(SCOPE_FL .. (active_input == "scope" and "|" or ""), list_w - box_w - 7, start_y + 34)

        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.print("Eyepiece FL (mm):", 20, start_y + 75)
        if active_input == "eyepiece" then set_color(0.2, 0.4, 0.8, 1) else set_color(0.15, 0.15, 0.25, 1) end
        love.graphics.rectangle("fill", list_w - box_w - 15, start_y + 70, box_w, 24, 4)
        set_color(1, 1, 1, 1)
        love.graphics.print(EYEPIECE_FL .. (active_input == "eyepiece" and "|" or ""), list_w - box_w - 7, start_y + 74)

        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.print("Eyepiece AFOV (°):", 20, start_y + 115)
        if active_input == "afov" then set_color(0.2, 0.4, 0.8, 1) else set_color(0.15, 0.15, 0.25, 1) end
        love.graphics.rectangle("fill", list_w - box_w - 15, start_y + 110, box_w, 24, 4)
        set_color(1, 1, 1, 1)
        love.graphics.print(EYEPIECE_AFOV .. (active_input == "afov" and "|" or ""), list_w - box_w - 7, start_y + 114)

        local calculated_mag = EYEPIECE_FL > 0 and (SCOPE_FL / EYEPIECE_FL) or 0
        set_color(0.6, 0.6, 0.8, 1)
        love.graphics.print("Resulting Mag: " .. string.format("%.1fx", calculated_mag), 20, start_y + 150)
        
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_bold)
        love.graphics.print("Bookmark Target", 20, start_y + 190)
        
        love.graphics.setFont(font_tiny)
        local input_long_w = list_w - 40
        
        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.print("Target Name:", 20, start_y + 220)
        if active_input == "custom_name" then set_color(0.2, 0.4, 0.8, 1) else set_color(0.15, 0.15, 0.25, 1) end
        love.graphics.rectangle("fill", 20, start_y + 235, input_long_w, 20, 4)
        set_color(1, 1, 1, 1)
        love.graphics.print(custom_name .. (active_input == "custom_name" and "|" or ""), 26, start_y + 239)

        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.print("Horizons ID/Des:", 20, start_y + 265)
        if active_input == "custom_id" then set_color(0.2, 0.4, 0.8, 1) else set_color(0.15, 0.15, 0.25, 1) end
        love.graphics.rectangle("fill", 20, start_y + 280, input_long_w, 20, 4)
        set_color(1, 1, 1, 1)
        love.graphics.print(custom_id .. (active_input == "custom_id" and "|" or ""), 26, start_y + 284)

        set_color(0.2, 0.6, 0.3, 1)
        love.graphics.rectangle("fill", 20, start_y + 315, input_long_w, 25, 4)
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_small)
        love.graphics.printf("REGISTER TARGET", 20, start_y + 320, input_long_w, "center")
        
    elseif app_mode == "journal" then
        -- --- NEW INTERACTIVE JOURNAL VIEWER HISTORY DIRECTORY TAB LAYER ---
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_bold)
        love.graphics.print("Session Log Entries", 20, start_y)

        local journal_spacing = 45
        love.graphics.setScissor(0, start_y + 25, list_w, view_h - 30)
        love.graphics.push()
        love.graphics.translate(0, -journal_scroll_y)

        if #saved_logs == 0 then
            set_color(0.5, 0.5, 0.5, 1)
            love.graphics.setFont(font_tiny)
            love.graphics.printf("No recorded observation notes found in this session roster yet.", 20, start_y + 40, list_w - 40, "left")
        else
            for i, entry_text in ipairs(saved_logs) do
                local entry_y = start_y + 35 + (i - 1) * journal_spacing
                set_color(0.1, 0.1, 0.18, 0.6)
                love.graphics.rectangle("fill", 10, entry_y - 4, list_w - 20, journal_spacing - 8, 4)
                
                set_color(0.9, 0.9, 0.9, 1)
                love.graphics.setFont(font_tiny)
                love.graphics.printf(entry_text, 16, entry_y, list_w - 32, "left")
            end
        end

        journal_max_scroll = math.max(0, (#saved_logs * journal_spacing) - view_h + 40)
        love.graphics.pop()
        love.graphics.setScissor()
    end
    love.graphics.pop()

    -- Responsive dynamic map coordinate space layout rendering
    love.graphics.push("all")
    local remaining_w = w - list_w
    local map_cX = list_w + remaining_w / 2
    local map_cY = (h - bottom_h) / 2
    local map_R = math.min(remaining_w, h - bottom_h) * 0.42
    
    love.graphics.setLineWidth(1)
    for a = 0, 90, 30 do
        local r = map_R * (1 - (a / 90))
        set_color(1, 1, 1, a == 0 and 0.3 or 0.1)
        love.graphics.circle("line", map_cX, map_cY, r)
        if a < 90 and map_R > 100 then
            set_color(0.5, 0.5, 0.5, 0.5)
            love.graphics.setFont(font_tiny)
            love.graphics.print(a .. "°", map_cX + 5, map_cY - r - 12)
        end
    end

    local directions = {[0]="N", [45]="NE", [90]="E", [135]="SE", [180]="S", [225]="SW", [270]="W", [315]="NW"}
    for angle_deg = 0, 315, 45 do
        local angle_rad = math.rad(angle_deg - 90)
        local cos_a, sin_a = math.cos(angle_rad), math.sin(angle_rad)
        set_color(1, 1, 1, 0.05)
        love.graphics.line(map_cX, map_cY, map_cX + cos_a * map_R, map_cY + sin_a * map_R)
        
        if map_R > 120 then
            set_color(0.8, 0.8, 0.8, 0.8)
            love.graphics.setFont(font_tiny)
            love.graphics.printf((directions[angle_deg] or "") .. "\n" .. angle_deg .. "°", map_cX + cos_a * (map_R + 18) - 20, map_cY + sin_a * (map_R + 18) - 10, 40, "center")
        end
    end

    for _, p_info in ipairs(Backend.planets) do
        local data = planets_data[p_info.name]
        if data and data.visible then
            local x, y = get_map_coords(data.alt, data.az, map_cX, map_cY, map_R)
            if x and y then
                if selected_planet == p_info.name then
                    set_color(1, 0, 0, 0.4)
                    love.graphics.circle("line", x, y, 6)
                    love.graphics.circle("line", x, y, 14)
                end
                set_color(p_info.color[1], p_info.color[2], p_info.color[3], 1)
                love.graphics.circle("fill", x, y, 4)
                if map_R > 100 then
                    love.graphics.setFont(font_tiny)
                    love.graphics.print(p_info.name, x + 8, y - 8)
                end
            end
        end
    end
    love.graphics.pop()

    -- bottom telemetry responsive block bar
    love.graphics.push("all")
    set_color(0.02, 0.02, 0.05, 1)
    love.graphics.rectangle("fill", list_w, h - bottom_h, w - list_w, bottom_h)
    set_color(1, 1, 1, 0.15)
    love.graphics.line(list_w, h - bottom_h, w, h - bottom_h)
    
    local sun_alt = planets_data["Sun"] and planets_data["Sun"].alt
    local sky_cond = Backend.getSkyCondition(sun_alt)
    
    set_color(1, 0.8, 0, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("UTC: " .. os.date("%H:%M", os.time() + time_offset) .. " | SKY: " .. sky_cond, list_w + 20, h - bottom_h + 15)

    local box_x = list_w + 20
    local box_w = math.max(200, math.floor((w - list_w) * 0.45))
    
    set_color(0.6, 0.6, 0.6, 0.8)
    love.graphics.setFont(font_tiny)
    love.graphics.print("Observation Notes Journal Logger (Click field box to write logs):", box_x, h - bottom_h + 45)
    
    if active_input == "session_notes" then set_color(0.15, 0.25, 0.45, 1) else set_color(0.1, 0.1, 0.15, 1) end
    love.graphics.rectangle("fill", box_x, h - bottom_h + 65, box_w, 40, 4)
    set_color(1, 1, 1, 1)
    love.graphics.printf(log_notes .. (active_input == "session_notes" and "|" or ""), box_x + 8, h - bottom_h + 70, box_w - 16, "left")

    set_color(0.2, 0.5, 0.8, 1)
    love.graphics.rectangle("fill", box_x, h - bottom_h + 112, 130, 22, 4)
    set_color(1, 1, 1, 1)
    love.graphics.printf("COMMIT NOTE", box_x, h - bottom_h + 116, 130, "center")

    set_color(0.5, 0.5, 0.5, 1)
    love.graphics.print("N: Night Mode | Arrows: Time Adjustments", list_w + 20, h - bottom_h + 32)
    love.graphics.pop()

    -- eyepiece simulation graphic resizing
    if selected_planet and planets_data[selected_planet] then
        love.graphics.push("all")
        local d = planets_data[selected_planet]
        
        local eye_box_w = math.max(160, math.floor((w - list_w) * 0.35))
        local r = math.min(80, math.floor(bottom_h * 0.38))
        local tx = w - r - 30
        local ty = h - bottom_h + (bottom_h / 2) - 10
        
        local current_mag = EYEPIECE_FL > 0 and (SCOPE_FL / EYEPIECE_FL) or 1
        local current_tfov = (EYEPIECE_AFOV / current_mag) * 3600

        set_color(0.02, 0.02, 0.05, 1)
        love.graphics.circle("fill", tx, ty, r)
        set_color(1, 1, 1, 0.2)
        love.graphics.circle("line", tx, ty, r)

        love.graphics.stencil(function()
            love.graphics.circle("fill", tx, ty, r)
        end, "replace", 1)
        love.graphics.setStencilTest("equal", 1)

        love.graphics.push()
        love.graphics.translate(tx, ty)
        
        local field_rotation = math.rad(d.az or 0)
        love.graphics.rotate(math.pi + field_rotation) 
        
        local ang_size = d.ang_size or 5
        local px_size = (ang_size / current_tfov) * (r * 2)
        
        local p_color = {1, 1, 1}
        local p_type = ""
        for _, info in ipairs(Backend.planets) do 
            if info.name == selected_planet then 
                p_color = info.color 
                p_type = info.type
                break
            end 
        end

        if p_type == "star" then
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", 0, 0, 1.5)
        elseif p_type == "dso" then
            set_color(p_color[1], p_color[2], p_color[3], 0.3)
            love.graphics.circle("fill", 0, 0, 15)
            set_color(1, 1, 1, 0.7)
            love.graphics.points(0, 0)
        elseif selected_planet == "Saturn" then
            set_color(p_color[1], p_color[2], p_color[3], 0.6)
            love.graphics.ellipse("line", 0, 0, px_size * 1.2, px_size * 0.4)
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", 0, 0, px_size / 2)
        elseif selected_planet == "Jupiter" then
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", 0, 0, px_size / 2)
            set_color(1, 1, 1, 0.8)
            local moon_offsets = {-2.5, -1.8, 1.5, 3.2} 
            for _, offset in ipairs(moon_offsets) do 
                love.graphics.circle("fill", offset * px_size, 0, 1.5) 
            end
        else
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", 0, 0, px_size / 2)
        end
        love.graphics.pop()
        love.graphics.setStencilTest()

        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_tiny)
        love.graphics.printf(selected_planet .. " (" .. string.format("%.0fx", current_mag) .. "x)", tx - 80, ty + r + 4, 160, "center")
        
        local drift_time_sec = math.floor((current_tfov / 2) / 15)
        set_color(0.5, 0.7, 0.9, 0.8)
        love.graphics.printf("Drift: ~" .. drift_time_sec .. "s", tx - 80, ty - r - 14, 160, "center")
        love.graphics.pop()
    end

    if selected_planet == "Sun" then
        love.graphics.push("all")
        set_color(1, 0, 0, 1)
        love.graphics.setFont(font_bold)
        love.graphics.printf("!!! SOLAR WARNING !!!\nFILTER REQUIRED", w - 210, h - bottom_h - 60, 200, "center")
        love.graphics.pop()
    end

    if is_dimmed then
        love.graphics.push("all")
        love.graphics.setColor(0, 0, 0, 0.85) 
        love.graphics.rectangle("fill", 0, 0, w, h)
        love.graphics.setColor(0.5, 0, 0, 1)
        love.graphics.setFont(font_small)
        love.graphics.printf("IDLE POWER OVERLAY: Night-Vision Lock Active\nMove cursor or interact to unlock panel frame context.", 0, h/2 - 20, w, "center")
        love.graphics.pop()
    end
end

function love.textinput(t)
    idle_time = 0
    is_dimmed = false
    if not active_input then return end
    
    if active_input == "scope" or active_input == "eyepiece" or active_input == "afov" then
        if t:match("%d") then 
            if active_input == "scope" then SCOPE_FL = tonumber(SCOPE_FL .. t) or SCOPE_FL
            elseif active_input == "eyepiece" then EYEPIECE_FL = tonumber(EYEPIECE_FL .. t) or EYEPIECE_FL
            elseif active_input == "afov" then EYEPIECE_AFOV = tonumber(EYEPIECE_AFOV .. t) or EYEPIECE_AFOV end
        end
    elseif active_input == "custom_name" then
        custom_name = custom_name .. t
    elseif active_input == "custom_id" then
        custom_id = custom_id .. t
    elseif active_input == "session_notes" then
        log_notes = log_notes .. t
    end
end

function love.keypressed(k)
    idle_time = 0
    is_dimmed = false

    if active_input then
        if k == "backspace" then
            if active_input == "scope" then
                local str = tostring(SCOPE_FL)
                SCOPE_FL = tonumber(str:sub(1, #str - 1)) or 0
            elseif active_input == "eyepiece" then
                local str = tostring(EYEPIECE_FL)
                EYEPIECE_FL = tonumber(str:sub(1, #str - 1)) or 0
            elseif active_input == "afov" then
                local str = tostring(EYEPIECE_AFOV)
                EYEPIECE_AFOV = tonumber(str:sub(1, #str - 1)) or 0
            elseif active_input == "custom_name" then
                custom_name = custom_name:sub(1, #custom_name - 1)
            elseif active_input == "custom_id" then
                custom_id = custom_id:sub(1, #custom_id - 1)
            elseif active_input == "session_notes" then
                log_notes = log_notes:sub(1, #log_notes - 1)
            end
        elseif k == "return" or k == "kpenter" or k == "escape" then
            active_input = nil
        end
        return 
    end

    if k == "n" then 
        night_mode = not night_mode
    elseif k == "r" then 
        time_offset = 0 
        refresh_data()
    end
end

function love.mousepressed(x, y, button)
    idle_time = 0
    is_dimmed = false
    
    local w, h = love.graphics.getDimensions()
    local list_w = math.max(240, math.floor(w * 0.25))
    local bottom_h = math.max(150, math.floor(h * 0.22))
    
    local header_h, tab_h = 70, 40
    local each_tab_w = math.floor((list_w - 10) / 3)
    local start_y = header_h + tab_h + 10
    local spacing = 65

    if button == 1 then
        -- Check responsive tab headers
        if y > header_h and y < header_h + tab_h and x < list_w then
            if x > 0 and x < 5 + each_tab_w then 
                app_mode = "log" active_input = nil
            elseif x >= 5 + each_tab_w and x < 5 + (each_tab_w * 2) then 
                app_mode = "specs" active_input = nil
            elseif x >= 5 + (each_tab_w * 2) and x < list_w then
                app_mode = "journal" active_input = nil
            end
        end

        if app_mode == "log" and x < list_w and y > start_y and y < (h - bottom_h) then
            local adjusted_y = y + scroll_y
            local index = math.floor((adjusted_y - start_y) / spacing) + 1
            if Backend.planets[index] then 
                selected_planet = Backend.planets[index].name 
            end
        elseif app_mode == "specs" and x < list_w then
            local box_w = math.min(100, list_w - 150)
            local box_left = list_w - box_w - 15
            
            if x >= box_left and x <= box_left + box_w then
                if y >= start_y + 30 and y <= start_y + 54 then active_input = "scope"
                elseif y >= start_y + 70 and y <= start_y + 94 then active_input = "eyepiece"
                elseif y >= start_y + 110 and y <= start_y + 134 then active_input = "afov"
                else active_input = nil end
            elseif x >= 20 and x <= list_w - 20 then
                if y >= start_y + 235 and y <= start_y + 255 then active_input = "custom_name"
                elseif y >= start_y + 280 and y <= start_y + 300 then active_input = "custom_id"
                elseif y >= start_y + 315 and y <= start_y + 340 then
                    if custom_name ~= "" and custom_id ~= "" then
                        table.insert(Backend.planets, {
                            name = custom_name,
                            id = custom_id,
                            color = {0.7, 0.7, 0.9},
                            type = "dso"
                        })
                        custom_name = ""
                        custom_id = ""
                        active_input = nil
                        refresh_data()
                    end
                else active_input = nil end
            else
                active_input = nil
            end
        end

        -- Check responsive coordinates for the bottom logger field box panel components
        local box_x = list_w + 20
        local box_w = math.max(200, math.floor((w - list_w) * 0.45))
        if x >= box_x and x <= box_x + box_w and y >= h - bottom_h + 65 and y <= h - bottom_h + 105 then
            active_input = "session_notes"
        elseif x >= box_x and x <= box_x + 130 and y >= h - bottom_h + 112 and y <= h - bottom_h + 134 then
            if log_notes ~= "" then
                local formatted_entry = os.date("%H:%M") .. " [" .. selected_planet .. "] " .. log_notes
                table.insert(saved_logs, formatted_entry)
                love.filesystem.append("observer_journal.txt", formatted_entry .. "\n")
                log_notes = ""
                active_input = nil
            end
        end
    end
end