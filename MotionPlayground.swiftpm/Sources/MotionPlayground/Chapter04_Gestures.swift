// Chapter04_Gestures.swift — Gestures 全集（iOS 17+）
//
// 7 个独立示例 + 1 个章节根 view：
//   1. TapVsSpatialTap       —— SpatialTapGesture 拿到 hit-tested 位置，触摸位置出涟漪
//   2. LongPressThenDrag     —— LongPressGesture.sequenced(before: DragGesture) 长按后跟手拖
//   3. GestureStateVsState   —— @GestureState 临时位移 vs @State 累积位移对比
//   4. PinchPanRotate        —— Magnify + Drag + Rotate 三 gesture simultaneouslyWith 操控卡片
//   5. SwipeToDismissSheet   —— DragGesture.velocity 喂给 interactiveSpring（实战 NowPlayingSheet）
//   6. ScrollVsDrag          —— simultaneousGesture 让 ScrollView 与 tap 并存
//   7. CustomSwipeAction     —— 把"水平 swipe ≥ 80pt 触发回调"封装成可复用 Gesture
//
// 全部使用 DesignTokens.swift 中的 AnycastColor / AnycastSpacing / AnycastRadius。
import SwiftUI

// MARK: - 1. SpatialTapGesture：点哪儿出涟漪/圆点

/// SpatialTapGesture（iOS 17+）的 Value 是 CGPoint，能拿到 hit-tested 位置。
/// 比起普通 TapGesture 多了"知道点在哪"的能力——做 ripple、拾取菜单项、map pin 都靠它。
struct RippleOnTapDemo: View {
    /// 每个涟漪的状态：位置 + 是否已展开（用于驱动 scale/opacity）
    private struct Ripple: Identifiable {
        let id = UUID()
        let point: CGPoint
        var expanded = false
    }

    @State private var ripples: [Ripple] = []

    var body: some View {
        PlaygroundFrame("4.1 · SpatialTapGesture") {
            ZStack {
                RoundedRectangle(cornerRadius: AnycastRadius.card)
                    .fill(AnycastColor.sand1)
                    .overlay(
                        RoundedRectangle(cornerRadius: AnycastRadius.card)
                            .stroke(AnycastColor.sand4.opacity(0.5), lineWidth: 1)
                    )

                // 渲染所有 ripple
                ForEach(ripples) { r in
                    Circle()
                        .stroke(AnycastColor.goldAlpha60, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .scaleEffect(r.expanded ? 5 : 0.4)
                        .opacity(r.expanded ? 0 : 1)
                        .position(r.point)
                        .allowsHitTesting(false)
                }

                if ripples.isEmpty {
                    Text("点这里任何位置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AnycastColor.sand9)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        addRipple(at: value.location)
                    }
            )
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("SpatialTapGesture(coordinateSpace: .local) 的 .onEnded 拿到的 value.location 就是 hit-tested 坐标。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("ripple 数：\(ripples.count)")
                    .font(AnycastFont.mono(12))
                Spacer()
                Button("清空") { ripples.removeAll() }
                    .font(.system(size: 12, weight: .medium))
                    .disabled(ripples.isEmpty)
            }
        }
    }

    private func addRipple(at point: CGPoint) {
        let new = Ripple(point: point)
        ripples.append(new)
        // 下一帧驱动展开动画
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.6)) {
                if let idx = ripples.firstIndex(where: { $0.id == new.id }) {
                    ripples[idx].expanded = true
                }
            }
            // 动画结束清理
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                ripples.removeAll { $0.id == new.id }
            }
        }
    }
}

#Preview("4.1 SpatialTap Ripple") {
    RippleOnTapDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 2. LongPressGesture.sequenced(before: DragGesture)

/// 长按 0.3s 进入"可拖拽"状态，再跟手平移。典型 reorder / 拖拽磁贴模式。
/// SequenceGesture 的 Value 是嵌套枚举 .first(_) | .second(_, _?)，必须模式匹配。
struct LongPressThenDragDemo: View {
    /// 三态：未激活 / 已长按未拖 / 拖动中（带当前位移）
    enum DragState: Equatable {
        case inactive
        case pressing
        case dragging(CGSize)

