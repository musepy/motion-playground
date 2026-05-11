// Chapter03_Transitions.swift — Transitions / matchedGeometryEffect / ContentTransition
// 8 个可运行示例 + 一个 root List。所有示例独立 #Preview，可在 Xcode Canvas 单独跑。
// 参考：research/swiftui-motion/topics/03-transitions-matched-geometry.md
import SwiftUI

// MARK: - Demo Models (chapter 内独占，避免和别章冲突)

private struct DemoEpisode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let host: String
    let color: Color
}

private extension Array where Element == DemoEpisode {
    static let demoSamples: [DemoEpisode] = [
        .init(title: "Spring Basics",     host: "Anna",   color: AnycastColor.gold),
        .init(title: "Phase Animator",    host: "Bryan",  color: AnycastColor.orange),
        .init(title: "Matched Geometry",  host: "Cara",   color: AnycastColor.sand4),
        .init(title: "Symbol Effects",    host: "Devon",  color: AnycastColor.sand9)
    ]
}

// MARK: - Example 1 · Transition Picker（必须）
// 用 Picker 切换 6 种内建 transition，按钮 toggle 显示/隐藏，直观对比

private enum TransitionKind: String, CaseIterable, Identifiable {
    case opacity, slide, scale, moveTop, pushTrailing, blurReplace
    var id: String { rawValue }
    var label: String {
        switch self {
        case .opacity:      return ".opacity"
        case .slide:        return ".slide"
        case .scale:        return ".scale"
        case .moveTop:      return ".move(.top)"
        case .pushTrailing: return ".push(.trailing)"
        case .blurReplace:  return ".blurReplace"
        }
    }
    var transition: AnyTransition {
        switch self {
        case .opacity:      return .opacity
        case .slide:        return .slide
        case .scale:        return .scale
        case .moveTop:      return .move(edge: .top).combined(with: .opacity)
        case .pushTrailing: return AnyTransition(.push(from: .trailing))
        case .blurReplace:  return AnyTransition(.blurReplace)
        }
    }
}

struct TransitionPickerExample: View {
    @State private var kind: TransitionKind = .opacity
    @State private var visible = true

    var body: some View {
        PlaygroundFrame("Transition Picker") {
            VStack(spacing: AnycastSpacing.gap) {
                Spacer(minLength: 0)
                ZStack {
                    if visible {
                        RoundedRectangle(cornerRadius: AnycastRadius.card)
                            .fill(AnycastColor.gold)
                            .frame(width: 180, height: 110)
                            .overlay(
                                Text(kind.label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(AnycastColor.sand1)
                            )
                            .transition(kind.transition)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 130)
                .clipped()
                Spacer(minLength: 0)
            }
        } controls: {
            Picker("Transition", selection: $kind) {
                ForEach(TransitionKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)

            Button(visible ? "Hide" : "Show") {
                withAnimation(.snappy(duration: 0.45)) { visible.toggle() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnycastColor.gold)

            Text("切换 transition 后再点 Hide/Show 对比效果")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Transition Picker") { TransitionPickerExample() }

// MARK: - Example 2 · Asymmetric + Custom AnyTransition
// .asymmetric(insertion:removal:) + AnyTransition.modifier(active:identity:) 自定义 ScaleBlur

private struct ScaleBlurModifier: ViewModifier {
    let amount: Double
    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - amount * 0.25)
            .blur(radius: amount * 10)
            .opacity(1 - amount)
    }
}

private extension AnyTransition {
    static var scaleBlur: AnyTransition {
        .modifier(active: ScaleBlurModifier(amount: 1),
                  identity: ScaleBlurModifier(amount: 0))
    }
    static var dropIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.92, anchor: .top)),
            removal: .scaleBlur
        )
    }
}

struct AsymmetricCustomExample: View {
    @State private var show = false

    var body: some View {
        PlaygroundFrame("Asymmetric + Custom Modifier") {
            VStack(spacing: AnycastSpacing.gap) {
                Spacer(minLength: 0)
                if show {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AnycastColor.gold)
                        Text("Saved to Library")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AnycastColor.sand12)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .transition(.dropIn)
                }
                Spacer(minLength: 0)
            }
        } controls: {
            Button(show ? "Dismiss" : "Show banner") {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                    show.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnycastColor.gold)

            Text("insertion: top + opacity + scale；removal: scaleBlur")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Asymmetric Custom") { AsymmetricCustomExample() }

// MARK: - Example 3 · matchedGeometryEffect Hero（必须）
// ZStack + @Namespace，小卡片点击展开成详情卡

struct HeroMatchedGeometryExample: View {
    @Namespace private var ns
    @State private var openedID: UUID?

    private let items: [DemoEpisode] = .demoSamples

    var body: some View {
        PlaygroundFrame("matchedGeometryEffect Hero") {
            ZStack {
                // 列表态（grid）
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                        GridItem(.flexible(), spacing: 10)],
                              spacing: 10) {
                        ForEach(items) { ep in
                            if openedID != ep.id {
                                gridCell(ep)
                                    .matchedGeometryEffect(id: ep.id, in: ns)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                                            openedID = ep.id
                                        }
                                    }
                            } else {
                                Color.clear.frame(height: 80)
                            }
                        }
                    }
                    .padding(12)
                }
                .opacity(openedID == nil ? 1 : 0.25)

