// Chapter02_CustomAnimations.swift — 第 2 章 自定义动画
// 覆盖：Animatable Shape、AnimatablePair、GeometryEffect、KeyframeAnimator、PhaseAnimator、CustomAnimation
// 参考：research/swiftui-motion/topics/02-custom-animations.md
// 所有示例独立 struct + #Preview，末尾 Chapter02_CustomAnimations 作为章节 root。

import SwiftUI

// MARK: - 2.1 Animatable Shape：正弦波浪（phase + amplitude 双 slider）

/// 双参数 Shape：phase 推进相位（横向流动），amplitude 控制波峰高度。
/// 用 `AnimatablePair<CGFloat, CGFloat>` 让 SwiftUI 同时插值两个分量。
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(phase, amplitude) }
        set { phase = newValue.first; amplitude = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let wavelength = max(1, rect.width / 2)
        p.move(to: .init(x: 0, y: midY))
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relative = (x / wavelength) + phase
            let y = midY + sin(relative * .pi * 2) * amplitude
            p.addLine(to: .init(x: x, y: y))
        }
        return p
    }
}

struct WaveDemo: View {
    @State private var phase: CGFloat = 0
    @State private var amplitude: CGFloat = 24
    @State private var autoFlow = true

    var body: some View {
        PlaygroundFrame("Animatable Shape · Wave") {
            WaveShape(phase: phase, amplitude: amplitude)
                .stroke(
                    LinearGradient(
                        colors: [AnycastColor.gold, AnycastColor.orange],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: .init(lineWidth: 3, lineCap: .round)
                )
                .padding(.horizontal, 24)
                .frame(height: 160)
                .animation(autoFlow
                            ? .linear(duration: 1.6).repeatForever(autoreverses: false)
                            : .default,
                           value: phase)
                .onAppear { if autoFlow { phase = 4 } }
                .onChange(of: autoFlow) { _, on in
                    phase = on ? 4 : 0
                }
        } controls: {
            Toggle("Auto flow (phase →)", isOn: $autoFlow)
                .tint(AnycastColor.orange)
            HStack {
                Text("Amplitude").font(.system(size: 12)).foregroundStyle(AnycastColor.sand9)
                Slider(value: $amplitude, in: 0...60)
                    .tint(AnycastColor.gold)
                Text("\(Int(amplitude))").font(AnycastFont.mono(12)).frame(width: 32)
            }
            HStack {
                Text("Phase").font(.system(size: 12)).foregroundStyle(AnycastColor.sand9)
                Slider(value: $phase, in: 0...4)
                    .tint(AnycastColor.gold)
                    .disabled(autoFlow)
                Text(String(format: "%.2f", phase)).font(AnycastFont.mono(12)).frame(width: 40)
            }
        }
    }
}

#Preview("2.1 Wave") { WaveDemo() }

// MARK: - 2.2 Animatable Shape：MorphStar（边数浮点插值 morph）

/// `sides` 浮点（3.0 → 8.0）插值实现"边数变化"动画；`inset` 控制星形凹陷。
struct MorphStar: Shape {
    var sides: CGFloat
    var inset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(sides, inset) }
        set { sides = newValue.first; inset = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let n = max(3, Int(sides.rounded()))
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        let step = .pi * 2 / CGFloat(n * 2)
        for i in 0..<(n * 2) {
            let radius = i.isMultiple(of: 2) ? r : r * (1 - inset)
            let angle = -.pi / 2 + step * CGFloat(i)
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}

struct MorphStarDemo: View {
    @State private var sides: CGFloat = 5
    @State private var inset: CGFloat = 0.45

    var body: some View {
        PlaygroundFrame("AnimatablePair · MorphStar") {
            MorphStar(sides: sides, inset: inset)
                .fill(
                    RadialGradient(
                        colors: [AnycastColor.orange, AnycastColor.gold],
                        center: .center, startRadius: 4, endRadius: 110
                    )
                )
                .frame(width: 180, height: 180)
                .animation(.spring(duration: 0.6, bounce: 0.35), value: sides)
                .animation(.easeInOut(duration: 0.4), value: inset)
        } controls: {
            HStack {
                Text("Sides").font(.system(size: 12)).foregroundStyle(AnycastColor.sand9)
                Slider(value: $sides, in: 3...8, step: 1)
                    .tint(AnycastColor.gold)
                Text("\(Int(sides))").font(AnycastFont.mono(12)).frame(width: 32)
            }
            HStack {
                Text("Inset ").font(.system(size: 12)).foregroundStyle(AnycastColor.sand9)
                Slider(value: $inset, in: 0...0.7)
                    .tint(AnycastColor.gold)
                Text(String(format: "%.2f", inset)).font(AnycastFont.mono(12)).frame(width: 40)
            }
        }
    }
}

#Preview("2.2 MorphStar") { MorphStarDemo() }

// MARK: - 2.3 GeometryEffect：Shake 抖动（密码错误反馈）

/// 每次 `attempts` 自增触发一次水平抖动；纯 transform，不触发 layout。
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: Int = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

extension View {
    func shake(times: Int, amount: CGFloat = 8) -> some View {
        modifier(ShakeEffect(amount: amount, animatableData: CGFloat(times)))
    }
}

struct ShakeDemo: View {
    @State private var attempts = 0
    @State private var password = ""

    var body: some View {
        PlaygroundFrame("GeometryEffect · Shake") {
            VStack(spacing: AnycastSpacing.gap) {
                SecureField("Enter password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                    .shake(times: attempts)
                    .animation(.linear(duration: 0.45), value: attempts)

                Button {
                    attempts += 1
                    password = ""
                } label: {
                    Text("Submit (always fails)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand1)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(AnycastColor.orange, in: .capsule)
                }

                Text("Attempts: \(attempts)")
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand9)
            }
        } controls: {
            Text("Each tap re-runs the Shake GeometryEffect — pure transform, no layout pass.")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("2.3 Shake") { ShakeDemo() }

// MARK: - 2.4 GeometryEffect：CardFlyIn (progress-driven 3D 飞入)

/// 单参数 progress 0→1 同时驱动 translate / scale / rotate / 透视 m34。
struct CardFlyIn: GeometryEffect {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress } set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let p = max(0, min(1, progress))
        let translateY = (1 - p) * 220
        let scale = 0.6 + 0.4 * p
        let angle = (1 - p) * .pi / 6   // 30° → 0°

        var t = CATransform3DIdentity
        t.m34 = -1 / 800
        t = CATransform3DTranslate(t, 0, translateY, 0)
        t = CATransform3DScale(t, scale, scale, 1)
        t = CATransform3DRotate(t, angle, 1, 0, 0)
        return ProjectionTransform(t)
    }
}

struct CardFlyInDemo: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        PlaygroundFrame("GeometryEffect · CardFlyIn") {
            ZStack {
                RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                    .fill(
                        LinearGradient(
                            colors: [AnycastColor.gold, AnycastColor.orange],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 130)
                    .overlay(
                        VStack(alignment: .leading, spacing: 6) {
                            Text("EP. 142")
                                .font(AnycastFont.mono(11))
                                .foregroundStyle(AnycastColor.sand1.opacity(0.85))
                            Text("Designing\nWith Motion")
                                .font(AnycastFont.display(20))
                                .foregroundStyle(AnycastColor.sand1)
                        }
                        .padding(16),
                        alignment: .topLeading
                    )
                    .modifier(CardFlyIn(progress: progress))
                    .shadow(color: .black.opacity(0.18 * Double(progress)), radius: 16, y: 10)
            }
            .animation(.spring(duration: 0.7, bounce: 0.32), value: progress)
        } controls: {
            HStack {
                Text("Progress").font(.system(size: 12)).foregroundStyle(AnycastColor.sand9)
                Slider(value: $progress, in: 0...1)
                    .tint(AnycastColor.gold)
                Text(String(format: "%.2f", progress)).font(AnycastFont.mono(12)).frame(width: 40)
            }
            HStack(spacing: 8) {
                Button("Fly out")  { progress = 0 }.buttonStyle(.bordered).tint(AnycastColor.sand9)
                Button("Fly in")   { progress = 1 }.buttonStyle(.borderedProminent).tint(AnycastColor.orange)
            }
        }
    }
}

#Preview("2.4 CardFlyIn") { CardFlyInDemo() }

// MARK: - 2.5 KeyframeAnimator：HeartBeat（多 track scale/rotation/yOffset）

/// 多 track 关键帧编排 — 每个属性独立曲线，按钮 trigger 推进一次。
struct HeartBeatDemo: View {
    @State private var beats = 0

    /// 关键帧目标值容器：每个属性一条独立 KeyframeTrack。
    struct BeatValues {
        var scale: CGFloat = 1
        var rotation: Angle = .zero
        var yOffset: CGFloat = 0
    }

    var body: some View {
        PlaygroundFrame("KeyframeAnimator · HeartBeat") {
            VStack(spacing: 18) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 88))
                    .foregroundStyle(AnycastColor.orange)
                    .keyframeAnimator(initialValue: BeatValues(), trigger: beats) { content, v in
                        content
                            .scaleEffect(v.scale)
                            .rotationEffect(v.rotation)
                            .offset(y: v.yOffset)
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.35, duration: 0.18, spring: .snappy)
                            SpringKeyframe(0.92, duration: 0.22, spring: .bouncy)
                            LinearKeyframe(1.0, duration: 0.15)
                        }
                        KeyframeTrack(\.rotation) {
                            CubicKeyframe(.degrees(-9), duration: 0.18)
                            CubicKeyframe(.degrees(9),  duration: 0.18)
                            CubicKeyframe(.zero,         duration: 0.15)
                        }
                        KeyframeTrack(\.yOffset) {
                            LinearKeyframe(-14, duration: 0.18)
                            SpringKeyframe(0,    duration: 0.42, spring: .bouncy)
                        }
                    }

                Button {
                    beats += 1
                } label: {
                    Text("Beat once  ·  \(beats)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand1)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(AnycastColor.orange, in: .capsule)
                }
            }
        } controls: {
            Text("3 tracks (scale / rotation / yOffset) run independent curves on every trigger.")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("2.5 HeartBeat") { HeartBeatDemo() }

// MARK: - 2.6 PhaseAnimator：LoadingDots (无限循环 phases)

/// 三个圆点轮流弹起，phase 自动循环；用 `.delay` 让每个 dot 错开。
struct LoadingDotsDemo: View {
    enum Phase: CaseIterable { case low, mid, high }

    var body: some View {
        PlaygroundFrame("PhaseAnimator · LoadingDots") {
            HStack(spacing: 14) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(AnycastColor.gold)
                        .frame(width: 18, height: 18)
                        .phaseAnimator(Phase.allCases) { content, phase in
                            content
                                .scaleEffect(phase == .high ? 1.35 : (phase == .mid ? 1.0 : 0.65))
                                .opacity(phase == .high ? 1.0 : 0.55)
                                .offset(y: phase == .high ? -10 : 0)
                        } animation: { phase in
                            switch phase {
                            case .low:  .easeIn(duration: 0.35).delay(Double(i) * 0.12)
                            case .mid:  .easeOut(duration: 0.30).delay(Double(i) * 0.12)
                            case .high: .spring(duration: 0.40, bounce: 0.45).delay(Double(i) * 0.12)
                            }
                        }
                }
            }
        } controls: {
            Text("phaseAnimator(_:) auto-cycles through allCases. Per-dot delay creates the wave.")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("2.6 LoadingDots") { LoadingDotsDemo() }

// MARK: - 2.7 PhaseAnimator + trigger：Toast 弹出

/// trigger 推进一次，从 hidden → sliding → settled → fading 走完一轮。
enum ToastPhase: CaseIterable {
    case hidden, sliding, settled, fading

    var offsetY: CGFloat {
        switch self {
        case .hidden, .fading: return -90
        case .sliding:         return -8
        case .settled:         return 0
        }
    }
    var opacity: Double {
        switch self {
        case .hidden, .fading: return 0
        default:               return 1
        }
    }
}

struct ToastDemo: View {
    @State private var trigger = 0
    @State private var message = "Episode saved"

    var body: some View {
        PlaygroundFrame("PhaseAnimator · Toast (trigger)") {
            VStack(spacing: 32) {
                ZStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AnycastColor.gold)
                        Text(message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AnycastColor.sand12)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: .capsule)
                    .overlay(Capsule().stroke(AnycastColor.sand4.opacity(0.5), lineWidth: 1))
                    .phaseAnimator(ToastPhase.allCases, trigger: trigger) { content, phase in
                        content
                            .offset(y: phase.offsetY)
                            .opacity(phase.opacity)
                    } animation: { phase in
                        switch phase {
                        case .sliding: .spring(duration: 0.45, bounce: 0.45)
                        case .settled: .linear(duration: 1.2)   // hold
                        case .fading:  .easeOut(duration: 0.35)
                        case .hidden:  .linear(duration: 0)
                        }
                    }
                }
                .frame(height: 56)

                Button {
                    trigger += 1
                } label: {
                    Text("Trigger toast")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand1)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(AnycastColor.gold, in: .capsule)
                }
            }
        } controls: {
            Text("trigger 形式：每次 +1 走完 hidden→sliding→settled→fading 完整一轮 phases。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("2.7 Toast") { ToastDemo() }

// MARK: - 2.8 GeometryEffect：3D Flip Card

/// 翻牌：angle 0→180°，绕 Y 轴翻转，带 m34 透视。
/// 注意：GeometryEffect 不影响 hit-testing，需 `.contentShape` 矫正点击区。
struct FlipEffect: GeometryEffect {
    var angle: Double
    let axis: (x: CGFloat, y: CGFloat)

    var animatableData: Double {
        get { angle } set { angle = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        var t = CATransform3DIdentity
        t.m34 = -1 / 500
        t = CATransform3DRotate(t, angle * .pi / 180, axis.x, axis.y, 0)
        return ProjectionTransform(t)
    }
}

struct FlipCardDemo: View {
    @State private var flipped = false

    var body: some View {
        PlaygroundFrame("GeometryEffect · 3D Flip") {
            ZStack {
                cardFront
                    .opacity(flipped ? 0 : 1)
                cardBack
                    .opacity(flipped ? 1 : 0)
            }
            .modifier(FlipEffect(angle: flipped ? 180 : 0, axis: (0, 1)))
            .contentShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
            .onTapGesture { flipped.toggle() }
            .animation(.spring(duration: 0.7, bounce: 0.25), value: flipped)
        } controls: {
            Text("Tap card to flip. m34 = -1/500 gives the perspective; affine alone would look flat.")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    private var cardFront: some View {
        RoundedRectangle(cornerRadius: AnycastRadius.card)
            .fill(AnycastColor.gold)
            .frame(width: 200, height: 130)
            .overlay(
                Text("FRONT")
                    .font(AnycastFont.display(28))
                    .foregroundStyle(AnycastColor.sand1)
            )
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: AnycastRadius.card)
            .fill(AnycastColor.sand12)
            .frame(width: 200, height: 130)
            .overlay(
                // 背面预先翻转 180°，避免显示成镜像
                Text("BACK")
                    .font(AnycastFont.display(28))
                    .foregroundStyle(AnycastColor.gold)
                    .rotation3DEffect(.degrees(180), axis: (0, 1, 0))
            )
    }
}

#Preview("2.8 FlipCard") { FlipCardDemo() }

// MARK: - Chapter Root

public struct Chapter02_CustomAnimations: View {
    public init() {}
    public var body: some View {
        List {
            Section("Animatable Shape") {
                NavigationLink("2.1 Wave (phase + amplitude)")        { ScrollView { WaveDemo() } }
                NavigationLink("2.2 MorphStar (sides 浮点插值)")       { ScrollView { MorphStarDemo() } }
            }
            Section("GeometryEffect") {
                NavigationLink("2.3 Shake (密码错误反馈)")             { ScrollView { ShakeDemo() } }
                NavigationLink("2.4 CardFlyIn (progress 驱动 3D)")     { ScrollView { CardFlyInDemo() } }
                NavigationLink("2.8 3D Flip (m34 透视)")               { ScrollView { FlipCardDemo() } }
            }
            Section("KeyframeAnimator (iOS 17+)") {
                NavigationLink("2.5 HeartBeat (多 track)")             { ScrollView { HeartBeatDemo() } }
            }
            Section("PhaseAnimator (iOS 17+)") {
                NavigationLink("2.6 LoadingDots (auto loop)")          { ScrollView { LoadingDotsDemo() } }
                NavigationLink("2.7 Toast (trigger 推进)")             { ScrollView { ToastDemo() } }
            }
        }
        .navigationTitle("2. Custom Animations")
        .listStyle(.insetGrouped)
    }
}

#Preview("Chapter 02 Root") {
    NavigationStack { Chapter02_CustomAnimations() }
}
