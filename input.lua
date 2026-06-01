-- Input handling: keyboard, mouse, wheel events

local M = {}

local state

function M.bind(s)
    state = s
end

function M.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        state.physics.reset()
        state.zoomMultiplier = 1.0
        state.cameraDist = state.cameraDistBase
    elseif key == "x" then
        state.physics.sliceX()
    elseif key == "y" then
        state.physics.sliceY()
    elseif key == "z" then
        state.physics.sliceZ()
    elseif key == "h" then
        state.showUI = not state.showUI
    elseif key == "1" then
        state.viewMode = 1
    elseif key == "2" then
        state.viewMode = 2
    elseif key == "3" then
        state.viewMode = 3
    elseif key == "i" then
        state.lightMode = 1 - state.lightMode
    end
end

function M.mousepressed(button)
    if button == 1 then
        state.physics.setDragState(true)
    end
end

function M.mousereleased(button)
    if button == 1 then
        state.physics.setDragState(false)
    end
end

function M.mousemoved(dx, dy)
    state.physics.updateMouseDelta(dx, dy)
    state.physics.applyTorque(dx, dy)
end

function M.wheelmoved(y)
    state.zoomMultiplier = state.zoomMultiplier + y * 0.1
    if state.zoomMultiplier < 0.2 then state.zoomMultiplier = 0.2 end
    if state.zoomMultiplier > 10.0 then state.zoomMultiplier = 10.0 end
end

return M
