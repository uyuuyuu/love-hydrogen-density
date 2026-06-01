-- Configure cpml path
local root = "./"
package.path = root .. "?.lua;" ..
               root .. "?/init.lua;" ..
               root .. "cpml/?.lua;" ..
               root .. "cpml/?/init.lua;" ..
               package.path

local orbitalsData = require("orbitals")
local physics = require("physics")
local ui = require("ui")
local input = require("input")
local cpml = require("cpml")
local vec3 = cpml.vec3
local quat = cpml.quat

local shader2D
local shader3D
local shaderProj
local startTime

local function orbitalScale(n, l)
    return n * (n + 1) / 2 - l * (l + 1) / 6
end

local function fact(x)
    local r = 1
    for i = 2, x do r = r * i end
    return r
end

local function radialNorm(n, l)
    return math.sqrt((2.0/n)^3 * fact(n-l-1) / (2.0*n * fact(n+l)))
end

local function shNorm(l, m)
    local abs_m = math.abs(m)
    local nrm = math.sqrt((2*l + 1) / (4*math.pi))
    nrm = nrm * math.sqrt(fact(l - abs_m) / fact(l + abs_m))
    if abs_m > 0 then nrm = nrm * math.sqrt(2) end
    return nrm
end

local densityCache = {}

local function getMaxDensity(n, l, m, S)
    local key = n .. "," .. l .. "," .. m
    if not densityCache[key] then
        densityCache[key] = orbitalsData.computeMaxDensity(n, l, m, S)
    end
    return densityCache[key]
end

-- Central state
local state = {
    viewMode = 1,
    zoomMultiplier = 1.0,
    cameraDistBase = 8.0,
    cameraDist = 8.0,
    lightMode = 0,
    currentN = 2,
    currentL = 0,
    currentM = 0,
    showUI = true,
    physics = physics,
}

input.bind(state)

function love.load()
    shader2D = love.graphics.newShader("shader_hydrogen.glsl")
    shader3D = love.graphics.newShader("shader_3d.glsl")
    shaderProj = love.graphics.newShader("shader_projection.glsl")
    startTime = love.timer.getTime()
    love.mouse.setRelativeMode(true)
    love.mouse.setVisible(true)
end

function love.update(dt)
    physics.update(dt)
end

function love.draw()
    local currentTime = love.timer.getTime()
    local iTime = currentTime - startTime
    local w, h = love.graphics.getDimensions()
    local nrmR = radialNorm(state.currentN, state.currentL)
    local nrmSH = shNorm(state.currentL, state.currentM)

    if state.viewMode == 1 then
        local invRot = physics.rotation:conjugate()
        local S = orbitalScale(state.currentN, state.currentL)
        local baseViewSize = (state.currentN * state.currentN * 2.0)
        local effectiveViewSize = baseViewSize / state.zoomMultiplier

        shaderProj:send("iResolution", { w, h })
        shaderProj:send("rotQ", { invRot.x, invRot.y, invRot.z, invRot.w })
        shaderProj:send("orbitalScale", S)
        shaderProj:send("quantumN", state.currentN)
        shaderProj:send("quantumL", state.currentL)
        shaderProj:send("quantumM", state.currentM)
        shaderProj:send("maxDensity", getMaxDensity(state.currentN, state.currentL, state.currentM, S))
        shaderProj:send("viewSize", effectiveViewSize)
        shaderProj:send("radialNorm", nrmR)
        shaderProj:send("shNorm", nrmSH)
        love.graphics.setShader(shaderProj)
    elseif state.viewMode == 2 then
        local invRot = physics.rotation:conjugate()
        local S = orbitalScale(state.currentN, state.currentL)
        -- Consistent with 3D: higher zoomMultiplier means smaller field of view (magnified)
        -- We define base size to be roughly the orbital extent
        local baseViewSize = (state.currentN * state.currentN * 2.0)
        local effectiveViewSize = baseViewSize / state.zoomMultiplier

        shader2D:send("iTime", iTime)
        shader2D:send("iResolution", { w, h })
        shader2D:send("rotQ", { invRot.x, invRot.y, invRot.z, invRot.w })
        shader2D:send("orbitalScale", S)
        shader2D:send("quantumN", state.currentN)
        shader2D:send("quantumL", state.currentL)
        shader2D:send("quantumM", state.currentM)
        shader2D:send("maxDensity", getMaxDensity(state.currentN, state.currentL, state.currentM, S))
        shader2D:send("viewSize", effectiveViewSize)
        shader2D:send("lightMode", state.lightMode)
        shader2D:send("radialNorm", nrmR)
        shader2D:send("shNorm", nrmSH)
        love.graphics.setShader(shader2D)
    else
        local S = orbitalScale(state.currentN, state.currentL)
        local maxR = (state.currentN * state.currentN * 2.0) * S
        local baseDist = maxR * 1.5
        local effectiveCameraDist = baseDist / state.zoomMultiplier

        local camDir = vec3(0, 0, -1)
        camDir = physics.rotation:mul_vec3(camDir)
        local lightOffset = quat.from_angle_axis(math.pi/6, vec3(0, 1, 0))
        local lightDir = lightOffset:mul_vec3(camDir)
        local invRot = physics.rotation:conjugate()

        shader3D:send("iTime", iTime)
        shader3D:send("iResolution", { w, h })
        shader3D:send("rotQ", { invRot.x, invRot.y, invRot.z, invRot.w })
        shader3D:send("orbitalScale", S)
        shader3D:send("quantumN", state.currentN)
        shader3D:send("quantumL", state.currentL)
        shader3D:send("quantumM", state.currentM)
        shader3D:send("maxDensity", getMaxDensity(state.currentN, state.currentL, state.currentM, S))
        shader3D:send("cameraDist", effectiveCameraDist)
        shader3D:send("lightDir", { lightDir.x, lightDir.y, lightDir.z })
        shader3D:send("lightMode", state.lightMode)
        shader3D:send("radialNorm", nrmR)
        shader3D:send("shNorm", nrmSH)
        love.graphics.setShader(shader3D)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setShader()

    if state.showUI then
        ui.draw(state.currentN, state.currentL, state.currentM, state.viewMode, state.zoomMultiplier, state.lightMode, physics)
    end
end

local function changeQuantum(qn, delta)
    if qn == "n" then
        state.currentN = math.max(1, state.currentN + delta)
        state.currentL = math.min(state.currentL, state.currentN - 1)
    elseif qn == "l" then
        state.currentL = math.max(0, math.min(state.currentN - 1, state.currentL + delta))
    elseif qn == "m" then
        state.currentM = math.max(-state.currentL, math.min(state.currentL, state.currentM + delta))
    end
end

local function randomizeQuantum()
    local maxN = 8
    state.currentN = math.random(1, maxN)
    state.currentL = math.random(0, state.currentN - 1)
    state.currentM = math.random(-state.currentL, state.currentL)
end

function love.keypressed(key)
    local isShift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local delta = isShift and -1 or 1

    if key == "n" then
        changeQuantum("n", delta)
    elseif key == "l" then
        changeQuantum("l", delta)
    elseif key == "m" then
        changeQuantum("m", delta)
    elseif key == "space" then
        randomizeQuantum()
    else
        input.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        local qn, delta = ui.getClickedQuantumButton(x, y)
        if qn then
            changeQuantum(qn, delta)
            return
        end
    end
    input.mousepressed(button)
end

function love.mousereleased(x, y, button)
    input.mousereleased(button)
end

function love.mousemoved(x, y, dx, dy)
    input.mousemoved(dx, dy)
end

function love.wheelmoved(x, y)
    input.wheelmoved(y)
end
