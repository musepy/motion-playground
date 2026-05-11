// Chapter06_MetalShaders.swift — 第 6 章：Metal Shader 三入口集成
// 来自 research/swiftui-motion/topics/06-metal-shaders.md 的可运行示例。
//
// SwiftUI iOS 17+ 把 Metal 着色器以三个 ViewModifier 直接挂上视图渲染管线：
//   .colorEffect       —— 逐像素重新着色（最便宜，不读邻居）
//   .distortionEffect  —— 输出新 UV，SwiftUI 用 linear sampler 重采样
//   .layerEffect       —— 把整张已栅格化 layer 传给 shader，可任意采样（最贵）
//
// 全部 Shader 函数在 Resources/AnycastShaders.metal，加了 [[stitchable]]，
// 在 SwiftPM target 里要用 `ShaderLibrary.bundle(.module).funcName(...)` 引用，
// 不能用 `.default`（.default 只看 main bundle）。
//
// 4 个示例：goldShimmer / ripple / chromaticAberration / filmGrain
import SwiftUI


// MARK: - 共用：本章 Shader 库（SwiftPM resource bundle，不是 main bundle）
private let anycastShaders = ShaderLibrary.bundle(.module)


// MARK: - 示例 1：金色 colorEffect Shimmer
// `.colorEffect` 不需要 SwiftUI 给纹理，逐像素重新着色 → 最便宜的入口。
// strength slider 调金色 + sheen 混合强度；TimelineView(.animation) 喂 time。
struct GoldShimmerDemo: View {
    @State private var strength: Float = 0.7
    private let start = Date()

    var body: some View {
        PlaygroundFrame("colorEffect · 金色 Shimmer") {
            TimelineView(.animation) { ctx in
                let t = Float(ctx.date.timeIntervalSince(start))
                // base view —— 一块 sand 卡片，shader 负责把它染成流动的金
                RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                    .fill(AnycastColor.sand4)
                    .frame(width: 260, height: 160)
                    .overlay(
                        Text("ANYCAST")
                            .font(AnycastFont.display(28))
                            .foregroundStyle(AnycastColor.sand12)
                            .tracking(4)
                    )
                    .colorEffect(
                        anycastShaders.goldShimmer(
                            .float(strength),
                            .float(t),
                            .boundingRect
                        )
                    )
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("strength")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Spacer()
                    Text(String(format: "%.2f", strength))
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                }
                Slider(value: $strength, in: 0...1)
                    .tint(AnycastColor.gold)
                Text("sheen 沿 X 轴流动；time 由 TimelineView(.animation) 每帧注入。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("1. Gold Shimmer (colorEffect)") { GoldShimmerDemo() }


// MARK: - 示例 2：点击涟漪 (distortionEffect + KeyframeAnimator)
// `.distortionEffect` 的 shader 输出新采样 UV，由 SwiftUI 重采样原图。
// 用 `.keyframeAnimator(trigger:)` 把 elapsedTime 从 0 推到 duration，
// shader 内部用 time × speed 计算波前位置 + 时间衰减。
struct RippleDemo: View {
    @State private var origin: CGPoint = .init(x: 140, y: 90)
    @State private var trigger: Int = 0

    // 与 shader 内一致的常量；amplitude 决定 maxSampleOffset
    private let duration: TimeInterval = 1.2
    private let amplitude: Float = 14
    private let frequency: Float = 18
    private let decay: Float = 4
    private let speed: Float = 800

    var body: some View {
        PlaygroundFrame("distortionEffect · 点击涟漪") {
            ZStack {
                // 一块带网格的 base view，方便看到 UV 扭曲
                gridArt
                    .frame(width: 280, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                    .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
                        view.distortionEffect(
                            anycastShaders.ripple(
                                .float2(Float(origin.x), Float(origin.y)),
                                .float(Float(elapsed)),
                                .float(amplitude),
                                .float(frequency),
                                .float(decay),
                                .float(speed)
                            ),
                            // padding 必须 ≥ amplitude，否则边缘像素被 clamp 成黑边
                            maxSampleOffset: CGSize(width: CGFloat(amplitude),
                                                    height: CGFloat(amplitude)),
                            isEnabled: elapsed < duration
                        )
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(duration, duration: duration)
                    }
                    .onTapGesture { loc in
                        origin = loc
                        trigger &+= 1
                    }
            }
        } controls: {
            HStack {
                Text("点击图块任意位置触发涟漪")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button("Trigger Center") {
                    origin = .init(x: 140, y: 90)
                    trigger &+= 1
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnycastColor.orange)
            }
        }
    }

    private var gridArt: some View {
        ZStack {
            AnycastColor.sand4
            // 4×3 棋盘格，让涟漪扭曲看得见
            VStack(spacing: 0) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { col in
                            Rectangle()
                                .fill((row + col).isMultiple(of: 2)
                                      ? AnycastColor.sand2
                                      : AnycastColor.sand4)
                        }
                    }
                }
            }
            // 中央徽标
            Circle()
                .strokeBorder(AnycastColor.gold, lineWidth: 3)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AnycastColor.gold)
                )
        }
    }
}