                // 详情态
                if let id = openedID, let ep = items.first(where: { $0.id == id }) {
                    detailCard(ep)
                        .matchedGeometryEffect(id: ep.id, in: ns)
                        .padding(14)
                        .zIndex(1)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                                openedID = nil
                            }
                        }
                }
            }
        } controls: {
            Text("点小卡片展开详情；再点详情收起")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
            Text("关键：ZStack + @Namespace + 同 id；列表 cell 让出位置用 Color.clear 占位")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    private func gridCell(_ ep: DemoEpisode) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                .fill(ep.color)
                .frame(height: 50)
            Text(ep.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AnycastColor.sand12)
                .lineLimit(1)
        }
        .padding(8)
        .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
    }

    private func detailCard(_ ep: DemoEpisode) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: AnycastRadius.card)
                .fill(ep.color)
                .frame(height: 130)
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(AnycastColor.sand1)
                )
            Text(ep.title)
                .font(AnycastFont.display(22))
                .foregroundStyle(AnycastColor.sand12)
            Text("Hosted by \(ep.host)")
                .font(.system(size: 13))
                .foregroundStyle(AnycastColor.sand9)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.card))
    }
}

#Preview("Hero matchedGeometry") { HeroMatchedGeometryExample() }

// MARK: - Example 4 · ContentTransition.numericText（必须）
// 数字滚动方向由 value 决定，Stepper 上加下减观察方向

struct NumericContentTransitionExample: View {
    @State private var price: Int = 19
    @State private var streak: Int = 7

    var body: some View {
        PlaygroundFrame("ContentTransition.numericText") {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("$")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(AnycastColor.sand9)
                    Text("\(price)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(value: Double(price)))
                        .animation(.snappy(duration: 0.35), value: price)
                        .foregroundStyle(AnycastColor.sand12)
                }

                HStack(spacing: 10) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AnycastColor.orange)
                    Text("\(streak) day streak")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .contentTransition(.numericText(value: Double(streak)))
                        .animation(.snappy, value: streak)
                        .foregroundStyle(AnycastColor.sand12)
                }
                Spacer(minLength: 0)
            }
        } controls: {
            Stepper("Price: \(price)", value: $price, in: 0...999, step: 1)
            Stepper("Streak: \(streak)", value: $streak, in: 0...365, step: 1)
            Text("加 → 数字向上滚；减 → 向下滚。SwiftUI 用 value 推断方向")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Numeric Text") { NumericContentTransitionExample() }

// MARK: - Example 5 · iOS 17 Transition 协议自定义（必须）
// BounceTransition + StretchTransition 用 phase 做多阶段

struct BounceTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.3)
            .opacity(phase.isIdentity ? 1 : 0)
            .rotationEffect(.degrees(phase == .willAppear ? -15 : (phase == .didDisappear ? 15 : 0)))
            .blur(radius: phase.isIdentity ? 0 : 6)
    }
}

