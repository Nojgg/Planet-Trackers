-- --- UI.LUA (Unified & Responsive with Tabs) ---

-- 1. Tab State (Add this to your existing state table at the top of ui.lua)
state.tab = state.tab or "log" -- Default to the Observer Log

function UI.draw()
    local L = get_layout() -- Using the responsive layout function from earlier
    
    -- Background
    set_color(C.bg)
    love.graphics.rectangle("fill", 0, 0, L.W, L.H)

    -- --- SIDEBAR AREA ---
    set_color(C.bg2)
    love.graphics.rectangle("fill", 0, 0, L.SIDEBAR_W, L.H)
    set_color(C.border)
    love.graphics.line(L.SIDEBAR_W, 0, L.SIDEBAR_W, L.H)

    -- --- TAB BUTTONS (FIXED AT THE TOP OF SIDEBAR) ---
    local tab_y = L.HEADER_H
    local tab_h = 45
    local btn_w = L.SIDEBAR_W / 2
    
    -- Log Tab Button
    set_color(state.tab == "log" and C.accent or C.bg3)
    love.graphics.rectangle("fill", 0, tab_y, btn_w, tab_h)
    -- Specs Tab Button
    set_color(state.tab == "specs" and C.accent or C.bg3)
    love.graphics.rectangle("fill", btn_w, tab_y, btn_w, tab_h)
    
    -- Tab Labels
    set_color(state.tab == "log" and C.bg or C.text_dim)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("LOG", 0, tab_y + 15, btn_w, "center")
    
    set_color(state.tab == "specs" and C.bg or C.text_dim)
    love.graphics.printf("SPECS", btn_w, tab_y + 15, btn_w, "center")

    -- --- TAB CONTENT ---
    local content_y = tab_y + tab_h + 10

    if state.tab == "log" then
        -- RENDER YOUR ORIGINAL PLANET LIST
        if state.results then
            for i, res in ipairs(state.results) do
                local ry = content_y + (i-1)*(L.ROW_H+4) - state.scroll
                if ry > tab_y + tab_h and ry < L.H - L.FOOTER_H then
                    set_color(C.bg3, 0.4)
                    love.graphics.rectangle("fill", 5, ry, L.SIDEBAR_W - 10, L.ROW_H, 4)
                    set_color(res.planet.color)
                    love.graphics.setFont(fonts.med)
                    love.graphics.print(res.planet.name, 15, ry + 10)
                    -- (Add your other planet info lines here)
                end
            end
        end
    else
        -- RENDER THE SPECS MODIFIER
        set_color(C.text)
        love.graphics.setFont(fonts.med)
        love.graphics.printf("EQUIPMENT", 0, content_y + 20, L.SIDEBAR_W, "center")
        
        love.graphics.setFont(fonts.small)
        set_color(C.text_dim)
        love.graphics.printf("Scope Focal: " .. telescope_focal .. "mm", 20, content_y + 60, L.SIDEBAR_W - 40, "left")
        love.graphics.printf("Eyepiece: " .. eyepiece_focal .. "mm", 20, content_y + 90, L.SIDEBAR_W - 40, "left")
        
        set_color(C.accent, 0.6)
        love.graphics.printf("Use ARROW KEYS to adjust specs while this tab is open.", 20, content_y + 140, L.SIDEBAR_W - 40, "left")
    end

    -- --- EYEPIECE VIEW (Preserving your specific Newtonian math) ---
    if selected_planet and planets_data[selected_planet] then
        local d = planets_data[selected_planet]
        local r = L.EYE_R
        local tx = L.W - r - 30
        local ty = L.H - L.FOOTER_H - r - 40
        
        -- Current Specs Math
        local mag = telescope_focal / eyepiece_focal
        local current_tfov = (50 / mag) * 3600 -- Arcseconds
        
        set_color(C.bg2)
        love.graphics.circle("fill", tx, ty, r)
        set_color(C.border, 0.3)
        love.graphics.circle("line", tx, ty, r)
        
        love.graphics.push()
        love.graphics.translate(tx, ty)
        love.graphics.rotate(math.pi) -- Your 180 flip
        
        local ang_size = d.ang_size or 5
        local px_size = (ang_size / current_tfov) * (r * 2)
        
        set_color(d.color or {1,1,1})
        if ang_size < 4.0 then
            love.graphics.points(0,0) -- Star point
            love.graphics.circle("fill", 0, 0, 1.2)
        else
            love.graphics.circle("fill", 0, 0, px_size / 2) -- Planet disk
        end
        love.graphics.pop()
    end
end

-- --- INPUTS (Necessary for the tab to work) ---

function UI.mousepressed(x, y, btn)
    local L = get_layout()
    -- Check if click is within the Tab Header area
    if y > L.HEADER_H and y < L.HEADER_H + 45 then
        if x < L.SIDEBAR_W / 2 then 
            state.tab = "log" 
        elseif x < L.SIDEBAR_W then 
            state.tab = "specs" 
        end
    end
end

function UI.keypressed(k)
    if state.tab == "specs" then
        if k == "up" then telescope_focal = telescope_focal + 10 end
        if k == "down" then telescope_focal = math.max(10, telescope_focal - 10) end
        if k == "right" then eyepiece_focal = eyepiece_focal + 1 end
        if k == "left" then eyepiece_focal = math.max(1, eyepiece_focal - 1) end
    end
end