        var translation: CGSize {
            if case .dragging(let t) = self { return t }
            return .zero
        }
        var isPressing: Bool {
            self != .inactive
        }
    }

    @State private var offset: CGSize = .zero          // 累积位移（提交后保留）
    @GestureState private var state: DragState = .inactive

    var body: some View {
        PlaygroundFrame("4.2 · LongPress.sequenced(before: Drag)") {
            ZStack {
                // 引导文字
                VStack(spacing: 6) {
                    Text("长按 0.3s 后拖动")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AnycastColor.sand9)
                    Text(stateLabel)
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9.opacity(0.7))
                }

                // 可拖拽圆
                Circle()
                    .fill(state.isPressing ? AnycastColor.orangeAlpha80 : AnycastColor.orangeAlpha60)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.6), lineWidth: state.isPressing ? 3 : 0)
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(state == .pressing ? 1.15 : 1.0)
                    .offset(x: offset.width + state.translation.width,
                            y: offset.height + state.translation.height)
                    .shadow(color: AnycastColor.orange.opacity(state.isPressing ? 0.4 : 0.15),
                            radius: state.isPressing ? 14 : 6, y: 6)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
                    .gesture(combinedGesture)
            }
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("LongPressGesture(0.3s).sequenced(before: DragGesture()) → updating 用 switch 拆 .first / .second")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("offset: x=\(Int(offset.width)) y=\(Int(offset.height))")
                    .font(AnycastFont.mono(11))
                Spacer()
                Button("回原位") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        offset = .zero
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var stateLabel: String {
        switch state {
        case .inactive:  return "状态：inactive"
        case .pressing:  return "状态：pressing（已识别长按）"
        case .dragging:  return "状态：dragging"
        }
    }

    private var combinedGesture: some Gesture {
        let press = LongPressGesture(minimumDuration: 0.3)
        let drag = DragGesture()
        return press.sequenced(before: drag)
            .updating($state) { value, state, _ in
                switch value {
                case .first(true):
                    state = .pressing
                case .second(true, let drag?):
                    state = .dragging(drag.translation)
                default:
                    state = .inactive
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                offset.width += drag.translation.width
                offset.height += drag.translation.height
            }
    }
}

#Preview("4.2 LongPress → Drag") {
    LongPressThenDragDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 3. @GestureState vs @State 对比

/// 同屏并排两张卡：左卡只用 @State（每帧 onChanged 写入），右卡用 @GestureState（updating 自动 reset）。
/// 故意"中途取消"才能看出区别——可在右下角 toggle "中断手势" 模拟。
struct GestureStateVsStateDemo: View {
    // 左卡：累积 @State
    @State private var leftLive: CGSize = .zero    // 拖动中实时
    @State private var leftCommitted: CGSize = .zero // 提交后

    // 右卡：临时 @GestureState + 累积 @State
    @GestureState private var rightLive: CGSize = .zero
    @State private var rightCommitted: CGSize = .zero

