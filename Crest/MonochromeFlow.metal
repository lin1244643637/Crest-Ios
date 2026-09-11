#include <metal_stdlib>
using namespace metal;

[[ stitchable ]] half4 monochromeFlow(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / max(size, float2(1.0));
    float2 p = (position - size * 0.5) / max(min(size.x, size.y), 1.0);

    // The surface and its reflections share one continuous, travelling fold field.
    float bendA = p.y * 2.15 - time * 0.26;
    float bendB = p.y * 3.6 + time * 0.19;
    float bend = 0.48 * sin(bendA) + 0.14 * sin(bendB);
    float bendSlope = 1.032 * cos(bendA) + 0.504 * cos(bendB);
    float fold = (p.x + bend) * 7.8 + p.y * 2.1 - time * 0.48;
    float twist = p.y * 1.7 + time * 0.23;
    float detail = fold * 1.65 + 0.6 * sin(twist);

    float foldX = 7.8;
    float foldY = bendSlope * 7.8 + 2.1;
    float slope = -0.16 * sin(fold);
    float detailSlope = -0.028 * sin(detail);
    float dx = slope * foldX + detailSlope * foldX * 1.65;
    float dy = slope * foldY + detailSlope * (foldY * 1.65 + 1.02 * cos(twist));
    float3 normal = normalize(float3(-dx, -dy, 1.0));
    float3 reflection = reflect(float3(0.0, 0.0, -1.0), normal);

    // Broad softbox light, a travelling narrow reflection, and deep unlit folds.
    float3 keyLight = normalize(float3(-0.55 + 0.22 * sin(time * 0.31), 0.35, 1.0));
    float3 rimLight = normalize(float3(0.75, -0.45 + 0.18 * sin(time * 0.27), 0.65));
    float key = max(dot(reflection, keyLight), 0.0);
    float rim = max(dot(reflection, rimLight), 0.0);
    float openFold = smoothstep(-0.85, 0.75, cos(fold));
    float shade = 0.018 + 0.055 * openFold;
    shade += (0.90 * pow(key, 3.5) + 0.38 * pow(key, 32.0)) * (0.35 + 0.65 * openFold);
    shade += 0.65 * pow(rim, 28.0) * (0.45 + 0.55 * openFold);
    shade += 0.20 * pow(key, 2.0) * openFold;

    float edgeShade = 1.0 - 0.34 * smoothstep(0.25, 0.72, abs(uv.x - 0.45));
    float lowerShade = 1.0 - 0.64 * smoothstep(0.50, 1.0, uv.y);
    float upperShade = mix(0.60, 1.0, smoothstep(0.0, 0.22, uv.y));
    half luminance = half(clamp(shade * edgeShade * lowerShade * upperShade, 0.008, 1.0));
    return half4(half3(luminance), 1.0) * color.a;
}
