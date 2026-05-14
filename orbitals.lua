-- Orbital definitions, wave function helpers, and precomputed max densities

local M = {}

-- 19 orbitals
M.orbitals = {
    { name = "2s",     n = 2, l = 0, m = 0 },
    { name = "2p_z",   n = 2, l = 1, m = 0 },
    { name = "2p_x",   n = 2, l = 1, m = 1 },
    { name = "3s",     n = 3, l = 0, m = 0 },
    { name = "3p_z",   n = 3, l = 1, m = 0 },
    { name = "3p_x",   n = 3, l = 1, m = 1 },
    { name = "3d_z2",  n = 3, l = 2, m = 0 },
    { name = "3d_xz",  n = 3, l = 2, m = 1 },
    { name = "3d_xy",  n = 3, l = 2, m = 2 },
    { name = "4s",     n = 4, l = 0, m = 0 },
    { name = "4p_z",   n = 4, l = 1, m = 0 },
    { name = "4p_x",   n = 4, l = 1, m = 1 },
    { name = "4d_z2",  n = 4, l = 2, m = 0 },
    { name = "4d_xz",  n = 4, l = 2, m = 1 },
    { name = "4d_xy",  n = 4, l = 2, m = 2 },
    { name = "4f_z3",  n = 4, l = 3, m = 0 },
    { name = "4f_xz2", n = 4, l = 3, m = 1 },
    { name = "4f_xyz", n = 4, l = 3, m = 2 },
    { name = "4f_x3",  n = 4, l = 3, m = 3 },
}

M.orbitalScales = {
    3.0,  3.0,  3.0,
    6.0,  6.0,  6.0,
    5.0,  5.0,  5.0,
    10.0, 10.0, 10.0,
    8.0,  8.0,  8.0,
    6.5,  6.5,  6.5, 6.5,
}

-- Wave function helpers
local sqrt = math.sqrt
local exp = math.exp
local cos = math.cos
local sin = math.sin
local atan2 = math.atan2
local acos = math.acos
local abs = math.abs
local pi = math.pi

local function fact(n)
    local r = 1
    for i = 2, n do r = r * i end
    return r
end

local function laguerre(k, alpha, x)
    local result = 0
    for j = 0, k do
        local sign = (j % 2 == 0) and 1 or -1
        local binom = fact(k + alpha) / (fact(k - j) * fact(alpha + j))
        result = result + sign * binom / fact(j) * (x^j)
    end
    return result
end

local function radialLua(n, l, r)
    local rho = 2.0 * r / n
    local N = sqrt((2.0/n)^3 * fact(n-l-1) / (2.0*n * fact(n+l)))
    return N * exp(-rho/2) * (rho^l) * laguerre(n-l-1, 2*l+1, rho)
end

local function assocLegendre(l, m, x)
    local abs_m = math.abs(m)
    if abs_m > l then return 0 end
    local somx2 = math.sqrt(math.max(0, 1 - x*x))
    local pmm = 1.0
    for i = 1, abs_m do
        pmm = pmm * (2*i - 1) * somx2
    end
    if l == abs_m then return pmm end
    local pmmp1 = x * (2*abs_m + 1) * pmm
    if l == abs_m + 1 then return pmmp1 end
    local pl_2, pl_1 = pmm, pmmp1
    for i = abs_m + 2, l do
        local pl = ((2*i - 1) * x * pl_1 - (i + abs_m - 1) * pl_2) / (i - abs_m)
        pl_2, pl_1 = pl_1, pl
    end
    return pl_1
end

local function sphericalHarmonicLua(l, m, theta, phi)
    local abs_m = math.abs(m)
    if abs_m > l then return 0 end
    local ct = math.cos(theta)
    local Plm = assocLegendre(l, abs_m, ct)
    if Plm == 0 then return 0 end
    local norm = math.sqrt((2*l + 1) / (4*pi))
    norm = norm * math.sqrt(fact(l - abs_m) / fact(l + abs_m))
    if abs_m > 0 then norm = norm * math.sqrt(2) end
    if m == 0 then return norm * Plm end
    if m > 0 then return norm * Plm * math.cos(m * phi) end
    return norm * Plm * math.sin(abs_m * phi)
