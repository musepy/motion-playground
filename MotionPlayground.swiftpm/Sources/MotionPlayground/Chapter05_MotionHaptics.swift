// Chapter05_MotionHaptics.swift — CoreMotion 视差 + 触觉反馈交互示例
// 注意：Simulator 没有真实运动数据，也不出震动；
//       本章 tilt parallax 用两个 Slider 模拟 roll/pitch；
//       触觉示例代码完整可编译，需要在真机上才能感受到震动。
import SwiftUI
import CoreHaptics

// MARK: - 5.1 Tilt Parallax（用 Slider 模拟 roll/pitch）

/// 真机版本绑 CMMotionManager.deviceMotion；这里用两个 Slider（0...1）作为 roll/pitch 输入，
/// 配合 rotation3DEffect + offset 演示视差卡片的视觉变换。
struct TiltParallaxExample: View {
    @State private var roll: Double = 0.5    // 0=左, 0.5=中, 1=右
    @State private var pitch: Double = 0.5   // 0=上仰, 0.5=平, 1=俯视

    /// 把 0...1 归一化到 -1...1，方便后续乘以幅度
    private var rollNormalized: Double { (roll - 0.5) * 2 }
    private var pitchNormalized: Double { (pitch - 0.5) * 2 }

    var body: some View {
        PlaygroundFrame("5.1 TILT PARALLAX (Sim 模拟)") {
            ZStack {
                // 背景层：偏移幅度小
                RoundedRectangle(cornerRadius: AnycastRadius.card)
                    .fill(AnycastColor.sand4.opacity(0.5))
                    .frame(width: 220, height: 280)
                    .offset(x: rollNormalized * 12, y: pitchNormalized * 12)

                // 中间层：黄金高光
                RoundedRectangle(cornerRadius: AnycastRadius.card)
                    .fill(LinearGradient(
                        colors: [AnycastColor.goldAlpha60, AnycastColor.orangeAlpha60],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 200, height: 260)
                    .offset(x: rollNormalized * 24, y: pitchNormalized * 24)

                // 前景文字层：偏移幅度最大 + 3D 旋转
                VStack(spacing: 8) {
                    Text("TILT")
                        .font(AnycastFont.display(56))
                        .foregroundStyle(AnycastColor.sand1)
                    Text("ME")
                        .font(AnycastFont.display(56))
                        .foregroundStyle(AnycastColor.sand1)
                }
                .offset(x: rollNormalized * 40, y: pitchNormalized * 40)
            }
            .rotation3DEffect(
                .degrees(pitchNormalized * 14),  // pitch 控制 X 轴
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.6
            )
            .rotation3DEffect(
                .degrees(-rollNormalized * 14), // roll 控制 Y 轴（取反更符合直觉）
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.6
            )
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.75),
                       value: roll)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.75),
                       value: pitch)
        } controls: {
            VStack(alignment: .leading, spacing: 8) {
                LabeledSlider(label: "Roll  (左 ←→ 右)", value: $roll)
                LabeledSlider(label: "Pitch (上 ←→ 下)", value: $pitch)
                Text("真机：把这两个值绑到 CMMotionManager.deviceMotion.attitude.roll/.pitch")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("5.1 TiltParallax") { TiltParallaxExample() }


// MARK: - 5.2 Slider 拖过 1/30 间隔的 .selection 触觉

/// 模拟播放器 scrubber：每次跨过 1/30 的进度桶（约 3.33% 一档）就触发一次 .selection 触觉。
/// 真机能感受到细密的"咔咔"反馈；Simulator 仅做 trigger 调用，不出声。
struct SelectionScrubExample: View {
    @State private var progress: Double = 0
    @State private var ticks: Int = 0   // 用来在 UI 上显示触觉次数

    var body: some View {
        PlaygroundFrame("5.2 .selection (跨档触发)") {
            VStack(spacing: 24) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AnycastColor.sand4.opacity(0.4))
                        .frame(height: 8)
                    Capsule()
                        .fill(AnycastColor.gold)
                        .frame(width: max(8, CGFloat(progress) * 240), height: 8)
                    Circle()
                        .fill(AnycastColor.sand1)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(AnycastColor.gold, lineWidth: 2))
                        .offset(x: CGFloat(progress) * 240 - 11)
                        .shadow(color: AnycastColor.sand12.opacity(0.15), radius: 4, y: 2)
                }
                .frame(width: 240)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            progress = min(max(0, Double(v.location.x / 240)), 1)
                        }
                )

                Text("triggered: \(ticks) times")
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand9)
            }
            // iOS 17+ — old/new 闭包做 bucket 节流
            .sensoryFeedback(trigger: progress) { old, new in
                let oldBucket = Int(old * 30)
                let newBucket = Int(new * 30)
                if oldBucket != newBucket {
                    Task { @MainActor in ticks += 1 }
                    return .selection
                }
                return nil
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("拖动滑块；每跨 1/30 进度档触发一次 .selection")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Button("Reset") {
                    progress = 0
                    ticks = 0
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnycastColor.gold)
            }
        }
    }
}

