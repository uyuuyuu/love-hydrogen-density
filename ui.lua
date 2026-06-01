-- Overlay UI rendering: Game-like Cyber HUD
local M = {}

local function orbitalScale(n, l)
    return n * (n + 1) / 2 - l * (l + 1) / 6
end

local function niceScale(rawLen)
    if rawLen <= 0 then return 1 end
    local exp = math.floor(math.log10(rawLen))
    local frac = rawLen / (10^exp)
    local nice
    if frac < 1.5 then nice = 1
    elseif frac < 3.5 then nice = 2
    elseif frac < 7.5 then nice = 5
    else nice = 1; exp = exp + 1
    end
    return nice * (10^exp)
end

local function a0ToMeter(a0)
    return a0 * 5.29177210903e-11
end

local function meterToA0(m)
    return m / 5.29177210903e-11
end

local function niceScaleSI(rawMeters)
    local prefixes = {
        { mult = 1e12, suffix = "pm" },
        { mult = 1e9,  suffix = "nm" },
        { mult = 1e6,  suffix = "um" },
        { mult = 1e3,  suffix = "mm" },
        { mult = 1,    suffix = "m" },
    }
    for i, p in ipairs(prefixes) do
        local val = rawMeters * p.mult
        if val < 1000 or i == #prefixes then
            local v = niceScale(val)
            if v >= 1000 and i < #prefixes then
                -- overflow to next prefix
            else
                return v / p.mult, string.format("%g %s", v, p.suffix)
            end
        end
    end
end

local function drawScaleBar(x, y, worldPerPixel)
    local rawMeters = a0ToMeter(100 * worldPerPixel)
    local niceMeters, text = niceScaleSI(rawMeters)
    local barLenA0 = meterToA0(niceMeters)
    local pxLen = barLenA0 / worldPerPixel
    local font = love.graphics.getFont()
    local tw = font:getWidth(text)
    local tx = x - tw / 2

    -- Semi-transparent background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x - pxLen / 2 - 6, y - 2, pxLen + 12, 20, 3)

    -- Bar line
    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.line(x - pxLen / 2, y + 6, x + pxLen / 2, y + 6)

    -- Tick marks at ends
    love.graphics.line(x - pxLen / 2, y + 2, x - pxLen / 2, y + 10)
    love.graphics.line(x + pxLen / 2, y + 2, x + pxLen / 2, y + 10)

    -- Label
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(text, tx, y + 12, 0, 0.8, 0.8)
end

local function drawBracket(x, y, w, h, size)
    love.graphics.line(x, y + size, x, y, x + size, y)
    love.graphics.line(x + w - size, y, x + w, y, x + w, y + size)
    love.graphics.line(x, y + h - size, x, y + h, x + size, y + h)
    love.graphics.line(x + w - size, y + h, x + w, y + h, x + size, y + h)
    love.graphics.line(x + w, y + h - size, x + w, y + h, x + w - size, y + h)
end

local function drawQuantumBox(x, y, label, value, color)
    local w, h = 45, 35
    -- Background
    love.graphics.setColor(color[1], color[2], color[3], 0.2)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    -- Border
    love.graphics.setColor(color[1], color[2], color[3], 0.8)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    -- Label
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print(label, x + 5, y + 2, 0, 0.7, 0.7)
    -- Value
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(tostring(value), x + 15, y + 12, 0, 1.2, 1.2)

    -- Buttons (Arrows)
    love.graphics.setColor(color[1], color[2], color[3], 0.6)
    -- Up Arrow
    love.graphics.polygon("fill", x + 15, y - 4, x + 30, y - 4, x + 22.5, y - 12)
    -- Down Arrow
    love.graphics.polygon("fill", x + 15, y + h + 4, x + 30, y + h + 4, x + 22.5, y + h + 12)
end

function M.getClickedQuantumButton(mx, my)
    -- HUD panel is at tx=30, ty=30. Quantum boxes at qy = ty + 45
    local tx, ty = 30, 30
    local qy = ty + 45
    local qx_list = {tx, tx + 55, tx + 110}
    local labels = {"n", "l", "m"}
    local w, h = 45, 35

    for i, qx in ipairs(qx_list) do
        -- Check Up button
        if mx >= qx + 10 and mx <= qx + 35 and my >= qy - 15 and my <= qy - 2 then
            return labels[i], 1
        end
        -- Check Down button
        if mx >= qx + 10 and mx <= qx + 35 and my >= qy + h + 2 and my <= qy + h + 15 then
            return labels[i], -1
        end
    end
    return nil
end

