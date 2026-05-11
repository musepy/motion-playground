// Chapter09_SymbolEffects.swift — 第 9 章：SF Symbol Effects + Content Transitions
// 来自 research/swiftui-motion/topics/09-symbol-content-transitions.md 的可运行示例。
// 每个示例独立 struct，配 #Preview；末尾 Chapter09_SymbolEffects 是入口列表。
// iOS 17+ 默认可用；iOS 18+ 的 .breathe / .wiggle / .rotate 用 #available 分支。
import SwiftUI

// MARK: - 示例 1：SymbolEffect Picker —— 切 effect 类型直观对比
/// 用 Picker 切换不同 effect，indefinite (pulse / variableColor / breathe) 走 isActive；
/// discrete (bounce / wiggle / rotate / scale.up) 走 value: trigger 计数。
struct SymbolEffectPickerDemo: View {
    enum Effect: String, CaseIterable, Identifiable {
        case bounce, pulse, variableColor, breathe, wiggle, rotate, scaleUp
        var id: String { rawValue }
        var label: String {
            switch self {
            case .bounce:        return ".bounce"
            case .pulse:         return ".pulse"
            case .variableColor: return ".variableColor.iterative"
            case .breathe:       return ".breathe (iOS 18)"
            case .wiggle:        return ".wiggle (iOS 18)"
            case .rotate:        return ".rotate (iOS 18)"
            case .scaleUp:       return ".scale.up"
            }
        }
        /// indefinite = 用 isActive 长开/长关；discrete = 用 value: trigger 一次
        var isIndefinite: Bool {
            switch self {
            case .pulse, .variableColor, .breathe, .scaleUp: return true
            case .bounce, .wiggle, .rotate:                  return false
            }
        }
    }

    @State private var effect: Effect = .bounce
    @State private var trigger: Int = 0       // discrete effects 用
    @State private var isActive: Bool = false // indefinite effects 用

    var body: some View {
        PlaygroundFrame("SymbolEffect Picker") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                Image(systemName: "wifi")
                    .font(.system(size: 64, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AnycastColor.gold)
                    .modifier(SymbolEffectModifier(effect: effect,
                                                   trigger: trigger,
                                                   isActive: isActive))

                Button {
                    if effect.isIndefinite {
                        isActive.toggle()
                    } else {
                        trigger &+= 1
                    }
                } label: {
                    Text(effect.isIndefinite
                         ? (isActive ? "停止" : "启动")
                         : "触发一次")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AnycastColor.orange, in: Capsule())
                    .foregroundStyle(.white)
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Picker("Effect", selection: $effect) {
                    ForEach(Effect.allCases) { e in
                        Text(e.rawValue).tag(e)
                    }
                }
                .pickerStyle(.menu)
                .tint(AnycastColor.gold)

                Text(effect.label)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)

                Text(effect.isIndefinite
                     ? "Indefinite —— 用 isActive 控制开/关"
                     : "Discrete —— 每次按按钮 value 变化触发一次")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
        .onChange(of: effect) { _, _ in
            // 切 effect 时复位，避免上一个 indefinite 一直跑
            isActive = false
            trigger = 0
        }
    }
}

/// 用 ViewModifier 把不同 effect 分支收敛到一处，避免 if/else 多个 Image 节点。
private struct SymbolEffectModifier: ViewModifier {
    let effect: SymbolEffectPickerDemo.Effect
    let trigger: Int
    let isActive: Bool

