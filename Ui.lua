-- ui.lua  –  StarWatch graphical interface
-- Dark astronomical aesthetic: deep space navy, amber/gold accents, crisp typography

-- ─── State & Forward Declarations ─────────────────────────────────────────────
local state = {
    mode        = "menu",    -- "menu" | "loading" | "results"
    time_mode   = 1,         -- 1=now, 2=custom
    input_text  = "",
    input_active= false,
    results     = {},
    errors      = {},
    loading     = {},
    query_time  = 0,
    anim_t      = 0,
    stars       = {},
    hover_row   = nil,
    scroll      = 0,
    status_msg  = "",
    done_count  = 0,
    total_count = 0,
    sky_open    = false,
    sort_by     = "name",   
}

UI = {}

-- ─── Palette (Preserved) ──────────────────────────────────────────────────────
local C = {
    bg          = {0.035, 0.04,  0.07,  1},
    bg2         = {0.055, 0.065, 0.11,  1},
    bg3         = {0.07,  0.085, 0.14,  1},
    border      = {0.14,  0.18,  0.28,  1},
    accent      = {0.92,  0.72,  0.22,  1},   -- amber
    accent2     = {0.40,  0.75,  1.00,  1},   -- sky-blue
    text        = {0.88,  0.90,  0.95,  1},
    text_dim    = {0.50,  0.54,  0.64,  1},
    text_faint  = {0.28,  0.31,  0.40,  1},
    green       = {0.30,  0.90,  0.55,  1},
    red         = {0.95,  0.35,  0.35,  1},
    gold_tr     = {0.92,  0.72,  0.22,  0.18},
    white       = {1,     1,     1,     1},
}

-- ─── Layout constants (Preserved) ─────────────────────────────────────────────
local W, H          = 1100, 720
local SIDEBAR_W     = 270
local HEADER_H      = 68
local FOOTER_H      = 32
local ROW_H         = 72
local CONTENT_X     = SIDEBAR_W + 16
local CONTENT_W     = W - SIDEBAR_W - 32
local LIST_Y        = HEADER_H + 90   

-- ─── Internal Helper Functions ────────────────────────────────────────────────
local function setcolor(c, alpha_override)
    if alpha_override then
        love.graphics.setColor(c[1], c[2], c[3], alpha_override)
    else
        love.graphics.setColor(c)
    end
end

local function rect(x, y, w, h, rx)
    love.graphics.rectangle("fill", x, y, w, h, rx or 0, rx or 0)
end

local function rect_line(x, y, w, h, rx)
    love.graphics.rectangle("line", x, y, w, h, rx or 0, rx or 0)
end

local fonts = {}
local function init_fonts()
    fonts.tiny    = love.graphics.newFont(10)
    fonts.small   = love.graphics.newFont(12)
    fonts.med     = love.graphics.newFont(16)
    fonts.large   = love.graphics.newFont(20)
    fonts.huge    = love.graphics.newFont(42)
end

local function draw_panel(x, y, w, h, rx, fill_c, border_c)
    setcolor(fill_c or C.bg2)
    rect(x, y, w, h, rx or 8)
    if border_c ~= false then
        setcolor(border_c or C.border)
        love.graphics.setLineWidth(1)
        rect_line(x, y, w, h, rx or 8)
    end
end

-- ─── Solar System Viz (Orrery) ───────────────────────────────────────────────
local function draw_solar_system_map(cx, cy, radius)
    -- Draw central star (Sun)
    setcolor(C.accent, 0.3 + 0.1 * math.sin(state.anim_t * 2))
    love.graphics.circle("fill", cx, cy, 10)
    setcolor(C.accent)
    love.graphics.circle("fill", cx, cy, 4)

    -- Fixed orbit spacing
    local orbit_step = radius / 10
    
    -- Draw Orbits and Planets based on results
    for i, res in ipairs(state.results) do
        local orbit_r = i * orbit_step + 15
        setcolor(C.border, 0.15)
        love.graphics.circle("line", cx, cy, orbit_r)
        
        -- Use Azimuth to place them on the map
        local angle = math.rad(res.az - 90)
        local px = cx + math.cos(angle) * orbit_r
        local py = cy + math.sin(angle) * orbit_r
        
        setcolor(res.planet.color, res.visible and 1 or 0.3)
        love.graphics.circle("fill", px, py, res.visible and 4 or 2)
        
        if res.visible then
            setcolor(res.planet.color, 0.2)
            love.graphics.circle("fill", px, py, 8)
        end
    end
