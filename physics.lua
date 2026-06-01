-- Rigid body physics using cpml (quaternion integration, angular momentum, torque)

local cpml = require("cpml")
local vec3 = cpml.vec3
local quat = cpml.quat

local M = {}

M.rotation = quat.unit
M.angularMomentum = vec3.zero
M.torque = vec3.zero
M.inertia_inv = vec3.new(1, 1, 1)
M.friction = 0.995
M.torqueScale = 0.1

M.isDragging = false
M.currentDX = nil
M.currentDY = nil

function M.update(dt)
    M.angularMomentum = M.angularMomentum + M.torque * dt

    local q_conj = M.rotation:conjugate()
    local L_body = q_conj:mul_vec3(M.angularMomentum)
    local omega_body = vec3.mul(L_body, M.inertia_inv)
    local omega = M.rotation:mul_vec3(omega_body)

    local omega_q = quat(omega.x, omega.y, omega.z, 0)
    local dq = (omega_q * M.rotation) * (0.5 * dt)
    M.rotation = (M.rotation + dq):normalize()

    M.angularMomentum = M.angularMomentum * M.friction
    M.torque = vec3.zero
end

function M.applyTorque(dx, dy)
    if M.isDragging then
        local t = vec3.new(-dy * M.torqueScale, dx * M.torqueScale, 0)
        M.torque = M.torque + t
    end
end

function M.setDragState(dragging)
    M.isDragging = dragging
end

function M.updateMouseDelta(dx, dy)
    M.currentDX, M.currentDY = dx, dy
end

function M.reset()
    M.rotation = quat.from_angle_axis(-math.pi/2, vec3(1, 0, 0))
    M.angularMomentum = vec3.zero
    M.torque = vec3.zero
    M.currentDX = nil
    M.currentDY = nil
end

function M.sliceX()
    M.rotation = quat.from_angle_axis(math.pi/2, vec3(0, 0, 1))
    M.angularMomentum = vec3.zero
    M.torque = vec3.zero
end

function M.sliceY()
    M.rotation = quat.from_angle_axis(-math.pi/2, vec3(1, 0, 0))
    M.angularMomentum = vec3.zero
    M.torque = vec3.zero
end

function M.sliceZ()
    M.rotation = quat.unit
    M.angularMomentum = vec3.zero
    M.torque = vec3.zero
end

return M