    func body(content: Content) -> some View {
        switch effect {
        case .bounce:
            content.symbolEffect(.bounce, value: trigger)
        case .pulse:
            content.symbolEffect(.pulse, options: .repeating, isActive: isActive)
        case .variableColor:
            content.symbolEffect(.variableColor.iterative,
                                 options: .repeating,
                                 isActive: isActive)
        case .scaleUp:
            content.symbolEffect(.scale.up, isActive: isActive)
        case .breathe:
            if #available(iOS 18.0, *) {
                content.symbolEffect(.breathe, options: .repeat(.continuous), isActive: isActive)
            } else {
                content.symbolEffect(.pulse, options: .repeating, isActive: isActive)
            }
        case .wiggle:
            if #available(iOS 18.0, *) {
                content.symbolEffect(.wiggle, value: trigger)
            } else {
                content.symbolEffect(.bounce, value: trigger)
            }
        case .rotate:
            if #available(iOS 18.0, *) {
                content.symbolEffect(.rotate, value: trigger)
            } else {
                content.symbolEffect(.bounce, value: trigger)
            }
        }
    }
}

#Preview("1. SymbolEffect Picker") { SymbolEffectPickerDemo() }


// MARK: - 示例 2：play / pause —— contentTransition(.symbolEffect(.replace.downUp))
/// 关键：必须在同一个 Image 节点切换 systemName，并用 withAnimation 包变更。
struct PlayPauseTransitionDemo: View {
    @State private var isPlaying = false

    var body: some View {
        PlaygroundFrame("Play / Pause 切换") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                Button {
                    withAnimation(.snappy) { isPlaying.toggle() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(AnycastColor.sand12)
                            .frame(width: 96, height: 96)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(AnycastColor.sand1)
                            .contentTransition(.symbolEffect(.replace.downUp))
                            // 修正 play 视觉重心，pause 居中
                            .offset(x: isPlaying ? 0 : 3)
                    }
                }
                .buttonStyle(.plain)

                Text(isPlaying ? "Playing" : "Paused")
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand9)
            }
        } controls: {
            Text(".contentTransition(.symbolEffect(.replace.downUp)) —— 旧的下去、新的上来。必须 withAnimation 包 toggle 才会动。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("2. Play / Pause Replace") { PlayPauseTransitionDemo() }


// MARK: - 示例 3：心形点赞 bounce + fill 切换
/// 点击：bounce (discrete, value: trigger) + replace (contentTransition)
/// 注意：`.symbolVariant(.fill)` 不会触发 contentTransition，所以写两个 systemName 字符串。
struct LikeHeartDemo: View {
    @State private var liked = false

    var body: some View {
        PlaygroundFrame("心形点赞 Bounce + Fill") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                Button {
                    withAnimation(.bouncy) { liked.toggle() }
                } label: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(liked ? AnycastColor.orange : AnycastColor.sand9)
                        .symbolEffect(.bounce.up.byLayer, value: liked)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(height: 70)
                }
                .buttonStyle(.plain)

                Text(liked ? "已收藏" : "点击收藏")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnycastColor.sand9)
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("两层 effect 叠加，SwiftUI 自动合并：")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text(".symbolEffect(.bounce.up.byLayer, value: liked)")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
                Text(".contentTransition(.symbolEffect(.replace))")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
            }
        }
    }
}

#Preview("3. Like Heart") { LikeHeartDemo() }


// MARK: - 示例 4：未读 badge 数字滚动 —— numericText + monospacedDigit
struct UnreadBadgeNumericDemo: View {
    @State private var count: Int = 7

    var body: some View {
        PlaygroundFrame("未读 Badge 数字滚动") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 56, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AnycastColor.sand12)
                        .frame(width: 120, height: 80)

                    Text("\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AnycastColor.orange, in: Capsule())
                        .contentTransition(.numericText(value: Double(count)))
                        .animation(.snappy(duration: 0.35), value: count)
                        .offset(x: 8, y: -6)
                }

