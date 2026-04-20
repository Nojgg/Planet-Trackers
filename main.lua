--local request = require("RequestPlanets")

button = {
    x = 100,
    y = 100,
    w = 200,
    h = 50,
    text = "Click me"
}

function drawButton(b)
    love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
    love.graphics.print(b.text, b.x + 10, b.y + 15)
end

function isInside(x, y, b)
    return x > b.x and x < b.x + b.w
       and y > b.y and y < b.y + b.h
end

function love.draw()
    drawButton(button)
end

function love.mousepressed(x, y, btn)
    if btn == 1 and isInside(x, y, button) then
        button.text = "Pressed"
    end
end