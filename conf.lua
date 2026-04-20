-- conf.lua  –  LÖVE2D window configuration for StarWatch

function love.conf(t)
    t.window.title   = "StarWatch — Planet Observer"
    t.window.width   = 1100
    t.window.height  = 720
    t.window.resizable = false
    t.window.vsync   = 1
    t.window.minwidth  = 1100
    t.window.minheight = 720

    -- Require modules
    t.modules.audio   = false   -- not needed
    t.modules.joystick = false
    t.modules.physics  = false
    t.modules.video    = false

    t.version = "11.4"
    t.console = true  -- Show console on Windows for debug output
end