#pragma language glsl3

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
precision highp float;

uniform float iTime;
uniform vec2 iResolution;
uniform vec4 rotQ;
uniform float orbitalScale;
uniform int quantumN;
uniform int quantumL;
uniform int quantumM;
uniform float maxDensity;
uniform float viewSize;
uniform int lightMode;
uniform float radialNorm;
uniform float shNorm;

#define PI 3.14159265358979

vec3 quatRotate(vec3 v, vec4 q) {
    vec3 t = 2.0 * cross(q.xyz, v);
    return v + q.w * t + cross(q.xyz, t);
}

float laguerre(int k, int alpha, float x) {
    if (k <= 0) return 1.0;
    if (k == 1) return 1.0 + float(alpha) - x;
    float L0 = 1.0;
    float L1 = 1.0 + float(alpha) - x;
    for (int i = 2; i <= k; i++) {
        float fi = float(i);
        float fa = float(alpha);
        float L = ((2.0*fi + fa - 1.0 - x) * L1 - (fi + fa - 1.0) * L0) / fi;
        L0 = L1;
        L1 = L;
    }
    return L1;
}

float radial(int n, int l, float r) {
    float rho = 2.0 * r / float(n);
    return radialNorm * exp(-rho * 0.5) * pow(rho, float(l)) * laguerre(n-l-1, 2*l+1, rho);
}

float assocLegendre(int l, int m, float x) {
    int abs_m = m < 0 ? -m : m;
    if (abs_m > l) return 0.0;
    float somx2 = sqrt(max(0.0, 1.0 - x * x));
    float pmm = 1.0;
    for (int i = 1; i <= abs_m; i++) {
        pmm *= float(2 * i - 1) * somx2;
    }
    if (l == abs_m) return pmm;
    float pmmp1 = x * float(2 * abs_m + 1) * pmm;
    if (l == abs_m + 1) return pmmp1;
    float pl_2 = pmm;
    float pl_1 = pmmp1;
    float pl = 0.0;
    for (int i = abs_m + 2; i <= l; i++) {
        float fi = float(i);
        float fm = float(abs_m);
        pl = ((2.0 * fi - 1.0) * x * pl_1 - (fi + fm - 1.0) * pl_2) / (fi - fm);
        pl_2 = pl_1;
        pl_1 = pl;
    }
    return pl;
}

float sphericalHarmonic(int l, int m, float theta, float phi) {
    int abs_m = m < 0 ? -m : m;
    if (abs_m > l) return 0.0;
    float ct = cos(theta);
    float Plm = assocLegendre(l, abs_m, ct);
    if (Plm == 0.0) return 0.0;
    if (m == 0) return shNorm * Plm;
    if (m > 0) return shNorm * Plm * cos(float(m) * phi);
    return shNorm * Plm * sin(float(abs_m) * phi);
}

vec3 getOrbitalColor(float a) {
    // Magma-like thermal palette: Black -> Deep Purple -> Magenta -> Orange -> White
    vec3 c1 = vec3(0.0, 0.0, 0.0);        // Black
    vec3 c2 = vec3(0.15, 0.02, 0.35);    // Deep Purple
    vec3 c3 = vec3(0.75, 0.05, 0.45);    // Purple-Red (Magenta)
    vec3 c4 = vec3(1.0, 0.55, 0.15);     // Orange
    vec3 c5 = vec3(1.0, 0.95, 0.75);     // Pale Yellow/White

    if (a < 0.2) return mix(c1, c2, a * 5.0);
    if (a < 0.4) return mix(c2, c3, (a - 0.2) * 5.0);
    if (a < 0.7) return mix(c3, c4, (a - 0.4) * 3.333);
    return mix(c4, c5, (a - 0.7) * 3.333);
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = (sc - 0.5 * iResolution) / iResolution.y;
    float S = orbitalScale;

    // Build the slice plane from quaternion:
    vec3 axisX = quatRotate(vec3(1.0, 0.0, 0.0), rotQ);
    vec3 axisY = quatRotate(vec3(0.0, 1.0, 0.0), rotQ);

    // Point on the slice plane (XY plane)
    vec3 p = uv.x * axisX * viewSize * S + uv.y * axisY * viewSize * S;

    float r = length(p);
    float theta = r > 0.0001 ? acos(clamp(p.y / r, -1.0, 1.0)) : 0.0;
    float phi = r > 0.0001 ? atan(p.z, p.x) : 0.0;

    int n = quantumN;
    int l = quantumL;
    int m = quantumM;

    float density;
    if (r < 0.0001) {
        float R0 = radial(n, l, 0.0);
        float Y0 = sphericalHarmonic(l, m, 0.0, 0.0);
        density = R0 * R0 * Y0 * Y0;
    } else {
        float R = radial(n, l, r/S);
        float Y = sphericalHarmonic(l, m, theta, phi);
        density = R*R * Y*Y;
    }

    float a = min(density / maxDensity, 1.0);
    vec3 col = getOrbitalColor(a);
    float brightness = 1.0;

    if (lightMode == 1 && r > 0.0001) {
        // Gradient-based pseudo-normal on slice plane
        float eps = 0.01 * S;
        vec3 p2x = p + axisX * eps;
        vec3 p2z = p + axisY * eps;
        float r_x = length(p2x), r_z = length(p2z);
        float theta_x = acos(clamp(p2x.y / r_x, -1.0, 1.0));
        float phi_x = atan(p2x.z, p2x.x);
        float theta_z = acos(clamp(p2z.y / r_z, -1.0, 1.0));
        float phi_z = atan(p2z.z, p2z.x);
        float R_x = radial(n, l, r_x/S);
        float R_z = radial(n, l, r_z/S);
        float Y_x = sphericalHarmonic(l, m, theta_x, phi_x);
        float Y_z = sphericalHarmonic(l, m, theta_z, phi_z);
        float d_x = R_x*R_x * Y_x*Y_x;
        float d_z = R_z*R_z * Y_z*Y_z;
        vec2 grad = vec2(d_x - density, d_z - density) / eps;
        vec3 normal = normalize(vec3(grad.x, 0.2, grad.y));

        vec3 L = normalize(vec3(0.5, 0.5, 1.0));
        float diffuse = max(0.0, dot(normal, L));
        brightness = 0.5 + 0.5 * diffuse;
    }

    col *= brightness;

    // Grid - subtle dark grid
    vec2 grid = abs(fract(uv * 10.0) - 0.5);
    float line = min(grid.x, grid.y);
    col *= 1.0 - 0.15 * (1.0 - smoothstep(0.0, 0.02, line));

    // Axes - subtle gray
    float ax = min(abs(uv.x), abs(uv.y));
    col = mix(col, vec3(0.5), 0.2 * (1.0 - smoothstep(0.0, 0.005, ax)));

    // Pulse
    col *= 0.98 + 0.02 * sin(iTime * 1.5);

    // Background fade
    vec3 bg = vec3(0.005, 0.005, 0.01);
    col = mix(bg, col, smoothstep(0.0, 0.01, a) * 0.95 + 0.05);

    return vec4(col, 1.0);
}

#endif