end

-- ─── Sky-map overlay (Updated: No Planets) ────────────────────────────────────
local function draw_sky_map()
    if not state.sky_open then return end
    setcolor({0, 0, 0, 0.70})
    rect(0, 0, W, H)

    local cx, cy, cr = W/2, H/2, 270
    setcolor({0.02, 0.04, 0.09, 0.97})
    love.graphics.circle("fill", cx, cy, cr)
    setcolor(C.border)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", cx, cy, cr)
    
    for _, ang in ipairs({0, math.pi/4, math.pi/2, 3*math.pi/4}) do
        local dx, dy = math.cos(ang)*cr, math.sin(ang)*cr
        love.graphics.line(cx-dx, cy-dy, cx+dx, cy+dy)
    end
    for _, frac in ipairs({0.33, 0.66, 1.0}) do
        setcolor(C.border, frac == 1 and 0.5 or 0.2)
        love.graphics.circle("line", cx, cy, cr*frac)
    end
    
    setcolor(C.text_dim)
    love.graphics.setFont(fonts.small)
    love.graphics.print("N", cx-5, cy-cr-18)
    love.graphics.print("S", cx-5, cy+cr+6)
    love.graphics.print("E", cx+cr+6, cy-7)
    love.graphics.print("W", cx-cr-18, cy-7)

    -- Planet rendering removed as per request
    
    setcolor(C.text_dim)
    love.graphics.printf("Press [M] or click to close", 0, cy+cr+28, W, "center")
end

-- ─── UI Components ────────────────────────────────────────────────────────────
local function draw_header()
    setcolor(C.bg2)
    rect(0, 0, W, HEADER_H)
    setcolor(C.border)
    love.graphics.line(0, HEADER_H, W, HEADER_H)
    setcolor(C.accent)
    love.graphics.setFont(fonts.large)
    love.graphics.print("✦ STARWATCH", 20, 12)
    
    local utc = os.date("!%Y-%m-%d  %H:%M:%S UTC")
    setcolor(C.text_dim)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(utc, 0, 28, W - 20, "right")

    local bx, by, bw, bh = W - 155, 14, 130, 34
    local hover = love.mouse.getX() >= bx and love.mouse.getX() <= bx+bw and love.mouse.getY() >= by and love.mouse.getY() <= by+bh
    setcolor(hover and C.accent or C.bg3)
    rect(bx, by, bw, bh, 6)
    setcolor(hover and C.bg or C.accent)
    love.graphics.printf("⬤  Sky Map  [M]", bx, by+10, bw, "center")
end

local function draw_footer()
    setcolor(C.bg2)
    rect(0, H - FOOTER_H, W, FOOTER_H)
    setcolor(C.border)
    love.graphics.line(0, H - FOOTER_H, W, H - FOOTER_H)
    setcolor(C.text_faint)
    love.graphics.setFont(fonts.tiny)
    love.graphics.printf("StarWatch · NASA/JPL Horizons API · Étretat Observer · [M] Sky Map · [↑↓] Scroll", 10, H - 22, W, "left")
end

local function draw_sidebar()
    draw_panel(0, HEADER_H, SIDEBAR_W, H - HEADER_H - FOOTER_H, 0, {0.04, 0.047, 0.083, 1}, false)
    setcolor(C.border)
    love.graphics.line(SIDEBAR_W, HEADER_H, SIDEBAR_W, H - FOOTER_H)

    local y = HEADER_H + 20
    setcolor(C.text_dim)
    love.graphics.setFont(fonts.small)
    love.graphics.print("OBSERVATION TIME", 16, y)
    y = y + 22

    local btn_w = (SIDEBAR_W - 36) / 2
    for i, label in ipairs({"Now", "Custom"}) do
        local bx = 16 + (i-1)*(btn_w + 4)
        local active = state.time_mode == i
        setcolor(active and C.accent or C.bg3)
        rect(bx, y, btn_w, 30, 6)
        setcolor(active and C.bg or C.text_dim)
        love.graphics.printf(label, bx, y+9, btn_w, "center")
    end