                // 大号数字也演示一次
                Text("\(count)")
                    .font(AnycastFont.display(56))
                    .monospacedDigit()
                    .foregroundStyle(AnycastColor.sand12)
                    .contentTransition(.numericText(value: Double(count)))
                    .animation(.snappy, value: count)
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Stepper(value: $count, in: 0...999) {
                    HStack {
                        Text("count")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand12)
                        Spacer()
                        Text("\(count)")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                }
                Text(".contentTransition(.numericText(value:)) + .monospacedDigit() —— 上下卷动，宽度恒定。value: 让方向判断对：增大向上滚、减小向下滚。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("4. Unread Badge Numeric") { UnreadBadgeNumericDemo() }


// MARK: - 示例 5：加载循环 variableColor.iterative.reversing —— Toggle 控制 isActive
struct LoadingVariableColorDemo: View {
    @State private var isLoading = false

    var body: some View {
        PlaygroundFrame("Loading variableColor.iterative.reversing") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                // 下载循环
                VStack(spacing: AnycastSpacing.gap) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AnycastColor.gold)
                        .symbolEffect(.variableColor.iterative.reversing,
                                      options: .repeating.speed(0.9),
                                      isActive: isLoading)
                    Text("download")
                        .font(AnycastFont.mono(10))
                        .foregroundStyle(AnycastColor.sand9)
                }

                // WiFi 信号强度循环
                VStack(spacing: AnycastSpacing.gap) {
                    Image(systemName: "wifi")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AnycastColor.orange)
                        .symbolEffect(.variableColor.cumulative,
                                      options: .repeating,
                                      isActive: isLoading)
                    Text("scanning")
                        .font(AnycastFont.mono(10))
                        .foregroundStyle(AnycastColor.sand9)
                }

                // 单点麦克风 pulse —— 同一 isActive 控两组动画
                VStack(spacing: AnycastSpacing.gap) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AnycastColor.sand12)
                        .symbolEffect(.pulse,
                                      options: .repeating,
                                      isActive: isLoading)
                    Text("listening")
                        .font(AnycastFont.mono(10))
                        .foregroundStyle(AnycastColor.sand9)
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $isLoading.animation(.snappy)) {
                    Text("isActive: \(isLoading ? "true" : "false")")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                }
                .tint(AnycastColor.gold)

                Text("Indefinite effect 用 isActive 控制 —— 切 false 不是立刻停，是动画走完当前周期再停。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("5. Loading variableColor") { LoadingVariableColorDemo() }


// MARK: - 示例 6：iOS 18 .breathe / .wiggle —— 兜底回退到 .pulse / .bounce
struct BreatheWiggleDemo: View {
    @State private var breathing = false
    @State private var wiggleTrigger = 0

    var body: some View {
        PlaygroundFrame("iOS 18 Breathe + Wiggle") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                // Breathe —— 比 pulse 更柔和的呼吸
                VStack(spacing: AnycastSpacing.gap) {
                    Group {
                        if #available(iOS 18.0, *) {
                            Image(systemName: "icloud.and.arrow.down")
                                .symbolEffect(.breathe,
                                              options: .repeat(.continuous),
                                              isActive: breathing)
                        } else {
                            Image(systemName: "icloud.and.arrow.down")
                                .symbolEffect(.pulse,
                                              options: .repeating,
                                              isActive: breathing)
                        }
                    }
                    .font(.system(size: 56))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AnycastColor.gold)

                    Toggle(isOn: $breathing) {
                        Text("breathe")
                            .font(AnycastFont.mono(10))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(AnycastColor.gold)
                }

                // Wiggle —— 通知图标提醒
                VStack(spacing: AnycastSpacing.gap) {
                    Group {
                        if #available(iOS 18.0, *) {
                            Image(systemName: "bell.fill")
                                .symbolEffect(.wiggle, value: wiggleTrigger)
                        } else {
                            Image(systemName: "bell.fill")
                                .symbolEffect(.bounce, value: wiggleTrigger)
                        }
                    }
                    .font(.system(size: 56))
                    .foregroundStyle(AnycastColor.orange)

                    Button("Wiggle") {
                        wiggleTrigger &+= 1
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AnycastColor.orange)
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                if #available(iOS 18.0, *) {
                    Text("当前 iOS 18+ —— 跑真正的 .breathe / .wiggle")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.gold)
                } else {
                    Text("iOS 17 fallback —— 用 .pulse / .bounce 顶上")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                }
                Text(".breathe 是 indefinite (用 isActive)，.wiggle 是 discrete (用 value:)。两个 API 形态不一样。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("6. Breathe + Wiggle (iOS 18)") { BreatheWiggleDemo() }


// MARK: - 示例 7：综合面板 —— 收藏星 + 通知铃 + 静音切换 (Magic Replace)
/// 把 .symbolVariant 切 fill、.contentTransition(.replace)、.replace.magic 一起演示。
struct StatusIconBundleDemo: View {
    @State private var saved = false
    @State private var notify = true
    @State private var muted = false

    var body: some View {
        PlaygroundFrame("综合：星 / 铃 / 静音") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                // 收藏 —— 双 systemName 字符串而不是 symbolVariant
                Button {
                    withAnimation(.bouncy) { saved.toggle() }
                } label: {
                    Image(systemName: saved ? "star.fill" : "star")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(saved ? AnycastColor.gold : AnycastColor.sand9)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: saved)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)

                // 通知铃 —— palette + bounce
                Button {
                    withAnimation(.snappy) { notify.toggle() }
                } label: {
                    Image(systemName: notify ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            notify ? AnycastColor.orange : AnycastColor.sand9,
                            AnycastColor.sand4
                        )
                        .contentTransition(.symbolEffect(.replace.downUp))
                        .symbolEffect(.bounce, value: notify)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)

                // Magic Replace（iOS 18） —— speaker 共享 strokes 时形变
                Button {
                    withAnimation(.snappy) { muted.toggle() }
                } label: {
                    Group {
                        if #available(iOS 18.0, *) {
                            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                        } else {
                            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                                .contentTransition(.symbolEffect(.replace.downUp))
                        }
                    }
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(muted ? AnycastColor.sand9 : AnycastColor.sand12)
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("点 3 个图标看不同 replace 风格：")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("• star：.replace 默认 + .bounce")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
                Text("• bell：.replace.downUp + palette 双色")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
                Text("• speaker：iOS 18 .replace.magic —— 共享 strokes 时直接 path morph")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
            }
        }
    }
}