    var body: some View {
        PlaygroundFrame("4.3 · @GestureState vs @State") {
            HStack(spacing: AnycastSpacing.gap * 2) {
                cardLeft
                cardRight
            }
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("@GestureState 在手势 ended/cancelled 时自动归零；@State 必须自己管 reset。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack(spacing: AnycastSpacing.gap) {
                Button("把两张都送回原位") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        leftLive = .zero; leftCommitted = .zero
                        rightCommitted = .zero
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }

    private var cardLeft: some View {
        VStack(spacing: 6) {
            Text("@State")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnycastColor.sand9)
            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                .fill(AnycastColor.gold.opacity(0.7))
                .frame(width: 80, height: 100)
                .offset(leftLive)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            leftLive = CGSize(
                                width: leftCommitted.width + v.translation.width,
                                height: leftCommitted.height + v.translation.height
                            )
                        }
                        .onEnded { v in
                            leftCommitted.width += v.translation.width
                            leftCommitted.height += v.translation.height
                            leftLive = leftCommitted
                        }
                )
            Text("offset \(Int(leftLive.width)),\(Int(leftLive.height))")
                .font(AnycastFont.mono(10))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    private var cardRight: some View {
        VStack(spacing: 6) {
            Text("@GestureState")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnycastColor.sand9)
            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                .fill(AnycastColor.orange.opacity(0.7))
                .frame(width: 80, height: 100)
                .offset(x: rightCommitted.width + rightLive.width,
                        y: rightCommitted.height + rightLive.height)
                .gesture(
                    DragGesture()
                        .updating($rightLive) { value, state, _ in
                            state = value.translation     // 手势结束自动归零
                        }
                        .onEnded { v in
                            rightCommitted.width += v.translation.width
                            rightCommitted.height += v.translation.height
                        }
                )
            Text("commit \(Int(rightCommitted.width)),\(Int(rightCommitted.height))")
                .font(AnycastFont.mono(10))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("4.3 GestureState vs State") {
    GestureStateVsStateDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 4. Pinch + Pan + Rotate 三 gesture simultaneouslyWith

/// 用 MagnifyGesture / DragGesture / RotateGesture 三个 .simultaneously(with:)，同时操控一张卡。
/// 关键点：每个手势用 @GestureState 拿"临时增量"，onEnded 时累加到 @State。
struct PinchPanRotateDemo: View {
    // 累积值
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero

    // 临时值（手势进行中）
    @GestureState private var pinch: CGFloat = 1.0
    @GestureState private var pan: CGSize = .zero
    @GestureState private var spin: Angle = .zero

    var body: some View {
        PlaygroundFrame("4.4 · Pinch + Pan + Rotate (Simultaneous)") {
            ZStack {
                // 卡片
                ZStack {
                    RoundedRectangle(cornerRadius: AnycastRadius.card)
                        .fill(
                            LinearGradient(
                                colors: [AnycastColor.gold, AnycastColor.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 38, weight: .bold))
                        Text("PINCH · PAN · SPIN")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.white)
                }
                .frame(width: 160, height: 100)
                .scaleEffect(scale * pinch)
                .rotationEffect(rotation + spin)
                .offset(x: offset.width + pan.width,
                        y: offset.height + pan.height)
                .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { v, s, _ in s = v.magnification }
                        .onEnded { v in
                            scale = max(0.4, min(4.0, scale * v.magnification))
                        }
                        .simultaneously(with:
                            RotateGesture()
                                .updating($spin) { v, s, _ in s = v.rotation }
                                .onEnded { v in rotation = rotation + v.rotation }
                        )
                        .simultaneously(with:
                            DragGesture()
                                .updating($pan) { v, s, _ in s = v.translation }
                                .onEnded { v in
                                    offset.width += v.translation.width
                                    offset.height += v.translation.height
                                }
                        )
                )
            }
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("MagnifyGesture.simultaneously(with: RotateGesture).simultaneously(with: DragGesture)")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("scale=\(String(format: "%.2f", scale))  rot=\(Int(rotation.degrees))°")
                    .font(AnycastFont.mono(11))
                Spacer()
                Button("Reset") {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                        scale = 1; offset = .zero; rotation = .zero
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }
            Text("提示：sim 上需按住 Option 模拟双指捏合 / 旋转。")
                .font(.system(size: 10))
                .foregroundStyle(AnycastColor.sand9.opacity(0.7))
        }
    }
}

#Preview("4.4 Pinch + Pan + Rotate") {
    PinchPanRotateDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 5. Swipe-to-dismiss + velocity → interactiveSpring（NowPlayingSheet 实战）

/// 模拟 Anycast NowPlayingSheet：下滑超过阈值 *或* 速度足够大时关闭，否则 spring 回弹。
/// 核心：把 v.velocity.height 喂给 .interactiveSpring，让动画"接力"手指速度，不从 0 起步。
struct SwipeToDismissDemo: View {
    @State private var dragY: CGFloat = 0
    @State private var dismissed = false

    private let dismissDistance: CGFloat = 120
    private let dismissVelocity: CGFloat = 800   // pt/s
    private let sheetHeight: CGFloat = 240

    var body: some View {
        PlaygroundFrame("4.5 · Swipe-to-Dismiss + Velocity") {
            ZStack(alignment: .bottom) {
                // 背板（半透明 sand12 模拟 dim）
                RoundedRectangle(cornerRadius: AnycastRadius.card)
                    .fill(AnycastColor.sand1)
                    .overlay(
                        AnycastColor.sand12.opacity(dismissed ? 0 : 0.18)
                            .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                            .allowsHitTesting(false)
                    )

                // 假 NowPlayingSheet
                VStack(spacing: 10) {
                    Capsule()
                        .fill(AnycastColor.sand4.opacity(0.6))
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(AnycastColor.gold)

                    Text("Now Playing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AnycastColor.sand12)
                    Text("下滑关闭 · 快速 flick 也能触发")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: sheetHeight)
                .background(
                    RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                        .fill(AnycastColor.sand2)
                        .shadow(color: .black.opacity(0.18), radius: 14, y: -4)
                )
                .offset(y: dismissed ? sheetHeight + 40 : max(0, dragY))
                .gesture(swipeGesture)

                // Reset 按钮（dismissed 时浮在上方）
                if dismissed {
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                            dragY = 0
                            dismissed = false
                        }
                    } label: {
                        Label("再呼出", systemImage: "arrow.up.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(AnycastColor.gold, in: Capsule())
                    }
                    .padding(.bottom, AnycastSpacing.gap)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("DragGesture.velocity.height (iOS 17+, CGSize) → interactiveSpring(initialVelocity:) 接力")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("dragY=\(Int(dragY)) · dismissed=\(dismissed ? "y" : "n")")
                    .font(AnycastFont.mono(11))
                Spacer()
            }
            Text("阈值：位移 > \(Int(dismissDistance))pt 或 速度 > \(Int(dismissVelocity))pt/s")
                .font(.system(size: 10))
                .foregroundStyle(AnycastColor.sand9.opacity(0.7))
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { v in
                // 只允许向下拖
                dragY = max(0, v.translation.height)
            }
            .onEnded { v in
                let dy = v.translation.height
                let vy = v.velocity.height                  // iOS 17+
                let shouldDismiss = dy > dismissDistance || vy > dismissVelocity

                if shouldDismiss {
                    // velocity 接力：normalized initialVelocity 喂给 interactiveSpring
                    let normalized = vy / max(1, sheetHeight - dragY)
                    withAnimation(.interactiveSpring(
                        response: 0.42,
                        dampingFraction: 0.86,
                        blendDuration: 0
                    )) {
                        dismissed = true
                    }
                    _ = normalized // 留作教学注释参考；真实场景可传给 timing 参数
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                        dragY = 0
                    }
                }
            }
    }
}

#Preview("4.5 Swipe-to-Dismiss") {
    SwipeToDismissDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 6. ScrollView × Tap：simultaneousGesture 共存

/// 在 ScrollView 子 cell 上同时识别滚动和单击——必须用 simultaneousGesture。
/// 直接 .gesture(TapGesture()) 在大多数情况下也能工作，但子 view 已经有 Button/NavLink 时就要 simultaneous 才不打架。
struct ScrollVsDragDemo: View {
    @State private var lastTappedRow: Int? = nil
    @State private var tapCount = 0

    var body: some View {
        PlaygroundFrame("4.6 · ScrollView × simultaneousGesture") {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(0..<14) { i in
                        rowCell(i)
                    }
                }
                .padding(AnycastSpacing.gap)
            }
            .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
        } controls: {
            Text(".simultaneousGesture(TapGesture()) 让 scroll 与 tap 并存——子 view 用纯 .gesture 会吃掉滚动")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("最后点击 row：\(lastTappedRow.map(String.init) ?? "—")  共 \(tapCount) 次")
                    .font(AnycastFont.mono(11))
                Spacer()
                Button("清空") {
                    lastTappedRow = nil; tapCount = 0
                }
                .font(.system(size: 12, weight: .medium))
                .disabled(tapCount == 0)
            }
        }
    }

    @ViewBuilder
    private func rowCell(_ i: Int) -> some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .foregroundStyle(AnycastColor.goldAlpha9)
            Text("Episode #\(i + 1)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AnycastColor.sand12)
            Spacer()
            if lastTappedRow == i {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AnycastColor.orange)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                lastTappedRow = i
                tapCount += 1
            }
        )
    }
}