end

local function psi2Lua(n, l, m, r, theta, phi)
    if r < 0.001 then
        local R0 = radialLua(n, l, 0.0)
        local Y0 = sphericalHarmonicLua(l, m, 0.0, 0.0)
        return R0*R0 * Y0*Y0
    end
    local R = radialLua(n, l, r)
    local Y = sphericalHarmonicLua(l, m, theta, phi)
    return R*R * Y*Y
end

-- Generate 1D Radial Texture (Look-up Table) for a specific orbital
function M.createRadialImageData(o, resolution, maxR_scaled)
    local data = love.image.newImageData(resolution, 1)

    -- 1. Find the peak absolute amplitude for this orbital
    local maxAmp = 1e-10
    for i = 0, resolution - 1 do
        local r_scaled = (i / (resolution - 1)) * maxR_scaled
        local val = math.abs(radialLua(o.n, o.l, r_scaled))
        if val > maxAmp then maxAmp = val end
    end

    -- 2. Store normalized absolute amplitude in Red channel
    for i = 0, resolution - 1 do
        local r_scaled = (i / (resolution - 1)) * maxR_scaled
        local val = math.abs(radialLua(o.n, o.l, r_scaled))
        data:setPixel(i, 0, val / maxAmp, 0, 0, 1)
    end

    return data, maxAmp
end

function M.computeMaxDensity(n, l, m, S)
    local maxR = (n * n * 2.0) * S

    -- max of density = max(R(r)^2) x max(Y(theta,phi)^2), since R and Y are separable
    -- Find max R(r)^2
    local maxRadial2 = 0

    for ir = 0, 200 do
        local r = (ir / 200) * maxR
        local R = radialLua(n, l, r/S)
        local R2 = R*R
        if R2 > maxRadial2 then maxRadial2 = R2 end
    end
    if maxRadial2 == 0 then return 1e-10 end

    -- Find max Y^2 via Fibonacci sphere sampling (uniform on sphere)
    local maxAngular2 = 0
    local golden = (1 + math.sqrt(5)) / 2
    local nSamples = 300
    for i = 0, nSamples - 1 do
        local theta = math.acos(1 - 2 * (i + 0.5) / nSamples)
        local phi = 2 * pi * i / golden
        local Y = sphericalHarmonicLua(l, m, theta, phi)
        local Y2 = Y*Y
        if Y2 > maxAngular2 then maxAngular2 = Y2 end
    end

    return maxRadial2 * maxAngular2
end

-- Precompute max density for each orbital
M.orbitalMaxDensity = {}

for i, o in ipairs(M.orbitals) do
    local S = M.orbitalScales[i]
    -- Increased maxR for precomputation to capture true peak of higher n orbitals
    local maxR = (o.n * o.n + 4.0) * S
    local maxD = 0

    for ir = 0, 200 do
        for iphi = 0, 100 do
            local r = (ir / 200) * maxR
            local phi = (iphi / 100) * 2.0 * pi
            local theta = pi / 2.0
            local d = psi2Lua(o.n, o.l, o.m, r/S, theta, phi)
            if d > maxD then maxD = d end
        end
    end

    for ir = 0, 200 do
        for itheta = 0, 100 do
            local r = (ir / 200) * maxR
            local theta = (itheta / 100) * pi
            local phi = 0
            local d = psi2Lua(o.n, o.l, o.m, r/S, theta, phi)
            if d > maxD then maxD = d end
        end
    end

    M.orbitalMaxDensity[i] = maxD > 0 and maxD or 1e-10
    print(string.format("Orbital %d (%s): max density = %g", i, o.name, M.orbitalMaxDensity[i]))
end

return M