function M.draw(n, l, m, viewMode, zoomMultiplier, lightMode, physics)
    local w, h = love.graphics.getDimensions()
    local time = love.timer.getTime()

    -- Colors
    local accent = {0.8, 0.4, 1.0, 0.8}
    local dim = {0.1, 0.1, 0.15, 0.5}
    local textCol = {1, 1, 1, 0.9}

    -- Aesthetic Quantum Colors (Not pure RGB)
    local qRed = {1.0, 0.3, 0.35}   -- Cyber Red/Coral
    local qGreen = {0.3, 1.0, 0.6}  -- Cyber Mint/Green
    local qBlue = {0.3, 0.7, 1.0}   -- Cyber Sky Blue

    -- 1. CENTRAL FOCUS BRACKETS
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 0.15 + 0.05 * math.sin(time * 2))
    local bSize = math.min(w, h) * 0.4
    drawBracket(w/2 - bSize/2, h/2 - bSize/2, bSize, bSize, 20)

    -- 1b. SCALE BAR below central brackets
    local S = orbitalScale(n, l)
    local worldPerPixel
    if viewMode == 3 then
        worldPerPixel = 6 * n * n * S * math.tan(0.7) / (zoomMultiplier * h)
    else
        worldPerPixel = 4 * n * n * S / (zoomMultiplier * h)
    end
    drawScaleBar(w/2, h/2 + bSize/2 + 20, worldPerPixel)

    -- 2. TOP LEFT: ORBITAL DATA PANEL
    local tx, ty = 30, 30
    love.graphics.setColor(dim)
    love.graphics.rectangle("fill", tx - 10, ty - 10, 260, 110, 4, 4)

    love.graphics.setColor(accent)
    love.graphics.setLineWidth(2)
    love.graphics.line(tx - 10, ty - 10, tx + 40, ty - 10)
    love.graphics.line(tx - 10, ty - 10, tx - 10, ty + 20)

    love.graphics.setColor(textCol)
    love.graphics.print(">> ORBITAL ANALYSIS", tx, ty)
    love.graphics.setColor(1, 0.7, 0.2, 1)
    love.graphics.print(string.format("IDENT: %d%s (m=%d)", n, l == 0 and "s" or l == 1 and "p" or l == 2 and "d" or l == 3 and "f" or "?", m), tx, ty + 22)

    -- Individual Quantum Boxes
    local qx = tx
    local qy = ty + 45
    drawQuantumBox(qx, qy, "n", n, qRed)
    drawQuantumBox(qx + 55, qy, "l", l, qGreen)
    drawQuantumBox(qx + 110, qy, "m", m, qBlue)

    love.graphics.setColor(textCol)
    local modeName = viewMode == 1 and "PROJECTION" or viewMode == 2 and "2D SLICE" or "3D VOLUME"
    love.graphics.print(string.format("MODE: %s", modeName), tx, ty + 85, 0, 0.85, 0.85)

    -- 3. TOP RIGHT: SYSTEM STATUS
    local rx, ry = w - 210, 30
    love.graphics.setColor(dim)
    love.graphics.rectangle("fill", rx - 10, ry - 10, 190, 60, 4, 4)

    love.graphics.setColor(0.3, 1.0, 0.5, 0.8)
    love.graphics.print("SYS STATUS: ONLINE", rx, ry)
    love.graphics.setColor(textCol)
    love.graphics.print(string.format("FRAME RATE: %d FPS", love.timer.getFPS()), rx, ry + 20)
    love.graphics.print(string.format("RENDER CORE: GLSL v3.3"), rx, ry + 40)

    -- 4. BOTTOM LEFT: CONTROLS HUD
    local bx, by = 30, h - 200
    love.graphics.setColor(dim)
    love.graphics.rectangle("fill", bx - 10, by - 10, 240, 200, 4, 4)

    love.graphics.setColor(accent)
    love.graphics.print("CONTROLS LOG:", bx, by)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local keys = {
        "[N/L/M] Incr Quantum",
        "[Shift+N/L/M] Decr",
        "[SCROLL] Adjust Zoom",
        "[DRAG] Rotate View",
        "[1] Projection",
        "[2/3] 2D Slice / 3D",
        "[I] Light Mode",
        "[R] Reset System",
        "[SPACE] Random Config",
        "[H] Toggle UI"
    }
    for i, line in ipairs(keys) do
        love.graphics.print(line, bx, by + 5 + i * 18)
    end

    -- 5. BOTTOM RIGHT: ZOOM GAUGE
    local zx, zy = w - 210, h - 60
    love.graphics.setColor(dim)
    love.graphics.rectangle("fill", zx - 10, zy - 10, 190, 45, 4, 4)

    love.graphics.setColor(textCol)
    love.graphics.print("ZOOM", zx, zy)

    local barW = 170
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", zx, zy + 20, barW, 6)

    local fill = (zoomMultiplier - 0.2) / (10.0 - 0.2)
    love.graphics.setColor(accent)
    love.graphics.rectangle("fill", zx, zy + 20, barW * fill, 6)
    love.graphics.print(string.format("%.0f%%", zoomMultiplier * 100), zx + barW - 40, zy)

    -- 6. DYNAMIC OVERLAY
    love.graphics.setColor(1, 1, 1, 0.03)
    for i = 0, h, 4 do
        love.graphics.line(0, i, w, i)
    end

    local p = 0.3 + 0.2 * math.sin(time * 3)
    love.graphics.setColor(accent[1], accent[2], accent[3], p)
    love.graphics.circle("fill", 15, 15, 3)
    love.graphics.circle("fill", w-15, 15, 3)
    love.graphics.circle("fill", 15, h-15, 3)
    love.graphics.circle("fill", w-15, h-15, 3)

    love.graphics.setColor(1, 1, 1, 1)
end

return M
