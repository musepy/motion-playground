// Chapter07_CanvasTimeline.swift
// 第 7 章：Canvas + TimelineView + GraphicsContext 可运行示例
//
// 6 个独立示例 + 1 个章节根视图：
//   7.1 CanvasBasics       — Canvas + GraphicsContext 基本用法（路径/渐变/transform）
//   7.2 FireworksParticles — 点击触发烟花 burst（drawLayer + .blur + .plusLighter）
//   7.3 WaveformBars       — 32-bin 波形可视化（sin 推动 + linearGradient 着色）
//   7.4 DashedLoadingRing  — 旋转虚线环 loading（用 ctx.date 时间）
//   7.5 FilterPlayground   — Slider 调 blur / saturation / hueRotation
//   7.6 ResolvedSymbols    — symbols ViewBuilder + resolveSymbol 高效绘制
//
// 注意：示例 7.2/7.3/7.4 使用 rendersAsynchronously: true；renderer 闭包内
// 严禁捕获 ObservableObject / @MainActor 状态——只读 @State 内的值类型快照。
// 物理 tick 在主线程的 TimelineView body 中先做完再交给 Canvas 绘制。
import SwiftUI

// MARK: - 7.1 Canvas 入门

/// 演示 GraphicsContext 三件事：fill / stroke / transform 状态拷贝。
/// 不需要每帧刷新——单帧静态绘制即可。
struct CanvasBasicsDemo: View {
    var body: some View {
        PlaygroundFrame("7.1 Canvas 入门") {
            Canvas { ctx, size in
                // 1. 渐变填充矩形（背景）
                let bgRect = CGRect(origin: .zero, size: size)
                ctx.fill(
                    Path(bgRect),
                    with: .linearGradient(
                        Gradient(colors: [AnycastColor.sand2, AnycastColor.sand1]),
                        startPoint: .zero,
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // 2. 描边圆环
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 3
                let ring = Path { p in
                    p.addArc(center: center, radius: radius,
                             startAngle: .degrees(0),
                             endAngle: .degrees(360),
                             clockwise: false)
                }
                ctx.stroke(
                    ring,
                    with: .color(AnycastColor.goldAlpha60),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )

                // 3. transform 状态拷贝：副本变换不污染外层
                var inner = ctx
                inner.translateBy(x: center.x, y: center.y)
                inner.rotate(by: .degrees(30))
                let square = CGRect(x: -28, y: -28, width: 56, height: 56)
                inner.fill(
                    Path(roundedRect: square, cornerRadius: AnycastRadius.sm),
                    with: .color(AnycastColor.gold9)
                )

                // 外层 ctx 未受 inner 旋转影响
                let dot = CGRect(x: size.width - 18, y: 8, width: 10, height: 10)
                ctx.fill(Path(ellipseIn: dot), with: .color(AnycastColor.orange))
            }
            .padding(AnycastSpacing.gap)
            .accessibilityLabel("Canvas 基础绘制示例")
        } controls: {
            Text("fill + stroke + transform；副本 inner 的旋转不污染外层 ctx。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("7.1 Canvas Basics") {
    CanvasBasicsDemo()
}

// MARK: - 7.2 烟花粒子系统

/// 烟花粒子：值类型，可安全跨 actor 拷贝到异步 Canvas renderer。
struct FireworkParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var birth: TimeInterval
    var lifespan: TimeInterval
    var hue: Double
    var size: CGFloat
}

struct FireworksParticlesDemo: View {
    @State private var particles: [FireworkParticle] = []
    @State private var lastTick: TimeInterval = 0
    @State private var tapCount: Int = 0

    var body: some View {
        PlaygroundFrame("7.2 烟花粒子（点击触发 burst）") {
            GeometryReader { geo in
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    // 主线程 tick：物理积分 + 老化清理
                    let snapshot = simulate(now: now)

                    Canvas(opaque: true,
                           colorMode: .linear,
                           rendersAsynchronously: true) { ctx, size in
                        // opaque=true 必须自己填背景
                        ctx.fill(Path(CGRect(origin: .zero, size: size)),
                                 with: .color(AnycastColor.sand12))

                        // 在隔离层里做 blur + plusLighter，外层不受影响
                        ctx.drawLayer { layer in
                            layer.addFilter(.blur(radius: 3))
                            layer.blendMode = .plusLighter
                            for p in snapshot {
                                let age = now - p.birth
                                let life = max(0, 1 - age / p.lifespan)
                                let r = p.size * (0.6 + life)
                                let rect = CGRect(
                                    x: p.position.x - r,
                                    y: p.position.y - r,
                                    width: r * 2, height: r * 2
                                )
                                var c = layer
                                c.opacity = life
                                c.fill(
                                    Path(ellipseIn: rect),
                                    with: .color(
                                        Color(hue: p.hue,
                                              saturation: 0.9,
                                              brightness: 1.0)
                                    )
                                )
                            }
                        }

                        // 提示文字（cache resolve 避免每帧重排版）
                        let hint = ctx.resolve(
                            Text("点击任意位置")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AnycastColor.sand4)
                        )
                        ctx.draw(hint, at: CGPoint(x: 12, y: 12), anchor: .topLeading)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .contentShape(Rectangle())
                .onTapGesture { location in
                    let now = Date().timeIntervalSinceReferenceDate
                    burst(at: location, now: now)
                    tapCount += 1
                }
            }
            .padding(AnycastSpacing.gap)
            .accessibilityLabel("烟花粒子动画，点击触发 burst")
            .accessibilityValue("已触发 \(tapCount) 次")
        } controls: {
            HStack {
                Text("已 burst \(tapCount) 次")
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button("自动 burst 一次") {
                    let now = Date().timeIntervalSinceReferenceDate
                    burst(at: CGPoint(x: 160, y: 120), now: now)
                    tapCount += 1
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnycastColor.gold9)
            }
        }
    }

    /// 主线程做物理积分，返回当前帧的快照。
    private func simulate(now: TimeInterval) -> [FireworkParticle] {
        let dt: TimeInterval
        if lastTick == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(now - lastTick, 1.0 / 30.0) // 卡顿封顶
        }
        // mutate @State on main thread
        DispatchQueue.main.async {
            self.lastTick = now
            self.particles.removeAll { now - $0.birth > $0.lifespan }
            for i in self.particles.indices {
                self.particles[i].velocity.dy += 220 * dt
                self.particles[i].position.x += self.particles[i].velocity.dx * dt
                self.particles[i].position.y += self.particles[i].velocity.dy * dt
            }
        }
        return particles
    }

    private func burst(at p: CGPoint, now: TimeInterval) {
        let count = 48
        let baseHue = Double.random(in: 0...1)
        var added: [FireworkParticle] = []
        added.reserveCapacity(count)
        for i in 0..<count {
            let angle = (Double(i) / Double(count)) * .pi * 2
            let speed = Double.random(in: 80...200)
            added.append(
                FireworkParticle(
                    position: p,
                    velocity: CGVector(dx: cos(angle) * speed,
                                       dy: sin(angle) * speed),
                    birth: now,
                    lifespan: .random(in: 0.9...1.6),
                    hue: (baseHue + Double.random(in: -0.05...0.05))
                        .truncatingRemainder(dividingBy: 1),
                    size: .random(in: 2...4)
                )
            )
        }
        particles.append(contentsOf: added)
    }
}

#Preview("7.2 Fireworks") {
    FireworksParticlesDemo()
}

// MARK: - 7.3 波形可视化

/// 32-bin 波形：每帧用 sin + 时间偏移推动，模拟实时音频频谱。
struct WaveformBarsDemo: View {
    private let binCount = 32
    @State private var seeds: [Double] = (0..<32).map { _ in Double.random(in: 0...1) }

    var body: some View {
        PlaygroundFrame("7.3 波形可视化（32 bin）") {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let bins = computeBins(at: t)

                Canvas(rendersAsynchronously: true) { ctx, size in
                    let inset: CGFloat = 12
                    let usableW = size.width - inset * 2
                    let usableH = size.height - inset * 2
                    let gap: CGFloat = 3
                    let barW = (usableW - gap * CGFloat(bins.count - 1)) / CGFloat(bins.count)

                    for (i, mag) in bins.enumerated() {
                        let h = max(4, CGFloat(mag) * usableH)
                        let x = inset + CGFloat(i) * (barW + gap)
                        let y = inset + (usableH - h)
                        let rect = CGRect(x: x, y: y, width: barW, height: h)
                        let path = Path(roundedRect: rect, cornerRadius: barW / 2)
                        ctx.fill(
                            path,
                            with: .linearGradient(
                                Gradient(colors: [
                                    AnycastColor.gold9,
                                    AnycastColor.orangeAlpha80
                                ]),
                                startPoint: CGPoint(x: 0, y: rect.maxY),
                                endPoint: CGPoint(x: 0, y: rect.minY)
                            )
                        )
                    }
                }
                .padding(AnycastSpacing.gap)
            }
            .accessibilityLabel("音频频谱可视化")
            .accessibilityValue("32 个频段，每帧由正弦波驱动")
        } controls: {
            Button("重新随机种子") {
                seeds = (0..<binCount).map { _ in Double.random(in: 0...1) }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AnycastColor.gold9)

            Text("每帧用 sin(t·freq + phase) 驱动 mag；linearGradient 沿 y 着色。")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    /// 纯函数：根据时间和 seed 数组计算每个 bin 的 magnitude（0...1）。
    private func computeBins(at t: TimeInterval) -> [Double] {
        seeds.enumerated().map { i, seed in
            let freq = 0.7 + seed * 1.6
            let phase = seed * 6.0
            let lowFreq = 0.4 + Double(i) / Double(binCount) * 0.6
            let raw = sin(t * freq + phase) * 0.4
                + sin(t * lowFreq * 0.5 + seed) * 0.4
                + 0.5
            return max(0.05, min(1.0, raw))
        }
    }
}

#Preview("7.3 Waveform") {
    WaveformBarsDemo()
}

// MARK: - 7.4 旋转虚线环 Loading

/// 用 ctx.date 时间驱动旋转的虚线环 + 中心可解析 Text。
/// 两环反向旋转，速度不同。
struct DashedLoadingRingDemo: View {
    var body: some View {
        PlaygroundFrame("7.4 虚线环 Loading") {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas(rendersAsynchronously: true) { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outerR = min(size.width, size.height) / 2 - 28
                    let innerR = outerR - 18

                    // 外环：顺时针，慢
                    drawDashedRing(
                        ctx: ctx,
                        center: center,
                        radius: outerR,
                        rotation: .radians(t.truncatingRemainder(dividingBy: 2 * .pi)),
                        color: AnycastColor.goldAlpha60,
                        dash: [6, 8],
                        lineWidth: 3
                    )
                    // 内环：逆时针，快
                    drawDashedRing(
                        ctx: ctx,
                        center: center,
                        radius: innerR,
                        rotation: .radians(-t.truncatingRemainder(dividingBy: 2 * .pi) * 1.6),
                        color: AnycastColor.orangeAlpha60,
                        dash: [3, 5],
                        lineWidth: 2
                    )

                    // 中心 label
                    let resolved = ctx.resolve(
                        Text("LOADING")
                            .font(AnycastFont.mono(11))
                            .foregroundColor(AnycastColor.sand12)
                    )
                    ctx.draw(resolved, at: center, anchor: .center)
                }
                .padding(AnycastSpacing.gap)
            }
            .accessibilityLabel("加载中动画")
        } controls: {
            Text("两环反向旋转：t mod 2π 直接当作角度。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    private func drawDashedRing(
        ctx: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        rotation: Angle,
        color: Color,
        dash: [CGFloat],
        lineWidth: CGFloat
    ) {
        var ring = Path()
        ring.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360),
                    clockwise: false)

        var local = ctx
        local.translateBy(x: center.x, y: center.y)
        local.rotate(by: rotation)
        local.translateBy(x: -center.x, y: -center.y)
        local.stroke(
            ring,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: .round,
                dash: dash
            )
        )
    }
}