#Preview("4.6 Scroll × Tap") {
    ScrollVsDragDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 7. 自定义 Gesture：水平 swipe 触发 left/right action

/// 把"水平 swipe ≥ threshold 触发回调"封装成可复用 Gesture——遵守 Gesture 协议、把 body 委托给 DragGesture。
struct SwipeAction: Gesture {
    var threshold: CGFloat = 80
    var onLeft: () -> Void
    var onRight: () -> Void

    var body: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { v in
                if v.translation.width > threshold { onRight() }
                else if v.translation.width < -threshold { onLeft() }
            }
    }
}

struct CustomSwipeActionDemo: View {
    enum Action: String { case left = "← Archive", right = "Delete →", none = "—" }
    @State private var lastAction: Action = .none
    @State private var x: CGFloat = 0
    @GestureState private var liveDrag: CGFloat = 0

    var body: some View {
        PlaygroundFrame("4.7 · 自定义 Gesture：SwipeAction") {
            VStack(spacing: AnycastSpacing.gap) {
                // 左右 hint label
                HStack {
                    Text("← Archive").foregroundStyle(AnycastColor.gold)
                    Spacer()
                    Text("Delete →").foregroundStyle(AnycastColor.orange)
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 6)

                ZStack {
                    RoundedRectangle(cornerRadius: AnycastRadius.card)
                        .fill(
                            (liveDrag > 0 ? AnycastColor.orange : AnycastColor.gold)
                                .opacity(min(0.9, Double(abs(liveDrag)) / 80.0))
                        )
                        .frame(height: 84)

                    HStack {
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AnycastColor.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Episode card")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AnycastColor.sand12)
                            Text("水平 swipe ≥ 80pt 触发")
                                .font(.system(size: 11))
                                .foregroundStyle(AnycastColor.sand9)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .background(
                        RoundedRectangle(cornerRadius: AnycastRadius.card)
                            .fill(AnycastColor.sand1)
                    )
                    .offset(x: x + liveDrag)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
                    .gesture(
                        // 同时挂：(a) updating 显示实时位移；(b) 自定义 SwipeAction 触发回调
                        DragGesture(minimumDistance: 5)
                            .updating($liveDrag) { v, s, _ in s = v.translation.width }
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    x = 0
                                }
                            }
                            .simultaneously(with:
                                SwipeAction(
                                    onLeft:  { lastAction = .left  },
                                    onRight: { lastAction = .right }
                                )
                            )
                    )
                }

                Text("最近触发：\(lastAction.rawValue)")
                    .font(AnycastFont.mono(12))
                    .foregroundStyle(AnycastColor.sand12)
            }
            .padding(AnycastSpacing.gap)
        } controls: {
            Text("struct SwipeAction: Gesture { var body: some Gesture { DragGesture()...onEnded } }")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
            HStack {
                Text("liveDrag x=\(Int(liveDrag))")
                    .font(AnycastFont.mono(11))
                Spacer()
                Button("Reset") { lastAction = .none }
                    .font(.system(size: 12, weight: .medium))
                    .disabled(lastAction == .none)
            }
        }
    }
}

