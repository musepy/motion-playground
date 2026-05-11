// AnycastShaders.metal — Chapter 6 配套 Metal Shading Language 着色器
// 4 个 [[stitchable]] 函数对应 Chapter06_MetalShaders.swift 的 4 个示例：
//   - goldShimmer        (colorEffect)        金色渐变 + 流动 sheen
//   - ripple             (distortionEffect)   点击涟漪 UV 扭曲
//   - chromaticAberration (layerEffect)        红/蓝通道横向偏移
//   - filmGrain          (colorEffect)        随机噪声颗粒 + 角落 vignette
//
// SwiftUI 三个入口对 MSL 函数签名的强约束：
//   colorEffect:      half4 fn(float2 position, half4 color, ...)
//   distortionEffect: float2 fn(float2 position, ...)
//   layerEffect:      half4 fn(float2 position, SwiftUI::Layer layer, ...)
// 必须加 [[stitchable]]，否则 SwiftUI 静默 no-op。
//
// 调试 tip：新 shader 第一行 `return half4(1,0,1,1);`，看到 magenta 才说明通路活着。

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;


// MARK: - hash21：低成本 2D → 1D 噪声，用于 grain
inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}


// MARK: - 1) goldShimmer (colorEffect)
// 把原 view 像素颜色和金色 sheen 做混合，sheen 沿 X 轴随时间流动。
// 参数：strength 0~1 控制混合强度；time 用 TimelineView 注入；bounds 来自 .boundingRect。
[[ stitchable ]] half4 goldShimmer(float2 position,
                                   half4 color,
                                   float strength,
                                   float time,
                                   float4 bounds) {
    // 把绝对像素坐标归一化到 0~1，方便用 sin 做横向流动
    float u = (position.x - bounds.x) / max(bounds.z, 1.0);
    float v = (position.y - bounds.y) / max(bounds.w, 1.0);

    // 主 wave：横向移动；副 wave：与 v 错相位让 sheen 不平直
    float wave = 0.5 + 0.5 * sin((u - time * 0.55) * 6.2831);
    float diag = 0.5 + 0.5 * sin((u + v * 0.4 - time * 0.35) * 4.0);
    float sheenAmt = mix(wave, diag, 0.4);

    half3 gold     = half3(0.95h, 0.78h, 0.32h);  // Anycast gold（display-referred）
    half3 sheenCol = half3(1.0h, 0.92h, 0.78h);   // 高光白金

    half3 base   = mix(color.rgb, gold, half(strength) * 0.55h);
    half3 final  = mix(base, sheenCol, half(sheenAmt) * half(strength) * 0.35h);

    return half4(final, color.a);
}


// MARK: - 2) ripple (distortionEffect)
// 点击触发的水波涟漪：从 origin 向外推一圈正弦扭曲，时间衰减。
// 输出新的采样坐标，SwiftUI 用 linear sampler 取颜色。
// maxSampleOffset 必须 ≥ amplitude，否则边缘 clamp 出黑边。
[[ stitchable ]] float2 ripple(float2 position,
                               float2 origin,
                               float time,
                               float amplitude,
                               float frequency,
                               float decay,
                               float speed) {
    float2 d = position - origin;
    float r  = length(d);

    float front = time * speed;     // 波前位置
    float delta = r - front;        // 当前像素离波前的距离

    // 正弦波 × 时间衰减 × 距离衰减（让涟漪只在波前附近一圈生效）
    float wave = sin(frequency * delta * 0.05)
               * exp(-decay * time)
               * exp(-abs(delta) * 0.01);

    float2 dir = r > 0.0001 ? d / r : float2(0.0);
    return position + dir * wave * amplitude;
}


// MARK: - 3) chromaticAberration (layerEffect)
// RGB 三通道分别从不同偏移采样，模拟廉价镜头色散。
// 红通道往右、蓝通道往左、绿/alpha 在原位。
[[ stitchable ]] half4 chromaticAberration(float2 position,
                                           SwiftUI::Layer layer,
                                           float amount) {
    half r = layer.sample(position + float2( amount, 0.0)).r;
    half g = layer.sample(position).g;
    half b = layer.sample(position + float2(-amount, 0.0)).b;
    half a = layer.sample(position).a;
    return half4(r, g, b, a);
}


// MARK: - 4) filmGrain (colorEffect)
// 像素位置 + time 喂 hash 出每帧不同的噪声值，叠加到原色，再叠 vignette 让四角变暗。
// intensity 同时控制 grain 强度和 vignette 深度。
[[ stitchable ]] half4 filmGrain(float2 position,
                                 half4 color,
                                 float intensity,
                                 float time,
                                 float4 bounds) {
    float2 uv = (position - bounds.xy) / max(bounds.zw, float2(1.0));

    // grain：高频 hash，每帧用 time 偏移噪点
    float n = hash21(uv * 800.0 + time * 60.0) - 0.5;
    half3 grained = color.rgb + half(n * intensity);

    // vignette：到中心距离平方衰减
    float2 c = uv - 0.5;
    float vig = 1.0 - dot(c, c) * (0.4 + intensity * 1.6);
    vig = clamp(vig, 0.0, 1.0);

    return half4(grained * half(vig), color.a);
}