#Preview("2. Ripple (distortionEffect)") { RippleDemo() }


// MARK: - 示例 3：Chromatic Aberration (layerEffect)
// `.layerEffect` 把整张离屏栅格化的 SwiftUI::Layer 传给 shader，
// 可在 shader 内部对任意位置 sample()。这里把 R / B 通道横向偏移，模拟廉价镜头色散。
struct ChromaticAberrationDemo: View {
    @State private var amount: Float = 4.0

    var body: some View {
        PlaygroundFrame("layerEffect · 色散 Chromatic Aberration") {
            VStack(spacing: 12) {
                // 高对比 base —— 边缘越锐利，色散越显眼
                Text("AB")
                    .font(AnycastFont.display(120))
                    .foregroundStyle(AnycastColor.sand12)
                    .padding(.horizontal, 24)
                    .background(AnycastColor.sand1)
                    .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                    .layerEffect(
                        anycastShaders.chromaticAberration(.float(amount)),
                        // 偏移最大值就是 amount，给同样大小的采样 padding
                        maxSampleOffset: CGSize(width: CGFloat(amount),
                                                height: CGFloat(amount))
                    )
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("amount (px)")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Spacer()
                    Text(String(format: "%.1f", amount))
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                }
                Slider(value: $amount, in: 0...20)
                    .tint(AnycastColor.orange)
                Text("R/B 通道横向偏移；amount=0 看原图，>10 已经像 VHS 噪声了。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("3. Chromatic Aberration (layerEffect)") { ChromaticAberrationDemo() }


// MARK: - 示例 4：Film Grain + Vignette (colorEffect)
// 颗粒 + 暗角是「质感」最廉价但最有效的工具。Anycast 的 sand grain 卡片就这套。
// time 让噪声每帧不同（不动的话像静态噪点贴图，没有胶片感）。
struct FilmGrainDemo: View {
    @State private var intensity: Float = 0.12
    private let start = Date()

    var body: some View {
        PlaygroundFrame("colorEffect · Film Grain + Vignette") {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                let t = Float(ctx.date.timeIntervalSince(start))
                // base view —— 中性渐变卡片
                ZStack {
                    LinearGradient(
                        colors: [AnycastColor.sand4, AnycastColor.sand9],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 6) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 56, weight: .regular))
                            .foregroundStyle(AnycastColor.gold)
                        Text("EP 042 · Field Recording")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AnycastColor.sand1)
                    }
                }
                .frame(width: 280, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .colorEffect(
                    anycastShaders.filmGrain(
                        .float(intensity),
                        .float(t),
                        .boundingRect
                    )
                )
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("intensity")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Spacer()
                    Text(String(format: "%.2f", intensity))
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                }
                Slider(value: $intensity, in: 0...0.5)
                    .tint(AnycastColor.gold)
                Text("intensity 同时驱动颗粒强度和 vignette 深度；time 让噪声逐帧变化。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("4. Film Grain (colorEffect)") { FilmGrainDemo() }


// MARK: - 章节入口：列表索引 4 个示例
struct Chapter06_MetalShaders: View {
    var body: some View {
        List {
            Section("Metal Shader 三入口") {
                NavigationLink("1. Gold Shimmer · colorEffect")        { GoldShimmerDemo() }
                NavigationLink("2. Ripple · distortionEffect")          { RippleDemo() }
                NavigationLink("3. Chromatic Aberration · layerEffect") { ChromaticAberrationDemo() }
                NavigationLink("4. Film Grain + Vignette · colorEffect") { FilmGrainDemo() }
            }
            Section("说明") {
                Text("Shader 函数在 Resources/AnycastShaders.metal，必须 [[stitchable]]。SwiftPM target 用 ShaderLibrary.bundle(.module)，不能用 .default。模拟器需 Apple Silicon Mac；Intel Mac 软栅格可能黑屏。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("6. Metal Shaders")
        .listStyle(.insetGrouped)
    }
}

#Preview("Chapter 6 Index") {
    NavigationStack { Chapter06_MetalShaders() }
}
