// Chapter01_AnimationBasics.swift — 第 1 章：动画基础 + Spring 物理
// 来自 research/swiftui-motion/topics/01-animation-fundamentals.md 的可运行示例。
// 每个示例独立 struct，配 #Preview；末尾 Chapter01_AnimationBasics 是入口列表。
import SwiftUI

// MARK: - 示例 1：Implicit vs Explicit —— 同一动作两种声明方式
struct AnimationImplicitVsExplicitDemo: View {
    @State private var implicitOn = false
    @State private var explicitOn = false

    var body: some View {
        PlaygroundFrame("Implicit vs Explicit") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                // implicit: 修饰符链上的 .animation(_:value:) 监听局部 state
                VStack(spacing: AnycastSpacing.gap) {
                    Image(systemName: implicitOn ? "pause.fill" : "play.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(implicitOn ? AnycastColor.orange : AnycastColor.sand9)
                        .scaleEffect(implicitOn ? 1.25 : 1.0)
                        .animation(.snappy(duration: 0.25), value: implicitOn)
                    Text("implicit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .onTapGesture { implicitOn.toggle() }

                // explicit: withAnimation 把状态变更包起来，跨 view 都生效
                VStack(spacing: AnycastSpacing.gap) {
                    Image(systemName: explicitOn ? "heart.fill" : "heart")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(explicitOn ? AnycastColor.gold : AnycastColor.sand9)
                        .scaleEffect(explicitOn ? 1.25 : 1.0)
                    Text("explicit")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .onTapGesture {
                    withAnimation(.bouncy(duration: 0.5)) { explicitOn.toggle() }
                }
            }
        } controls: {
            Text("点左：.animation(.snappy, value:) 修饰符。点右：withAnimation(.bouncy) 包闭包。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("1. Implicit vs Explicit") { AnimationImplicitVsExplicitDemo() }


// MARK: - 示例 2：缓动家族对照 —— linear / easeIn / easeOut / easeInOut
struct EasingFamilyDemo: View {
    @State private var moved = false
    private let curves: [(name: String, animation: Animation)] = [
        ("linear",     .linear(duration: 0.9)),
        ("easeIn",     .easeIn(duration: 0.9)),
        ("easeOut",    .easeOut(duration: 0.9)),
        ("easeInOut",  .easeInOut(duration: 0.9))
    ]

    var body: some View {
        PlaygroundFrame("缓动家族对照") {
            VStack(spacing: 14) {
                ForEach(curves, id: \.name) { curve in
                    HStack(spacing: AnycastSpacing.gap) {
                        Text(curve.name)
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand9)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AnycastColor.sand12.opacity(0.08))
                                    .frame(height: 6)
                                Circle()
                                    .fill(AnycastColor.gold)
                                    .frame(width: 18, height: 18)
                                    .offset(x: moved ? max(0, geo.size.width - 18) : 0)
                                    .animation(curve.animation, value: moved)
                            }
                            .frame(height: 18)
                        }
                        .frame(height: 18)
                    }
                }
            }
            .padding(.horizontal, AnycastSpacing.pageH)
        } controls: {
            HStack {
                Text("同一段距离，不同曲线的速度感差异")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button(moved ? "返回" : "出发") { moved.toggle() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnycastColor.orange)
            }
        }
    }
}

#Preview("2. Easing Family") { EasingFamilyDemo() }


// MARK: - 示例 3：iOS 17 简写 —— smooth / snappy / bouncy 对比
struct SpringPresetPickerDemo: View {
    enum Preset: String, CaseIterable, Identifiable {
        case smooth, snappy, bouncy
        var id: String { rawValue }
        var animation: Animation {
            switch self {
            case .smooth: return .smooth(duration: 0.5)
            case .snappy: return .snappy(duration: 0.5)
            case .bouncy: return .bouncy(duration: 0.5)
            }
        }
        var subtitle: String {
            switch self {
            case .smooth: return "duration 0.5, bounce 0 — 无反弹"
            case .snappy: return "duration 0.5, bounce 0.15 — 利落"
            case .bouncy: return "duration 0.5, bounce 0.3 — 活泼"
            }
        }
    }

    @State private var preset: Preset = .snappy
    @State private var pushed = false

    var body: some View {
        PlaygroundFrame("Spring 简写：smooth / snappy / bouncy") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                ZStack {
                    RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                        .fill(AnycastColor.goldAlpha40)
                        .frame(width: 120, height: 120)
                        .offset(x: pushed ? 90 : -90)
                        .animation(preset.animation, value: pushed)
                }
                .frame(maxWidth: .infinity)

                Button {
                    pushed.toggle()
                } label: {
                    Text(pushed ? "回弹" : "弹出")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AnycastColor.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Picker("Spring", selection: $preset) {
                    ForEach(Preset.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                Text(preset.subtitle)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("3. Spring Preset Picker") { SpringPresetPickerDemo() }


// MARK: - 示例 4：Spring Tuner —— 实时调 response 与 bounce，直观感受物理
struct SpringTunerDemo: View {
    @State private var response: Double = 0.5      // 0.1 ... 2.0
    @State private var bounce: Double = 0.2        // -0.3 ... 0.7
    @State private var toggled = false

    var body: some View {
        PlaygroundFrame("Spring Tuner") {
            ZStack {
                // 静态参考轨：起点和终点位置
                HStack {
                    Circle()
                        .stroke(AnycastColor.sand4, lineWidth: 1)
                        .frame(width: 20, height: 20)
                    Spacer()
                    Circle()
                        .stroke(AnycastColor.sand4, lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 60)

                // 动画化的弹球
                Circle()
                    .fill(AnycastColor.orange)
                    .overlay(
                        Circle()
                            .stroke(AnycastColor.orangeAlpha80, lineWidth: 2)
                    )
                    .frame(width: 64, height: 64)
                    .offset(x: toggled ? 110 : -110)
                    .animation(.spring(duration: response, bounce: bounce), value: toggled)
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                tunerRow(label: "response",
                         value: response,
                         range: 0.1...2.0,
                         display: String(format: "%.2f s", response)) {
                    Slider(value: $response, in: 0.1...2.0)
                        .tint(AnycastColor.gold)
                }

                tunerRow(label: "bounce",
                         value: bounce,
                         range: -0.3...0.7,
                         display: String(format: "%+.2f", bounce)) {
                    Slider(value: $bounce, in: -0.3...0.7)
                        .tint(AnycastColor.orange)
                }

                HStack {
                    Text("dampingFraction ≈ \(String(format: "%.2f", 1 - bounce))")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Spacer()
                    Button {
                        toggled.toggle()
                    } label: {
                        Text("Animate")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AnycastColor.gold, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tunerRow<Content: View>(label: String,
                                         value: Double,
                                         range: ClosedRange<Double>,
                                         display: String,
                                         @ViewBuilder slider: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
                Spacer()
                Text(display)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)
            }
            slider()
        }
    }
}

#Preview("4. Spring Tuner") { SpringTunerDemo() }


// MARK: - 示例 5：组合修饰符 —— delay / repeatForever / speed
struct PulseRepeatDemo: View {
    @State private var pulse = false
    @State private var speed: Double = 1.0

    var body: some View {
        PlaygroundFrame("Repeat / Delay / Speed") {
            ZStack {
                // 三个错峰脉冲圈，演示 .delay 错开节奏
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(AnycastColor.goldAlpha60, lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulse ? 2.4 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.4)
                                .repeatForever(autoreverses: false)
                                .speed(speed)
                                .delay(Double(i) * 0.45),
                            value: pulse
                        )
                }
                Circle()
                    .fill(AnycastColor.orange)
                    .frame(width: 56, height: 56)
            }
            .onAppear { pulse = true }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("speed")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                    Spacer()
                    Text(String(format: "%.2fx", speed))
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                }
                Slider(value: $speed, in: 0.25...3.0)
                    .tint(AnycastColor.gold)
                Text(".repeatForever + .delay 错峰 + .speed 倍率叠加")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("5. Pulse Repeat") { PulseRepeatDemo() }


// MARK: - 示例 6：修饰符顺序 —— scale ↔ rotate 顺序对插值轨迹的影响
struct ModifierOrderDemo: View {
    @State private var big = false

    var body: some View {
        PlaygroundFrame("修饰符顺序：scale ↔ rotate") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                VStack(spacing: 8) {
                    // A: scale 在内，rotate 在外 —— 旋转的是已放大的形状
                    RoundedRectangle(cornerRadius: AnycastRadius.sm)
                        .fill(AnycastColor.gold)
                        .frame(width: 60, height: 60)
                        .scaleEffect(big ? 1.6 : 1.0)
                        .rotationEffect(.degrees(big ? 90 : 0))
                        .animation(.snappy(duration: 0.6), value: big)
                    Text("scale → rotate")
                        .font(AnycastFont.mono(10))
                        .foregroundStyle(AnycastColor.sand9)
                }

                VStack(spacing: 8) {
                    // B: rotate 在内，scale 在外 —— 先旋转再放大
                    RoundedRectangle(cornerRadius: AnycastRadius.sm)
                        .fill(AnycastColor.orange)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(big ? 90 : 0))
                        .scaleEffect(big ? 1.6 : 1.0)
                        .animation(.snappy(duration: 0.6), value: big)
                    Text("rotate → scale")
                        .font(AnycastFont.mono(10))
                        .foregroundStyle(AnycastColor.sand9)
                }
            }
        } controls: {
            HStack {
                Text("两个用同一动画，但中间扫过区域不同")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button(big ? "复位" : "变换") { big.toggle() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnycastColor.orange)
            }
        }
    }
}

#Preview("6. Modifier Order") { ModifierOrderDemo() }


// MARK: - 示例 7：Transaction —— 同一帧多 state，按字段决定要不要插值
struct TransactionDemo: View {
    @State private var expanded = false
    @State private var unread = 0

    var body: some View {
        PlaygroundFrame("Transaction：拦截不想动的字段") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                HStack(spacing: AnycastSpacing.gap) {
                    RoundedRectangle(cornerRadius: AnycastRadius.sm)
                        .fill(AnycastColor.goldAlpha60)
                        .frame(width: expanded ? 180 : 100, height: 64)

                    Text("\(unread)")
                        .font(AnycastFont.display(28))
                        .foregroundStyle(AnycastColor.sand12)
                        .frame(width: 56, height: 56)
                        .background(AnycastColor.orangeAlpha60, in: Circle())
                        // 这一段：即使外层 withAnimation 想 lerp 数字，也被拦下来瞬切
                        .transaction { $0.animation = nil }
                }

                Button {
                    withAnimation(.bouncy(duration: 0.55)) {
                        expanded.toggle()
                        unread += 1
                    }
                } label: {
                    Text(expanded ? "收起 + 计数" : "展开 + 计数")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AnycastColor.orange, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        } controls: {
            Text("withAnimation 同时改 expanded + unread；transaction.animation = nil 让数字不参与插值，避免出现 4/5/6 中间帧")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("7. Transaction Override") { TransactionDemo() }


// MARK: - Chapter root —— 章节入口列表
struct Chapter01_AnimationBasics: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "Implicit vs Explicit",
                 subtitle: ".animation(_:value:) 与 withAnimation 的边界",
                 view: AnyView(AnimationImplicitVsExplicitDemo())),
            Demo(number: 2, title: "Easing Family",
                 subtitle: "linear / easeIn / easeOut / easeInOut 速度感对比",
                 view: AnyView(EasingFamilyDemo())),
            Demo(number: 3, title: "Spring Preset Picker",
                 subtitle: "iOS 17 .smooth / .snappy / .bouncy 三件套",
                 view: AnyView(SpringPresetPickerDemo())),
            Demo(number: 4, title: "Spring Tuner",
                 subtitle: "拖 response / bounce 滑块直观感受弹簧物理",
                 view: AnyView(SpringTunerDemo())),
            Demo(number: 5, title: "Pulse Repeat",
                 subtitle: ".repeatForever + .delay + .speed 组合",
                 view: AnyView(PulseRepeatDemo())),
            Demo(number: 6, title: "Modifier Order",
                 subtitle: "scale 与 rotate 先后顺序如何改变插值轨迹",
                 view: AnyView(ModifierOrderDemo())),
            Demo(number: 7, title: "Transaction Override",
                 subtitle: "同帧多 state，用 transaction 拦下不想动的字段",
                 view: AnyView(TransactionDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 1 章 · 动画基础 + Spring 物理") {
                ForEach(demos) { demo in
                    NavigationLink {
                        ScrollView { demo.view }
                            .background(AnycastColor.sand1.ignoresSafeArea())
                            .navigationTitle(demo.title)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: AnycastSpacing.gap) {
                            Text("\(demo.number)")
                                .font(AnycastFont.mono(13))
                                .foregroundStyle(AnycastColor.gold)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(demo.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AnycastColor.sand12)
                                Text(demo.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnycastColor.sand9)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ch. 1 Animation Basics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 1 — Animation Basics") {
    NavigationStack { Chapter01_AnimationBasics() }
}
