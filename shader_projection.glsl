uniform vec2 iResolution;
uniform vec4 rotQ;
uniform float orbitalScale;
uniform int quantumN;
uniform int quantumL;
uniform int quantumM;
uniform float maxDensity;
uniform float viewSize;
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

float getDensity(int n, int l, int m, vec3 p, float S) {
    float r = length(p);
    if (r < 0.0001) {
        float R0 = radial(n, l, 0.0);
        float Y0 = sphericalHarmonic(l, m, 0.0, 0.0);
        return R0*R0 * Y0*Y0;
    }
    float theta = acos(clamp(p.y/r, -1.0, 1.0));
    float phi = atan(p.z, p.x);
    float R = radial(n, l, r/S);
    float Y = sphericalHarmonic(l, m, theta, phi);
    return R*R * Y*Y;
}

vec3 getOrbitalColor(float a) {
    vec3 c1 = vec3(0.0, 0.0, 0.0);
    vec3 c2 = vec3(0.15, 0.02, 0.35);
    vec3 c3 = vec3(0.75, 0.05, 0.45);
    vec3 c4 = vec3(1.0, 0.55, 0.15);
    vec3 c5 = vec3(1.0, 0.95, 0.75);
    vec3 col = mix(c1, c2, smoothstep(0.0, 0.15, a));
    col = mix(col, c3, smoothstep(0.15, 0.4, a));
    col = mix(col, c4, smoothstep(0.4, 0.7, a));
    col = mix(col, c5, smoothstep(0.7, 1.0, a));
    return col;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    vec2 uv = (sc - 0.5 * iResolution) / iResolution.y;
    float S = orbitalScale;

    vec3 axisX = quatRotate(vec3(1.0, 0.0, 0.0), rotQ);
    vec3 axisY = quatRotate(vec3(0.0, 1.0, 0.0), rotQ);
    vec3 axisZ = quatRotate(vec3(0.0, 0.0, 1.0), rotQ);

    // Base point on the projection plane
    vec3 base = uv.x * axisX * viewSize * S + uv.y * axisY * viewSize * S;

    int n = quantumN;
    int l = quantumL;
    int m = quantumM;
    float maxR = (float(n) * float(n) * 2.0) * S;

    // Integrate density along Z through the atom
    float total = 0.0;
    const int steps = 128;
    float range = maxR * 2.0;
    float dt = range / float(steps);

    // Dither
    float dither = fract(sin(dot(sc, vec2(12.9898, 78.233))) * 43758.5453);
    float t = -maxR + dither * dt;

    for (int i = 0; i < steps; i++) {
        vec3 p = base + axisZ * t;
        float r = length(p);
        if (r < maxR * 1.2) {
            total += getDensity(n, l, m, p, S) * dt;
        }
        t += dt;
    }

    // Normalize by column density through a uniform sphere of peak density
    float normalized = clamp(total / (maxDensity * maxR * 2.5), 0.0, 1.0);
    // Boost contrast
    float display = pow(normalized, 0.6);
    vec3 col = getOrbitalColor(display);

    return vec4(col, 1.0);
}