#Preview("7. Status Icon Bundle") { StatusIconBundleDemo() }


// MARK: - Chapter root —— 章节入口列表
struct Chapter09_SymbolEffects: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "SymbolEffect Picker",
                 subtitle: "Picker 切 .bounce / .pulse / .variableColor / .breathe / .wiggle / .rotate / .scale.up",
                 view: AnyView(SymbolEffectPickerDemo())),
            Demo(number: 2, title: "Play / Pause Replace",
                 subtitle: ".contentTransition(.symbolEffect(.replace.downUp)) + withAnimation",
                 view: AnyView(PlayPauseTransitionDemo())),
            Demo(number: 3, title: "Like Heart",
                 subtitle: "心形 .bounce.up.byLayer + .replace fill 切换",
                 view: AnyView(LikeHeartDemo())),
            Demo(number: 4, title: "Unread Badge Numeric",
                 subtitle: "Stepper +/- → .contentTransition(.numericText(value:)) + monospacedDigit",
                 view: AnyView(UnreadBadgeNumericDemo())),
            Demo(number: 5, title: "Loading variableColor",
                 subtitle: ".variableColor.iterative.reversing 循环，Toggle 控 isActive",
                 view: AnyView(LoadingVariableColorDemo())),
            Demo(number: 6, title: "Breathe + Wiggle (iOS 18)",
                 subtitle: "iOS 18+ 真效果，iOS 17 自动 fallback 到 .pulse / .bounce",
                 view: AnyView(BreatheWiggleDemo())),
            Demo(number: 7, title: "Status Icon Bundle",
                 subtitle: "星 / 铃 / 静音 —— 三种 replace 风格 + Magic Replace",
                 view: AnyView(StatusIconBundleDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 9 章 · Symbol & Content Transitions") {
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
        .navigationTitle("Ch. 9 Symbol Effects")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 9 — Symbol & Content Transitions") {
    NavigationStack { Chapter09_SymbolEffects() }
}