#Preview("5.2 SelectionScrub") { SelectionScrubExample() }


// MARK: - 5.3 .alignment 在 0/0.5/1.0 对齐位置触发

/// 拖过 0/0.5/1.0 三个 snap 点时给一次 .alignment 触觉，模仿 Final Cut 时间线对齐感。
struct AlignmentSnapExample: View {
    @State private var x: Double = 0.25
    @State private var lastSnap: Double = -1   // 防抖：同一档不重复 fire

    private let snaps: [Double] = [0.0, 0.5, 1.0]
    private let snapTolerance: Double = 0.015

    private func snapped(_ v: Double) -> Double? {
        snaps.first { abs($0 - v) < snapTolerance }
    }

    var body: some View {
        PlaygroundFrame("5.3 .alignment (snap 点)") {
            VStack(spacing: 20) {
                ZStack(alignment: .leading) {
                    // 轨道 + snap 标记
                    Capsule()
                        .fill(AnycastColor.sand4.opacity(0.35))
                        .frame(height: 6)
                    HStack(spacing: 0) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(AnycastColor.sand9.opacity(0.5))
                                .frame(width: 8, height: 8)
                            if i < 2 { Spacer() }
                        }
                    }
                    .frame(width: 240)

                    // 拇指
                    Circle()
                        .fill(snapped(x) != nil ? AnycastColor.orange : AnycastColor.sand1)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(AnycastColor.gold, lineWidth: 2))
                        .offset(x: CGFloat(x) * 240 - 13)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7),
                                   value: snapped(x) != nil)
                }
                .frame(width: 240)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            x = min(max(0, Double(v.location.x / 240)), 1)
                        }
                )

                Text(snapped(x).map { String(format: "snapped at %.1f", $0) }
                     ?? String(format: "x = %.3f", x))
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand9)
            }
            .sensoryFeedback(.alignment, trigger: x) { _, new in
                guard let snap = snaps.first(where: { abs($0 - new) < snapTolerance }) else {
                    Task { @MainActor in lastSnap = -1 }
                    return false
                }
                if snap != lastSnap {
                    Task { @MainActor in lastSnap = snap }
                    return true
                }
                return false
            }
        } controls: {
            Text("snap 点：0 / 0.5 / 1.0；进入容差区给 .alignment 触觉，离开后才能再次触发。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("5.3 AlignmentSnap") { AlignmentSnapExample() }


// MARK: - 5.4 .impact / .success / .warning / .error 选择器演示

/// 把 5 种语义 + 冲击合并到一个 Picker；按按钮触发，trigger 用 nonce 强制每次都 fire。
enum HapticDemo: String, CaseIterable, Identifiable {
    case impactLight = "impact.light"
    case impactMedium = "impact.medium"
    case impactHeavy = "impact.heavy"
    case success = "success"
    case warning = "warning"
    case error = "error"

    var id: String { rawValue }

    /// 返回 trigger view modifier 时用的 SensoryFeedback
    var feedback: SensoryFeedback {
        switch self {
        case .impactLight:  return .impact(weight: .light, intensity: 0.7)
        case .impactMedium: return .impact(weight: .medium, intensity: 0.8)
        case .impactHeavy:  return .impact(weight: .heavy, intensity: 1.0)
        case .success:      return .success
        case .warning:      return .warning
        case .error:        return .error
        }
    }

    var symbol: String {
        switch self {
        case .impactLight:  return "circle.dotted"
        case .impactMedium: return "circle.lefthalf.filled"
        case .impactHeavy:  return "circle.fill"
        case .success:      return "checkmark.circle.fill"
        case .warning:      return "exclamationmark.triangle.fill"
        case .error:        return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .impactLight, .impactMedium, .impactHeavy: return AnycastColor.gold
        case .success:                                  return .green
        case .warning:                                  return AnycastColor.orange
        case .error:                                    return .red
        }
    }
}

struct HapticPickerExample: View {
    @State private var selected: HapticDemo = .impactMedium
    @State private var fireNonce: Int = 0    // 用 nonce 让相同 case 也能反复触发

    var body: some View {
        PlaygroundFrame("5.4 Impact / Notification 选择器") {
            VStack(spacing: 18) {
                Image(systemName: selected.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(selected.tint)
                    .symbolEffect(.bounce, value: fireNonce)
                    .frame(height: 80)

                Picker("Haptic", selection: $selected) {
                    ForEach(HapticDemo.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(AnycastColor.gold)

                Button {
                    fireNonce &+= 1
                } label: {
                    Text("Fire haptic")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand1)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(selected.tint, in: Capsule())
                }
            }
            // 选中变化时也震一下（用户切 case 即给反馈）
            .sensoryFeedback(.selection, trigger: selected)
            // 按按钮触发：trigger 是 nonce，每次 +1 都触发对应 case
            .sensoryFeedback(selected.feedback, trigger: fireNonce)
        } controls: {
            Text("点 Fire 触发当前 case；切 Picker 同时给 .selection 反馈。Simulator 只看到 symbol bounce，真机才能感受震动。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("5.4 HapticPicker") { HapticPickerExample() }


// MARK: - 5.5 CoreHaptics 充电式 ramp Pattern

/// 单例 engine 复用，prepare 在 view onAppear 调用。
/// playChargeUp() 播放一个 1.2s 的 continuous 事件 + 末尾一记 transient click，
/// intensity 从 0.2 升到 1.0，sharpness 从 0.1 升到 0.9 —— 典型"蓄力满溢"触感。
@MainActor
final class HapticsEngineHolder: ObservableObject {
    static let shared = HapticsEngineHolder()

    private(set) var engine: CHHapticEngine?
    let supportsHaptics: Bool

    private init() {
        self.supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func prepare() {
        guard supportsHaptics, engine == nil else { return }
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            e.stoppedHandler = { reason in
                // 仅日志；下次 play 时会按需重启
                print("[Haptics] engine stopped, reason:", reason.rawValue)
            }
            try e.start()
            engine = e
        } catch {
            print("[Haptics] init error:", error)
        }
    }

    func play(_ pattern: CHHapticPattern) {
        guard let engine else { return }
        do {
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[Haptics] play error:", error)
        }
    }
}

/// 构造一个充电式 ramp pattern：duration 内 intensity / sharpness 都从低升到高，
/// 末尾叠一记 transient 大震当作"装弹完成"的 click。
func makeChargeUpPattern(duration: TimeInterval = 1.2) throws -> CHHapticPattern {
    let intensityCurve = CHHapticParameterCurve(
        parameterID: .hapticIntensityControl,
        controlPoints: [
            .init(relativeTime: 0,                value: 0.2),
            .init(relativeTime: duration * 0.5,   value: 0.6),
            .init(relativeTime: duration,         value: 1.0)
        ],
        relativeTime: 0
    )
    let sharpnessCurve = CHHapticParameterCurve(
        parameterID: .hapticSharpnessControl,
        controlPoints: [
            .init(relativeTime: 0,        value: 0.1),
            .init(relativeTime: duration, value: 0.9)
        ],
        relativeTime: 0
    )
    let continuous = CHHapticEvent(
        eventType: .hapticContinuous,
        parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        ],
        relativeTime: 0,
        duration: duration
    )
    let click = CHHapticEvent(
        eventType: .hapticTransient,
        parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        ],
        relativeTime: duration
    )
    return try CHHapticPattern(
        events: [continuous, click],
        parameterCurves: [intensityCurve, sharpnessCurve]
    )
}

struct ChargeUpHapticExample: View {
    @StateObject private var holder = HapticsEngineHolder.shared
    @State private var charging = false
    @State private var rampProgress: Double = 0

    private func playPattern() {
        do {
            let pattern = try makeChargeUpPattern(duration: 1.2)
            holder.play(pattern)
        } catch {
            print("[Haptics] pattern build error:", error)
        }
    }

    var body: some View {
        PlaygroundFrame("5.5 CoreHaptics 充电 ramp") {
            VStack(spacing: 22) {
                // 视觉指示：跟着 1.2s ramp 一起亮起来
                ZStack {
                    Circle()
                        .stroke(AnycastColor.sand4.opacity(0.4), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: rampProgress)
                        .stroke(
                            AngularGradient(
                                colors: [AnycastColor.goldAlpha40,
                                         AnycastColor.gold,
                                         AnycastColor.orange],
                                center: .center
                            ),
                            style: .init(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                    Image(systemName: charging ? "bolt.fill" : "bolt")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(charging ? AnycastColor.orange : AnycastColor.gold)
                        .symbolEffect(.bounce, value: rampProgress >= 1)
                }

                Button {
                    guard !charging else { return }
                    charging = true
                    rampProgress = 0
                    playPattern()
                    withAnimation(.easeIn(duration: 1.2)) {
                        rampProgress = 1
                    }
                    // 1.2s 后复位
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        charging = false
                        withAnimation(.easeOut(duration: 0.3)) {
                            rampProgress = 0
                        }
                    }
                } label: {
                    Text(charging ? "Charging…" : "Charge")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AnycastColor.sand1)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(charging ? AnycastColor.orange : AnycastColor.gold,
                                    in: Capsule())
                }
                .disabled(charging)
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text(holder.supportsHaptics
                     ? "CHHapticEngine ready · 真机才能感受到 1.2s 充电震动"
                     : "本设备 (Sim 或 iPad) 不支持 CoreHaptics — pattern 不会播放")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("intensity 0.2 → 1.0；sharpness 0.1 → 0.9；末尾一记 transient click。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
            }
        }
        .onAppear { holder.prepare() }
    }
}

#Preview("5.5 ChargeUpHaptic") { ChargeUpHapticExample() }


// MARK: - 5.6 综合：tilt 视差 + .alignment 边缘触觉

/// 把 5.1 的视差和 5.3 的 .alignment 结合：当 roll/pitch 任一接近 0/±1 边界时给一次 .alignment 反馈。
/// 真机上能模拟"撞到墙"的物理对齐感。
struct ParallaxWithEdgeHapticExample: View {
    @State private var roll: Double = 0.5
    @State private var pitch: Double = 0.5
    @State private var atEdge: Bool = false

    private var rollNorm: Double { (roll - 0.5) * 2 }
    private var pitchNorm: Double { (pitch - 0.5) * 2 }

    /// 接近 ±1（容差 0.04）即认为撞到边
    private func nearEdge(_ a: Double, _ b: Double) -> Bool {
        abs(a) > 0.96 || abs(b) > 0.96
    }

    var body: some View {
        PlaygroundFrame("5.6 视差 + 边缘 .alignment") {
            ZStack {
                RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                    .fill(LinearGradient(
                        colors: [AnycastColor.sand4, AnycastColor.gold],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 220, height: 220)
                    .shadow(color: AnycastColor.sand12.opacity(0.25), radius: 16, y: 8)

                Image(systemName: "headphones")
                    .font(.system(size: 88, weight: .semibold))
                    .foregroundStyle(AnycastColor.sand1)
                    .offset(x: rollNorm * 30, y: pitchNorm * 30)

                // 边缘红圈：撞墙提示
                RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                    .stroke(AnycastColor.orange, lineWidth: atEdge ? 3 : 0)
                    .frame(width: 220, height: 220)
                    .opacity(atEdge ? 1 : 0)
                    .animation(.easeOut(duration: 0.2), value: atEdge)
            }
            .rotation3DEffect(.degrees(pitchNorm * 18),
                              axis: (1, 0, 0), perspective: 0.6)
            .rotation3DEffect(.degrees(-rollNorm * 18),
                              axis: (0, 1, 0), perspective: 0.6)
            .onChange(of: roll) { _, _ in atEdge = nearEdge(rollNorm, pitchNorm) }
            .onChange(of: pitch) { _, _ in atEdge = nearEdge(rollNorm, pitchNorm) }
            // 任一坐标越界给 .alignment；老/新都越界时不会重复触发
            .sensoryFeedback(.alignment, trigger: atEdge) { old, new in
                old == false && new == true
            }
        } controls: {
            VStack(alignment: .leading, spacing: 8) {
                LabeledSlider(label: "Roll  (左 ←→ 右)", value: $roll)
                LabeledSlider(label: "Pitch (上 ←→ 下)", value: $pitch)
                Text("拖到滑块两端会触发一次 .alignment（红圈高亮）；真机才有震动。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("5.6 ParallaxWithEdgeHaptic") { ParallaxWithEdgeHapticExample() }


// MARK: - 共享小组件

/// 标准带 label 的 0...1 Slider，让控制区视觉一致。
private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnycastColor.sand12)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)
            }
            Slider(value: $value, in: 0...1)
                .tint(AnycastColor.gold)
        }
    }
}


// MARK: - 章节根 View

struct Chapter05_MotionHaptics: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AnycastSpacing.sectionGap) {
                Header()
                TiltParallaxExample()
                SelectionScrubExample()
                AlignmentSnapExample()
                HapticPickerExample()
                ChargeUpHapticExample()
                ParallaxWithEdgeHapticExample()
            }
            .padding(.vertical, AnycastSpacing.pageHeader)
        }
        .background(AnycastColor.sand1.ignoresSafeArea())
        .navigationTitle("CoreMotion + Haptics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Header: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHAPTER 05")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnycastColor.gold)
                .tracking(1.2)
            Text("CoreMotion + Haptics")
                .font(AnycastFont.display(28))
                .foregroundStyle(AnycastColor.sand12)
            Text("Simulator 没有真实运动数据、也不出震动。视差用 Slider 模拟、触觉示例只能在真机感受。")
                .font(.system(size: 13))
                .foregroundStyle(AnycastColor.sand9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnycastSpacing.pageH)
    }
}

#Preview("Chapter 5 Root") {
    NavigationStack { Chapter05_MotionHaptics() }
}
