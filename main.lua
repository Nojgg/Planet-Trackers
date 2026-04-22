local Backend = require("Backend")

local SCOPE_FL, EYEPIECE_FL, EYEPIECE_AFOV = 900, 9, 66
app_mode = "log" 

local planets_data, queue = {}, {}
local is_fetching, time_offset, selected_planet = false, 0, "Jupiter"
local night_mode = false
local loc_status = "Locating..."

local scroll_y = 0
local max_scroll = 0

function love.load()
    love.window.setTitle("Hadley 114/900 Mission Control")
    love.window.setMode(1200, 800, {resizable=true})
    font_bold = love.graphics.newFont(16)
    font_small = love.graphics.newFont(12)
    font_tiny = love.graphics.newFont(10)
    
    Backend.initLocation()
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

function love.update(dt) 
    Backend.poll() 

    if Backend.updateLocation() then
        loc_status = string.format("Lat: %.2f Lon: %.2f", Backend.lat, Backend.lon)
        refresh_data() 
    end
end

function love.wheelmoved(x, y)
    if app_mode == "log" then
        scroll_y = scroll_y - (y * 30)
        scroll_y = math.max(0, math.min(scroll_y, max_scroll))
    end
end

local function set_color(r, g, b, a)
    if night_mode then
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
    
    love.graphics.clear(0.01, 0.01, 0.03)

    set_color(0.05, 0.05, 0.1, 1)
    love.graphics.rectangle("fill", 0, 0, list_w, h)
    
    set_color(1, 1, 1, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("Hadley Observer Log", 20, 20)
    
    set_color(0.4, 0.4, 0.6, 1)
    love.graphics.setFont(font_tiny)
    love.graphics.print(loc_status, 20, 42)

    local sidebar_w = 280 
    local tab_h = 40
    local header_h = 70 

    love.graphics.setColor(0.05, 0.05, 0.1, 1) 
    love.graphics.rectangle("fill", 0, header_h, sidebar_w, tab_h)

    local is_log = (app_mode == "log")
    if is_log then love.graphics.setColor(0.92, 0.72, 0.22, 1) 
    else love.graphics.setColor(0.1, 0.15, 0.25, 1) end
    love.graphics.rectangle("fill", 5, header_h + 5, (sidebar_w/2) - 7, tab_h - 10, 4)

    local is_specs = (app_mode == "specs")
    if is_specs then love.graphics.setColor(0.92, 0.72, 0.22, 1) 
    else love.graphics.setColor(0.1, 0.15, 0.25, 1) end
    love.graphics.rectangle("fill", (sidebar_w/2) + 2, header_h + 5, (sidebar_w/2) - 7, tab_h - 10, 4)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font_small)
    love.graphics.printf("LOG", 5, header_h + 12, (sidebar_w/2) - 7, "center")
    love.graphics.printf("SPECS", (sidebar_w/2) + 2, header_h + 12, (sidebar_w/2) - 7, "center")
    
    if app_mode == "log" then
        local start_y, spacing = 115, 65
        local view_h = h - bottom_h - start_y

        love.graphics.setScissor(0, start_y, list_w, view_h)
        love.graphics.push()
        love.graphics.translate(0, -scroll_y)

        for i, p_info in ipairs(Backend.planets) do
            local data, y = planets_data[p_info.name], start_y + (i-1) * spacing 
            
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
                local time_info = string.format("↑ %s  ↓ %s", data.rise or "--:--", data.set or "--:--")
                love.graphics.print(time_info, 20, y + 38)
                
                if data.visible then
                    set_color(0.2, 1, 0.2, 1)
                    love.graphics.circle("fill", list_w - 25, y + 10, 4)
                else
                    set_color(0.4, 0.1, 0.1, 1)
                    love.graphics.circle("fill", list_w - 25, y + 10, 4)
                end
            end
        end
        max_scroll = math.max(0, (#Backend.planets * spacing) - view_h + 20)
        love.graphics.pop()
        love.graphics.setScissor()
    else
        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_bold)
        love.graphics.print("Telescope Specs", 20, 120)
        set_color(0.8, 0.8, 0.8, 1)
        love.graphics.setFont(font_small)
        love.graphics.print("Focal Length: " .. SCOPE_FL .. "mm", 20, 150)
        love.graphics.print("Eyepiece: " .. EYEPIECE_FL .. "mm", 20, 180)
        love.graphics.print("Mag: " .. string.format("%.1fx", SCOPE_FL/EYEPIECE_FL), 20, 210)
        set_color(0.92, 0.72, 0.22, 1)
        love.graphics.printf("Use [+] and [-] to change eyepiece.", 20, 260, sidebar_w - 40, "left")
    end


    local map_cX = list_w + (w - list_w) / 2
    local map_cY = (h - bottom_h) / 2
    local map_R = math.min(w - list_w, h - bottom_h) * 0.42
    
    love.graphics.setLineWidth(1)
    for a = 0, 90, 30 do
        local r = map_R * (1 - (a / 90))
        set_color(1, 1, 1, a == 0 and 0.3 or 0.1)
        love.graphics.circle("line", map_cX, map_cY, r)
        if a < 90 then
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
        set_color(0.8, 0.8, 0.8, 0.8)
        local label_r = map_R + 25
        love.graphics.setFont(font_small)
        love.graphics.printf((directions[angle_deg] or "") .. "\n" .. angle_deg .. "°", map_cX + cos_a * label_r - 20, map_cY + sin_a * label_r - 10, 40, "center")
    end

    for _, p_info in ipairs(Backend.planets) do
        local data = planets_data[p_info.name]
        if data and data.visible then
            local x, y = get_map_coords(data.alt, data.az, map_cX, map_cY, map_R)
            if selected_planet == p_info.name then
                set_color(1, 0, 0, 0.4)
                love.graphics.circle("line", x, y, 8)
                love.graphics.circle("line", x, y, 20)
                love.graphics.circle("line", x, y, 40)
            end
            set_color(p_info.color[1], p_info.color[2], p_info.color[3], 1)
            love.graphics.circle("fill", x, y, 5)
            love.graphics.setFont(font_small)
            love.graphics.print(p_info.name, x + 10, y - 10)
        end
    end


    set_color(0.02, 0.02, 0.05, 1)
    love.graphics.rectangle("fill", list_w, h - bottom_h, w - list_w, bottom_h)
    set_color(1, 1, 1, 0.15)
    love.graphics.line(list_w, h - bottom_h, w, h - bottom_h)
    
    -- AJOUT : État du ciel
    local sun_alt = planets_data["Sun"] and planets_data["Sun"].alt
    local sky_cond = Backend.getSkyCondition(sun_alt)
    
    set_color(1, 0.8, 0, 1)
    love.graphics.setFont(font_bold)
    love.graphics.print("UTC: " .. os.date("%H:%M", os.time() + time_offset) .. " | SKY: " .. sky_cond, list_w + 20, h - bottom_h + 20)

    set_color(0.5, 0.5, 0.5, 1)
    love.graphics.setFont(font_tiny)
    love.graphics.print("N: Night Mode | Arrows: Time", list_w + 20, h - bottom_h + 45)


    if selected_planet and planets_data[selected_planet] then
        local d = planets_data[selected_planet]
        local tx, ty, r = w - 120, h - 95, 80 
        local current_tfov = (EYEPIECE_AFOV / (SCOPE_FL / EYEPIECE_FL)) * 3600

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
        love.graphics.rotate(math.pi)
        
        local ang_size = d.ang_size or 5
        local px_size = (ang_size / current_tfov) * (r * 2)
        
        local p_color = {1, 1, 1}
        for _, info in ipairs(Backend.planets) do if info.name == selected_planet then p_color = info.color end end
  

        local p_type = ""
        for _, info in ipairs(Backend.planets) do if info.name == selected_planet then p_type = info.type end end

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
            for _, offset in ipairs(moon_offsets) do love.graphics.circle("fill", offset * px_size, 0, 1.5) end
        else
            set_color(p_color[1], p_color[2], p_color[3], 1)
            love.graphics.circle("fill", 0, 0, px_size / 2)
        end
        love.graphics.pop()
        love.graphics.setStencilTest()

        set_color(1, 1, 1, 1)
        love.graphics.setFont(font_small)
        love.graphics.printf(selected_planet .. "\n" .. string.format("%.0fx", SCOPE_FL/EYEPIECE_FL) .. "x Mag", tx - 70, ty + r + 10, 140, "center")
    end

    if selected_planet == "Sun" then
        set_color(1, 0, 0, 1)
        love.graphics.setFont(font_bold)
        love.graphics.printf("!!! SOLAR WARNING !!!\nFILTER REQUIRED", w - 250, h - 250, 200, "center")
    end
end

function love.keypressed(k)
    if k == "n" then night_mode = not night_mode
    elseif k == "r" then time_offset = 0 refresh_data()
    elseif k == "=" or k == "kp+" then EYEPIECE_FL = EYEPIECE_FL + 1
    elseif k == ")" or k == "kp-" then EYEPIECE_FL = math.max(1, EYEPIECE_FL - 1)
    elseif k == "right" then time_offset = time_offset + 3600 refresh_data()
    elseif k == "left" then time_offset = time_offset - 3600 refresh_data() end
end

function love.mousepressed(x, y, button)
    local list_w, header_h, tab_h = 280, 70, 40
    local start_y, spacing = 115, 65

    if button == 1 then
        if y > header_h and y < header_h + tab_h then
            if x > 0 and x < list_w / 2 then app_mode = "log"
            elseif x > list_w / 2 and x < list_w then app_mode = "specs" end
        end


        if app_mode == "log" and x < list_w and y > start_y and y < (love.graphics.getHeight() - 180) then
            local adjusted_y = y + scroll_y
            local index = math.floor((adjusted_y - start_y) / spacing) + 1
            if Backend.planets[index] then selected_planet = Backend.planets[index].name end
        end
    end
end