#Preview("7.4 Loading Ring") {
    DashedLoadingRingDemo()
}

// MARK: - 7.5 Filter Playground

/// 在 Canvas 内用 addFilter 调 blur / saturation / hueRotation。
/// 用 Slider 调三个参数实时观察。
struct FilterPlaygroundDemo: View {
    @State private var blurRadius: Double = 0
    @State private var saturation: Double = 1
    @State private var hueShift: Double = 0

    var body: some View {
        PlaygroundFrame("7.5 Filter 演示") {
            Canvas { ctx, size in
                // 背景
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(AnycastColor.sand1))

                // 在 drawLayer 内施加 filter，仅影响内部绘制
                ctx.drawLayer { layer in
                    if blurRadius > 0.01 {
                        layer.addFilter(.blur(radius: blurRadius))
                    }
                    layer.addFilter(.saturation(saturation))
                    layer.addFilter(.hueRotation(.degrees(hueShift)))

                    // 三个色块：演示 filter 作用
                    let colors: [Color] = [
                        AnycastColor.gold9,
                        AnycastColor.orange9,
                        AnycastColor.sand12
                    ]
                    let count = colors.count
                    let pad: CGFloat = 16
                    let totalW = size.width - pad * 2
                    let blockW = (totalW - pad * CGFloat(count - 1)) / CGFloat(count)
                    let blockH: CGFloat = min(size.height - pad * 2, 100)
                    let y = (size.height - blockH) / 2
                    for (i, c) in colors.enumerated() {
                        let x = pad + CGFloat(i) * (blockW + pad)
                        let rect = CGRect(x: x, y: y, width: blockW, height: blockH)
                        layer.fill(
                            Path(roundedRect: rect, cornerRadius: AnycastRadius.sm),
                            with: .color(c)
                        )
                    }

                    // 渐变叠加，看 hueRotation
                    let stripe = CGRect(
                        x: pad,
                        y: y + blockH + 12,
                        width: size.width - pad * 2,
                        height: 14
                    )
                    layer.fill(
                        Path(roundedRect: stripe, cornerRadius: 7),
                        with: .linearGradient(
                            Gradient(colors: [
                                AnycastColor.gold9,
                                AnycastColor.orange9,
                                AnycastColor.sand12
                            ]),
                            startPoint: CGPoint(x: stripe.minX, y: 0),
                            endPoint: CGPoint(x: stripe.maxX, y: 0)
                        )
                    )
                }
            }
            .padding(AnycastSpacing.gap)
            .accessibilityLabel("Filter 演示画布")
            .accessibilityValue(
                "blur \(Int(blurRadius))，saturation \(String(format: "%.1f", saturation))，色相 \(Int(hueShift)) 度"
            )
        } controls: {
            sliderRow("Blur",
                      value: $blurRadius,
                      range: 0...30,
                      formatted: String(format: "%.1f", blurRadius))
            sliderRow("Saturation",
                      value: $saturation,
                      range: 0...3,
                      formatted: String(format: "%.2f", saturation))
            sliderRow("Hue°",
                      value: $hueShift,
                      range: -180...180,
                      formatted: "\(Int(hueShift))")
        }
    }

    @ViewBuilder
    private func sliderRow(_ label: String,
                           value: Binding<Double>,
                           range: ClosedRange<Double>,
                           formatted: String) -> some View {
        HStack {
            Text(label)
                .font(AnycastFont.mono(11))
                .foregroundStyle(AnycastColor.sand12)
                .frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
                .tint(AnycastColor.gold9)
            Text(formatted)
                .font(AnycastFont.mono(11))
                .foregroundStyle(AnycastColor.sand9)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

#Preview("7.5 Filter Playground") {
    FilterPlaygroundDemo()
}

// MARK: - 7.6 ResolvedSymbols

/// 演示 symbols ViewBuilder + resolveSymbol(id:)：
/// 把带 .palette 渲染的 SF Symbol 烘焙成 ResolvedSymbol，每帧绘制多次。
struct ResolvedSymbolsDemo: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        PlaygroundFrame("7.6 Symbols + Resolve") {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas(
                    renderer: { ctx, size in
                        guard let star = ctx.resolveSymbol(id: 0),
                              let wave = ctx.resolveSymbol(id: 1) else { return }

                        let count = 6
                        let radius: CGFloat = min(size.width, size.height) / 3
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)

                        for i in 0..<count {
                            let baseAngle = (Double(i) / Double(count)) * .pi * 2
                            let angle = baseAngle + t * 0.6
                            let p = CGPoint(
                                x: center.x + cos(angle) * radius,
                                y: center.y + sin(angle) * radius
                            )
                            ctx.draw(i.isMultiple(of: 2) ? star : wave,
                                     at: p, anchor: .center)
                        }

                        ctx.draw(star, at: center, anchor: .center)
                    },
                    symbols: {
                        Image(systemName: "star.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AnycastColor.gold9, AnycastColor.sand4)
                            .font(.system(size: 28, weight: .semibold))
                            .tag(0)

                        Image(systemName: "waveform.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(AnycastColor.orange9, AnycastColor.sand2)
                            .font(.system(size: 28, weight: .semibold))
                            .tag(1)
                    }
                )
                .padding(AnycastSpacing.gap)
            }
            .accessibilityLabel("符号轨道动画")
        } controls: {
            Text("symbols ViewBuilder 让 .palette 模式生效；resolveSymbol(id: Int) 缓存避免每帧重 resolve。")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("7.6 Resolved Symbols") {
    ResolvedSymbolsDemo()
}

// MARK: - Chapter Root

/// 第 7 章入口：6 个示例集合页。ContentView 的 NavigationLink 跳转到此。
struct Chapter07_CanvasTimeline: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AnycastSpacing.sectionGap) {
                CanvasBasicsDemo()
                FireworksParticlesDemo()
                WaveformBarsDemo()
                DashedLoadingRingDemo()
                FilterPlaygroundDemo()
                ResolvedSymbolsDemo()

                Text("Canvas + TimelineView：50+ 个独立元素同动、需 blendMode/filter、每帧物理模拟时选 Canvas；少量元素或单元素命中测试用 Shape + animatableData。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                    .padding(.horizontal, AnycastSpacing.pageH)
                    .padding(.bottom, AnycastSpacing.sectionGap)
            }
            .padding(.top, AnycastSpacing.pageHeader)
        }
        .background(AnycastColor.sand1.ignoresSafeArea())
        .navigationTitle("7. Canvas + Timeline")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 7 Root") {
    NavigationStack {
        Chapter07_CanvasTimeline()
    }
}