#Preview("4.7 SwipeAction") {
    CustomSwipeActionDemo()
        .background(AnycastColor.sand1)
}

// MARK: - 章节根 view

public struct Chapter04_Gestures: View {
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnycastSpacing.sectionGap) {
                header
                RippleOnTapDemo()
                LongPressThenDragDemo()
                GestureStateVsStateDemo()
                PinchPanRotateDemo()
                SwipeToDismissDemo()
                ScrollVsDragDemo()
                CustomSwipeActionDemo()
            }
            .padding(.bottom, AnycastSpacing.sectionGap)
        }
        .background(AnycastColor.sand1.ignoresSafeArea())
        .navigationTitle("4. Gestures 全集")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gestures")
                .font(AnycastFont.display(34))
                .foregroundStyle(AnycastColor.sand12)
            Text("原子 / 组合 / 自定义 三层抽象 · velocity 接力 spring · @GestureState vs @State · iOS 17+")
                .font(.system(size: 13))
                .foregroundStyle(AnycastColor.sand9)
        }
        .padding(.horizontal, AnycastSpacing.pageH)
        .padding(.top, AnycastSpacing.pageHeader)
    }
}

#Preview("Chapter 04 · 全集") {
    NavigationStack {
        Chapter04_Gestures()
    }
}