end

-- ─── Main Drawing Logic ───────────────────────────────────────────────────────
function UI.load()
    init_fonts()
    math.randomseed(os.time())
    for i=1,150 do
        table.insert(state.stars, {x=math.random()*W, y=math.random()*H, s=math.random()*1.5})
    end
end

function UI.update(dt)
    state.anim_t = state.anim_t + dt
    require("Backend").poll()
end

function UI.draw()
    setcolor(C.bg)
    rect(0, 0, W, H)
    
    -- Background stars
    setcolor({1,1,1}, 0.4)
    for _, s in ipairs(state.stars) do
        love.graphics.circle("fill", s.x, s.y, s.s)
    end

    draw_header()
    draw_sidebar()

    -- Content Area
    local x, w = CONTENT_X, CONTENT_W
    if state.mode == "results" then
        -- Solar System Banner Panel
        setcolor(C.bg3)
        rect(x, HEADER_H + 10, w, 100, 6)
        draw_solar_system_map(x + w - 120, HEADER_H + 60, 45)
        
        setcolor(C.text)
        love.graphics.setFont(fonts.med)
        love.graphics.print("SOLAR SYSTEM LIVE MAP", x + 15, HEADER_H + 25)
        setcolor(C.text_dim)
        love.graphics.setFont(fonts.tiny)
        love.graphics.print("Top-down ecliptic view based on fetched data", x + 15, HEADER_H + 50)
        
        -- Planet List
        local sorted = state.results -- simplified for example
        for i, res in ipairs(sorted) do
            local ry = LIST_Y + 20 + (i-1)*(ROW_H+6) - state.scroll
            if ry > LIST_Y and ry < H - FOOTER_H then
                setcolor(C.bg2)
                rect(x, ry, w, ROW_H, 6)
                setcolor(res.planet.color)
                rect(x, ry+8, 4, ROW_H-16, 2)
                setcolor(C.text)
                love.graphics.setFont(fonts.med)
                love.graphics.print(res.planet.name, x+40, ry+15)
            end
        end
    elseif state.mode == "loading" then
        for i, name in ipairs(state.loading) do
            local ly = LIST_Y + (i-1)*35
            setcolor(C.text_dim)
            love.graphics.print("Fetching " .. name .. "...", x, ly)
            -- Fixed arc parameters
            setcolor(C.accent)
            love.graphics.arc("line", "open", x + 150, ly + 8, 6, state.anim_t*5, state.anim_t*5 + 2)
        end
    else
        setcolor(C.text_dim)
        love.graphics.printf("Ready to observe. Press FETCH POSITIONS to begin.", x, H/2, w, "center")
    end

    draw_footer() -- Fixed: Calling local function correctly
    draw_sky_map()
end

-- ─── Input ────────────────────────────────────────────────────────────────────
function UI.mousepressed(x, y, btn)
    if btn ~= 1 then return end
    if state.sky_open then state.sky_open = false; return end
    if x > W-155 and y < 50 then state.sky_open = true end
    
    -- Fetch button logic (simplified)
    if x < SIDEBAR_W and y > 200 and y < 250 then
        state.mode = "loading"
        local Backend = require "Backend"
        state.results = {}
        for _, p in ipairs(Backend.planets) do
            table.insert(state.loading, p.name)
            Backend.fetch_planet(p, os.time(), function(res)
                table.insert(state.results, res)
                for k,v in ipairs(state.loading) do if v == p.name then table.remove(state.loading,k) break end end
                if #state.results >= #Backend.planets then state.mode = "results" end
            end)
        end
    end
end

function UI.keypressed(k)
    if k == "m" then state.sky_open = not state.sky_open end
end

function UI.wheelmoved(x, y)
    state.scroll = math.max(0, state.scroll - y * 30)
end