struct StretchTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(
                x: phase.isIdentity ? 1 : 1.4,
                y: phase.isIdentity ? 1 : 0.3,
                anchor: .bottom
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

extension Transition where Self == BounceTransition {
    static var bounce: BounceTransition { BounceTransition() }
}

extension Transition where Self == StretchTransition {
    static var stretch: StretchTransition { StretchTransition() }
}

private enum CustomKind: String, CaseIterable, Identifiable {
    case bounce, stretch
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

struct CustomTransitionProtocolExample: View {
    @State private var kind: CustomKind = .bounce
    @State private var show = true

    var body: some View {
        PlaygroundFrame("Transition 协议自定义 (iOS 17+)") {
            VStack {
                Spacer(minLength: 0)
                ZStack {
                    if show {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 88))
                            .foregroundStyle(AnycastColor.gold)
                            .applyKind(kind)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                Spacer(minLength: 0)
            }
        } controls: {
            Picker("Kind", selection: $kind) {
                ForEach(CustomKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Button(show ? "Remove" : "Insert") {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                    show.toggle()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnycastColor.gold)

            Text("Bounce: scale + rotate + blur 三轴。Stretch: 橡皮筋纵向压扁")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

private extension View {
    @ViewBuilder
    func applyKind(_ kind: CustomKind) -> some View {
        switch kind {
        case .bounce:  self.transition(.bounce)
        case .stretch: self.transition(.stretch)
        }
    }
}

#Preview("Custom Transition Protocol") { CustomTransitionProtocolExample() }

// MARK: - Example 6 · Staggered ForEach Transition
// 多 row 同进同出，按 index 加 delay 错峰

struct StaggeredForEachExample: View {
    @State private var visible = false
    private let rows = ["Spring", "Phase", "Matched Geometry", "Symbol", "Liquid Glass", "Canvas"]

    var body: some View {
        PlaygroundFrame("Staggered ForEach") {
            VStack(alignment: .leading, spacing: 6) {
                if visible {
                    ForEach(Array(rows.enumerated()), id: \.element) { idx, item in
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(AnycastColor.gold)
                            Text(item)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AnycastColor.sand12)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.regularMaterial,
                                    in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(idx) * 0.06),
                            value: visible
                        )
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } controls: {
            Button(visible ? "Collapse" : "Expand") {
                withAnimation { visible.toggle() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnycastColor.gold)

            Text(".animation(...delay(idx*0.06), value: visible) — 经典 stagger")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Staggered Rows") { StaggeredForEachExample() }

// MARK: - Example 7 · Step Card with .push(from:) + ContentTransition.symbolEffect
// 步骤指示器：箭头从右推入；图标 .replace 平滑变形

struct StepCardPushExample: View {
    @State private var step = 0
    private let titles = ["Choose plan", "Add payment", "Confirm", "All set"]
    private let icons  = ["square.grid.2x2", "creditcard", "checkmark.circle", "sparkles"]

    var body: some View {
        PlaygroundFrame(".push(from:.trailing) + symbolEffect") {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                Image(systemName: icons[step])
                    .font(.system(size: 56))
                    .foregroundStyle(AnycastColor.gold)
                    .contentTransition(.symbolEffect(.replace))

                Group {
                    Text(titles[step])
                        .font(AnycastFont.display(22))
                        .foregroundStyle(AnycastColor.sand12)
                }
                .id("step-\(step)")
                .transition(.push(from: .trailing).combined(with: .opacity))
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    ForEach(titles.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? AnycastColor.gold : AnycastColor.sand4.opacity(0.5))
                            .frame(width: i == step ? 22 : 8, height: 6)
                            .animation(.snappy, value: step)
                    }
                }
            }
        } controls: {
            HStack {
                Button("Back") {
                    withAnimation(.snappy) {
                        step = max(0, step - 1)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(step == 0)

                Spacer()

                Button("Next") {
                    withAnimation(.snappy) {
                        step = min(titles.count - 1, step + 1)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AnycastColor.gold)
                .disabled(step == titles.count - 1)
            }

            Text(".id() 改变触发 transition；图标用 contentTransition 平滑变形")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Step Card Push") { StepCardPushExample() }

// MARK: - Example 8 · Transaction overlay (per-view animation override)
// 同一 toggle 触发，背景用 easeInOut，卡片用 spring；用 .transaction 局部覆盖

struct TransactionLayeredExample: View {
    @State private var on = false

    var body: some View {
        PlaygroundFrame("Transaction 局部覆盖动画") {
            ZStack {
                if on {
                    AnycastColor.sand12.opacity(0.45)
                        .transition(.opacity)
                        .transaction { $0.animation = .easeInOut(duration: 0.5) }

                    VStack(spacing: 8) {
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 36))
                            .foregroundStyle(AnycastColor.sand1)
                        Text("Now Playing")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AnycastColor.sand1)
                    }
                    .padding(28)
                    .background(AnycastColor.gold,
                                in: RoundedRectangle(cornerRadius: AnycastRadius.cardLarge))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .transaction { $0.animation = .spring(response: 0.45, dampingFraction: 0.72) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } controls: {
            Button(on ? "Hide overlay" : "Show overlay") {
                withAnimation { on.toggle() }
            }
            .buttonStyle(.borderedProminent)
            .tint(AnycastColor.gold)

            Text("背景 fade 0.5s，卡片 spring 同时跑——.transaction 各管各的曲线")
                .font(.system(size: 11))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("Transaction Override") { TransactionLayeredExample() }

// MARK: - Chapter Root

struct Chapter03_Transitions: View {
    var body: some View {
        List {
            Section("Transitions 基础") {
                NavigationLink("1. Transition Picker") { TransitionPickerExample() }
                NavigationLink("2. Asymmetric + 自定义 Modifier") { AsymmetricCustomExample() }
            }
            Section("Hero / Geometry") {
                NavigationLink("3. matchedGeometryEffect Hero") { HeroMatchedGeometryExample() }
            }
            Section("Content Transitions") {
                NavigationLink("4. numericText 数字滚动") { NumericContentTransitionExample() }
                NavigationLink("7. Step Card · push + symbolEffect") { StepCardPushExample() }
            }
            Section("Transition 协议（iOS 17+）") {
                NavigationLink("5. Custom: Bounce / Stretch") { CustomTransitionProtocolExample() }
            }
            Section("Coordination") {
                NavigationLink("6. Staggered ForEach") { StaggeredForEachExample() }
                NavigationLink("8. Transaction 局部曲线覆盖") { TransactionLayeredExample() }
            }
        }
        .navigationTitle("3. Transitions")
    }
}

#Preview("Chapter 03 Root") {
    NavigationStack { Chapter03_Transitions() }
}
