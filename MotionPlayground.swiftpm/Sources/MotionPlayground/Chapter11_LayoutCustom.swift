// Chapter11_LayoutCustom.swift — 第 11 章：Custom Layout 协议
// 来自 research/swiftui-motion/topics/11-layout-custom.md 的可运行示例。
// 每个示例独立 struct，配 #Preview；末尾 Chapter11_LayoutCustom 是入口列表。
import SwiftUI

// MARK: - 共享布局：FlowLayout —— 标签流换行（完整 sizeThatFits + placeSubviews）
/// width-driven 流式布局：一行装不下就换行。带 cache 复用 row 测量结果。
struct FlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    struct Row {
        var range: Range<Int>
        var sizes: [CGSize]
        var width: CGFloat
        var height: CGFloat
    }

    struct Cache {
        var width: CGFloat = .nan
        var rows: [Row] = []
        var totalSize: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // 子 view 集合变了：作废上一次按 width 缓存的行，下次重算
        cache.width = .nan
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        compute(maxWidth: maxWidth, subviews: subviews, cache: &cache)
        return CGSize(
            width: proposal.width ?? cache.totalSize.width,
            height: cache.totalSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let maxWidth = bounds.width
        compute(maxWidth: maxWidth, subviews: subviews, cache: &cache)

        var y = bounds.minY
        for row in cache.rows {
            let leftover = maxWidth - row.width
            var x: CGFloat
            switch alignment {
            case .center:   x = bounds.minX + leftover / 2
            case .trailing: x = bounds.minX + leftover
            default:        x = bounds.minX
            }
            for (offset, idx) in row.range.enumerated() {
                let size = row.sizes[offset]
                subviews[idx].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + hSpacing
            }
            y += row.height + vSpacing
        }
    }

    private func compute(
        maxWidth: CGFloat,
        subviews: Subviews,
        cache: inout Cache
    ) {
        // memoization：同一个 width 不重算
        guard cache.width != maxWidth else { return }
        cache.width = maxWidth
        cache.rows.removeAll(keepingCapacity: true)

        var rowStart = 0
        var rowSizes: [CGSize] = []
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let needed = rowSizes.isEmpty ? size.width : rowWidth + hSpacing + size.width
            if !rowSizes.isEmpty && needed > maxWidth {
                cache.rows.append(.init(
                    range: rowStart..<i,
                    sizes: rowSizes,
                    width: rowWidth,
                    height: rowHeight
                ))
                totalHeight += rowHeight + vSpacing
                totalWidth = max(totalWidth, rowWidth)
                rowStart = i
                rowSizes = [size]
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowSizes.append(size)
                rowWidth = needed
                rowHeight = max(rowHeight, size.height)
            }
        }
        if !rowSizes.isEmpty {
            cache.rows.append(.init(
                range: rowStart..<subviews.endIndex,
                sizes: rowSizes,
                width: rowWidth,
                height: rowHeight
            ))
            totalHeight += rowHeight
            totalWidth = max(totalWidth, rowWidth)
        }
        cache.totalSize = CGSize(width: totalWidth, height: totalHeight)
    }
}


// MARK: - 共享布局：RadialLayout —— 圆形菜单（完整 sizeThatFits + placeSubviews）
/// 把 N 个子 view 等角度铺到圆周上。startAngle 从哪个角度开始，clockwise 顺/逆时针。
struct RadialLayout: Layout {
    var startAngle: Angle = .degrees(-90)
    var clockwise: Bool = true

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // 取 proposal 短边作为正方形边长，nil 默认 240
        let side = min(
            proposal.width ?? 240,
            proposal.height ?? 240
        )
        return CGSize(width: side, height: side)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // 半径 = 容器短边 / 2 - 最大子 view 半径，避免溢出边框
        let maxChild = subviews
            .map { $0.sizeThatFits(.unspecified) }
            .reduce(CGFloat(0)) { max($0, max($1.width, $1.height)) }
        let radius = max(0, (min(bounds.width, bounds.height) - maxChild) / 2)

        let step = 2 * .pi / Double(subviews.count)
        let dir: Double = clockwise ? 1 : -1

        for (i, subview) in subviews.enumerated() {
            let angle = startAngle.radians + dir * step * Double(i)
            let pt = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            subview.place(at: pt, anchor: .center, proposal: .unspecified)
        }
    }
}


// MARK: - 示例 1：FlowLayout 标签流 —— 增删 chip + spring 过渡
struct FlowLayoutChipsDemo: View {
    private let palette = [
        "Daily", "Tech", "Comedy", "History", "Design",
        "Music", "Science", "Politics", "Sports", "Film",
        "Business", "Health", "Cooking"
    ]

    @State private var chips: [String] = ["Daily", "Tech", "Comedy", "History", "Design"]

    private var addable: [String] {
        palette.filter { !chips.contains($0) }
    }

    var body: some View {
        PlaygroundFrame("FlowLayout · 标签流换行") {
            VStack(spacing: AnycastSpacing.gap) {
                FlowLayout(hSpacing: 8, vSpacing: 8, alignment: .leading) {
                    ForEach(chips, id: \.self) { tag in
                        chipView(tag: tag, removable: true)
                    }
                }
                .padding(AnycastSpacing.gap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.sm))

                if !addable.isEmpty {
                    Text("点下方加进流里")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                    FlowLayout(hSpacing: 6, vSpacing: 6, alignment: .leading) {
                        ForEach(addable, id: \.self) { tag in
                            Button {
                                withAnimation(.spring(duration: 0.45, bounce: 0.32)) {
                                    chips.append(tag)
                                }
                            } label: {
                                Text("+ \(tag)")
                                    .font(.system(size: 12, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(AnycastColor.sand12.opacity(0.06),
                                                in: Capsule())
                                    .foregroundStyle(AnycastColor.sand12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AnycastSpacing.gap)
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.28), value: chips)
        } controls: {
            HStack {
                Text("\(chips.count) 个标签 · 行数随宽度变化")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button("清空") {
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        chips.removeAll()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnycastColor.orange)
                .disabled(chips.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func chipView(tag: String, removable: Bool) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.system(size: 13, weight: .semibold))
            if removable {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AnycastColor.goldAlpha40, in: Capsule())
        .foregroundStyle(AnycastColor.sand12)
        .onTapGesture {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
                chips.removeAll { $0 == tag }
            }
        }
    }
}

#Preview("1. FlowLayout Chips") { FlowLayoutChipsDemo() }


// MARK: - 示例 2：RadialLayout —— Slider 调 startAngle 看子项绕圈
struct RadialLayoutDemo: View {
    @State private var startAngleDeg: Double = -90
    @State private var clockwise: Bool = true
    @State private var count: Int = 8

    private var symbols: [String] {
        let all = [
            "play.fill", "pause.fill", "forward.fill", "backward.fill",
            "speaker.wave.2.fill", "heart.fill", "bookmark.fill", "star.fill",
            "headphones", "music.note", "mic.fill", "waveform"
        ]
        return Array(all.prefix(count))
    }

    var body: some View {
        PlaygroundFrame("RadialLayout · 圆形菜单") {
            VStack(spacing: 0) {
                ZStack {
                    // 参考圆
                    Circle()
                        .stroke(AnycastColor.sand4, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 220, height: 220)

                    RadialLayout(
                        startAngle: .degrees(startAngleDeg),
                        clockwise: clockwise
                    ) {
                        ForEach(symbols, id: \.self) { name in
                            Image(systemName: name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AnycastColor.sand12)
                                .frame(width: 38, height: 38)
                                .background(AnycastColor.goldAlpha60, in: Circle())
                        }
                    }
                    .frame(width: 240, height: 240)

                    // 中心标签
                    Text("\(Int(startAngleDeg))°")
                        .font(AnycastFont.mono(13))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 260)
            }
            .animation(.spring(duration: 0.45, bounce: 0.3), value: count)
            .animation(.spring(duration: 0.55, bounce: 0.25), value: clockwise)
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("startAngle")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand12)
                        Spacer()
                        Text(String(format: "%+.0f°", startAngleDeg))
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                    Slider(value: $startAngleDeg, in: -180...180)
                        .tint(AnycastColor.gold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("count")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand12)
                        Spacer()
                        Text("\(count)")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                    Slider(value: Binding(
                        get: { Double(count) },
                        set: { count = max(2, min(12, Int($0))) }
                    ), in: 2...12, step: 1)
                    .tint(AnycastColor.orange)
                }

                Toggle(isOn: $clockwise) {
                    Text(clockwise ? "顺时针 (clockwise)" : "逆时针 (counter-clockwise)")
                        .font(.system(size: 12))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .tint(AnycastColor.gold)
            }
        }
    }
}

#Preview("2. RadialLayout") { RadialLayoutDemo() }


// MARK: - 示例 3：AnyLayout 切换 —— list / grid / radial 同一组子 view
private struct GalleryItem: Identifiable, Hashable {
    let id: Int
    let title: String
    let color: Color
    let symbol: String
}

struct AnyLayoutSwitcherDemo: View {
    enum Mode: String, CaseIterable, Identifiable {
        case list, grid, radial
        var id: String { rawValue }
    }

    @State private var mode: Mode = .grid

    private let items: [GalleryItem] = [
        GalleryItem(id: 0, title: "Daily",    color: AnycastColor.gold,           symbol: "sun.max.fill"),
        GalleryItem(id: 1, title: "Tech",     color: AnycastColor.orange,         symbol: "cpu.fill"),
        GalleryItem(id: 2, title: "Music",    color: AnycastColor.goldAlpha60,    symbol: "music.note"),
        GalleryItem(id: 3, title: "History",  color: AnycastColor.orangeAlpha60,  symbol: "book.fill"),
        GalleryItem(id: 4, title: "Comedy",   color: AnycastColor.goldAlpha40,    symbol: "face.smiling.fill"),
        GalleryItem(id: 5, title: "Science",  color: AnycastColor.orangeAlpha40,  symbol: "atom"),
        GalleryItem(id: 6, title: "Sport",    color: AnycastColor.gold,           symbol: "figure.run"),
        GalleryItem(id: 7, title: "Film",     color: AnycastColor.orange,         symbol: "film.fill")
    ]

    private var layout: AnyLayout {
        switch mode {
        case .list:   return AnyLayout(VStackLayout(spacing: 8))
        case .grid:   return AnyLayout(FlowLayout(hSpacing: 10, vSpacing: 10, alignment: .leading))
        case .radial: return AnyLayout(RadialLayout(startAngle: .degrees(-90)))
        }
    }

    var body: some View {
        PlaygroundFrame("AnyLayout · list / grid / radial") {
            VStack(spacing: AnycastSpacing.gap) {
                // 关键：layout 直接当 view builder 调用，ForEach 用 stable id
                layout {
                    ForEach(items) { item in
                        itemTile(item)
                            // .id(item.id) 不必要 —— ForEach 的 Identifiable 已保 identity
                    }
                }
                .frame(maxWidth: .infinity, minHeight: mode == .radial ? 260 : 100)
                .padding(mode == .radial ? 0 : AnycastSpacing.gap)
                .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
                .animation(.spring(duration: 0.55, bounce: 0.28), value: mode)
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Picker("Layout", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue.capitalized).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Text("AnyLayout 切换需要：① ForEach + stable id；② layout 直接当 builder，不要走 if/else 分支。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }

    @ViewBuilder
    private func itemTile(_ item: GalleryItem) -> some View {
        HStack(spacing: 6) {
            Image(systemName: item.symbol)
                .font(.system(size: 12, weight: .bold))
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(item.color, in: Capsule())
        .foregroundStyle(AnycastColor.sand12)
    }
}

#Preview("3. AnyLayout Switcher") { AnyLayoutSwitcherDemo() }


// MARK: - 示例 4：LayoutValueKey —— 给子 view 附 metadata（priority），FlowLayout 按它排序
private struct ChipPriorityKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

extension View {
    fileprivate func chipPriority(_ value: Int) -> some View {
        layoutValue(key: ChipPriorityKey.self, value: value)
    }
}

/// 演示：在 placeSubviews 里读取 LayoutValueKey，按 priority 重新排序。
struct PriorityFlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let layout = computeLayout(subviews: subviews, maxWidth: maxWidth)
        return CGSize(
            width: proposal.width ?? layout.size.width,
            height: layout.size.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let layout = computeLayout(subviews: subviews, maxWidth: bounds.width)
        for placement in layout.placements {
            subviews[placement.index].place(
                at: CGPoint(
                    x: bounds.minX + placement.origin.x,
                    y: bounds.minY + placement.origin.y
                ),
                anchor: .topLeading,
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    private struct Placement {
        let index: Int
        let origin: CGPoint
        let size: CGSize
    }

    private struct LayoutResult {
        let placements: [Placement]
        let size: CGSize
    }

    private func computeLayout(subviews: Subviews, maxWidth: CGFloat) -> LayoutResult {
        // 按 priority 降序排序，相同 priority 保持原顺序
        let order = subviews.indices.sorted {
            let a = subviews[$0][ChipPriorityKey.self]
            let b = subviews[$1][ChipPriorityKey.self]
            return a == b ? $0 < $1 : a > b
        }

        var placements: [Placement] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for idx in order {
            let size = subviews[idx].sizeThatFits(.unspecified)
            // 当前行装不下：换行
            if x > 0, x + size.width > maxWidth {
                y += rowHeight + vSpacing
                x = 0
                rowHeight = 0
            }
            placements.append(Placement(
                index: idx,
                origin: CGPoint(x: x, y: y),
                size: size
            ))
            x += size.width + hSpacing
            rowHeight = max(rowHeight, size.height)
            totalWidth = max(totalWidth, x - hSpacing)
        }

        return LayoutResult(
            placements: placements,
            size: CGSize(width: totalWidth, height: y + rowHeight)
        )
    }
}

struct LayoutValueKeyDemo: View {
    private struct Chip: Identifiable, Hashable {
        let id: Int
        let title: String
        var priority: Int
    }

    @State private var chips: [Chip] = [
        Chip(id: 0, title: "Inbox",     priority: 5),
        Chip(id: 1, title: "Subscribed", priority: 3),
        Chip(id: 2, title: "Recent",    priority: 1),
        Chip(id: 3, title: "Saved",     priority: 4),
        Chip(id: 4, title: "Trending",  priority: 2),
        Chip(id: 5, title: "Editor",    priority: 0)
    ]

    var body: some View {
        PlaygroundFrame("LayoutValueKey · priority 排序") {
            VStack(spacing: AnycastSpacing.gap) {
                PriorityFlowLayout(hSpacing: 8, vSpacing: 8) {
                    ForEach(chips) { chip in
                        Text("\(chip.title) · \(chip.priority)")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                AnycastColor.gold.opacity(0.25 + Double(chip.priority) * 0.12),
                                in: Capsule()
                            )
                            .foregroundStyle(AnycastColor.sand12)
                            .chipPriority(chip.priority)
                    }
                }
                .padding(AnycastSpacing.gap)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
                .animation(.spring(duration: 0.5, bounce: 0.28), value: chips.map(\.priority))
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("点 chip：随机重排 priority。chip 自己绕过 source 顺序，按容器读到的 LayoutValueKey 排版。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                HStack {
                    Button("随机 priority") {
                        withAnimation(.spring(duration: 0.55, bounce: 0.3)) {
                            for i in chips.indices {
                                chips[i].priority = Int.random(in: 0...5)
                            }
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnycastColor.orange)
                    Spacer()
                    Button("重置") {
                        withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                            chips = [
                                Chip(id: 0, title: "Inbox",     priority: 5),
                                Chip(id: 1, title: "Subscribed", priority: 3),
                                Chip(id: 2, title: "Recent",    priority: 1),
                                Chip(id: 3, title: "Saved",     priority: 4),
                                Chip(id: 4, title: "Trending",  priority: 2),
                                Chip(id: 5, title: "Editor",    priority: 0)
                            ]
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnycastColor.gold)
                }
            }
        }
    }
}

#Preview("4. LayoutValueKey · Priority") { LayoutValueKeyDemo() }


// MARK: - 示例 5：Animatable Layout —— RadialLayout 内插 startAngle，旋转扫一圈
/// RadialLayout 的可动画版本：将 startAngle 暴露为 animatableData，
/// SwiftUI 会在两个 startAngle 之间逐帧插值。
struct AnimatableRadialLayout: Layout, Animatable {
    var startAngle: Angle = .degrees(-90)
    var clockwise: Bool = true

    var animatableData: Double {
        get { startAngle.radians }
        set { startAngle = .radians(newValue) }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let side = min(
            proposal.width ?? 240,
            proposal.height ?? 240
        )
        return CGSize(width: side, height: side)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let maxChild = subviews
            .map { $0.sizeThatFits(.unspecified) }
            .reduce(CGFloat(0)) { max($0, max($1.width, $1.height)) }
        let radius = max(0, (min(bounds.width, bounds.height) - maxChild) / 2)
        let step = 2 * .pi / Double(subviews.count)
        let dir: Double = clockwise ? 1 : -1
        for (i, subview) in subviews.enumerated() {
            let angle = startAngle.radians + dir * step * Double(i)
            let pt = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
            subview.place(at: pt, anchor: .center, proposal: .unspecified)
        }
    }
}

struct AnimatableLayoutDemo: View {
    @State private var spin: Double = -90      // degrees
    private let symbols = ["1.circle.fill", "2.circle.fill", "3.circle.fill",
                           "4.circle.fill", "5.circle.fill", "6.circle.fill"]

    var body: some View {
        PlaygroundFrame("Animatable Layout · 整组绕圈插值") {
            ZStack {
                Circle()
                    .stroke(AnycastColor.sand4, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 200, height: 200)

                AnimatableRadialLayout(startAngle: .degrees(spin)) {
                    ForEach(symbols, id: \.self) { name in
                        Image(systemName: name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(AnycastColor.orange)
                            .frame(width: 36, height: 36)
                            .background(AnycastColor.sand1, in: Circle())
                            .overlay(Circle().stroke(AnycastColor.orangeAlpha60, lineWidth: 1.5))
                    }
                }
                .frame(width: 240, height: 240)
                .animation(.spring(duration: 0.7, bounce: 0.3), value: spin)
            }
            .frame(maxWidth: .infinity)
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Text("点按钮：startAngle 通过 animatableData 在两次值之间插值，整组节点沿圆轨平滑滚动。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                HStack {
                    Button("逆时针 90°") { spin -= 90 }
                        .buttonStyle(SpinButtonStyle(tint: AnycastColor.gold))
                    Spacer()
                    Button("归零") { spin = -90 }
                        .buttonStyle(SpinButtonStyle(tint: AnycastColor.sand9))
                    Spacer()
                    Button("顺时针 90°") { spin += 90 }
                        .buttonStyle(SpinButtonStyle(tint: AnycastColor.orange))
                }
            }
        }
    }
}

private struct SpinButtonStyle: ButtonStyle {
    let tint: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(configuration.isPressed ? 0.45 : 0.25), in: Capsule())
            .foregroundStyle(tint)
    }
}

#Preview("5. Animatable Layout") { AnimatableLayoutDemo() }


// MARK: - 示例 6：Proposal 三态 —— 同一 FlowLayout，nil / 有限值 / .infinity 拿到的尺寸
struct ProposalProbeDemo: View {
    @State private var widthMode: WidthMode = .finite

    enum WidthMode: String, CaseIterable, Identifiable {
        case nilUnspecified = "nil (unspecified)"
        case finite = "有限值 (200pt)"
        case infinityCase = "infinity"
        var id: String { rawValue }
    }

    private let chips = ["SwiftUI", "Layout", "Cache",
                         "Proposal", "Subviews",
                         "Animatable", "Anchor"]

    var body: some View {
        PlaygroundFrame("Proposal 三态 · width 决定换行") {
            VStack(spacing: AnycastSpacing.gap) {
                ZStack(alignment: .topLeading) {
                    // 灰色框：当前 proposal 给的"建议宽度"
                    RoundedRectangle(cornerRadius: AnycastRadius.sm)
                        .stroke(AnycastColor.sand4, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: containerWidth, height: 160)

                    FlowLayout(hSpacing: 6, vSpacing: 6, alignment: .leading) {
                        ForEach(chips, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 12, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AnycastColor.goldAlpha40, in: Capsule())
                                .foregroundStyle(AnycastColor.sand12)
                        }
                    }
                    .frame(width: containerWidth, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .animation(.spring(duration: 0.5, bounce: 0.25), value: widthMode)
            }
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Picker("width", selection: $widthMode) {
                    ForEach(WidthMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                Text(currentExplanation)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }

    private var containerWidth: CGFloat {
        switch widthMode {
        case .nilUnspecified: return 320     // 模拟 nil → 取理想总宽
        case .finite:         return 200
        case .infinityCase:   return 360     // 模拟 infinity → 摊到一行
        }
    }

    private var currentExplanation: String {
        switch widthMode {
        case .nilUnspecified: return "proposal.width = nil → 容器返回理想宽度"
        case .finite:         return "proposal.width = 200 → 按硬约束换行"
        case .infinityCase:   return "proposal.width = .infinity → 一行展开（FlowLayout 会被父级裁切）"
        }
    }
}

#Preview("6. Proposal Probe") { ProposalProbeDemo() }


// MARK: - Chapter root —— 章节入口列表
struct Chapter11_LayoutCustom: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "FlowLayout Chips",
                 subtitle: "完整 FlowLayout 实现 · 增删 chip · spring 过渡",
                 view: AnyView(FlowLayoutChipsDemo())),
            Demo(number: 2, title: "RadialLayout",
                 subtitle: "Slider 调 startAngle 看子项绕圈 · 顺逆时针切换",
                 view: AnyView(RadialLayoutDemo())),
            Demo(number: 3, title: "AnyLayout Switcher",
                 subtitle: "Picker 在 list / grid / radial 三种 layout 间 spring 切换",
                 view: AnyView(AnyLayoutSwitcherDemo())),
            Demo(number: 4, title: "LayoutValueKey · Priority",
                 subtitle: "子 view 用 layoutValue 携带 metadata，容器按 priority 排版",
                 view: AnyView(LayoutValueKeyDemo())),
            Demo(number: 5, title: "Animatable Layout",
                 subtitle: "Layout 实现 Animatable，startAngle 通过 animatableData 插值",
                 view: AnyView(AnimatableLayoutDemo())),
            Demo(number: 6, title: "Proposal Probe",
                 subtitle: "ProposedViewSize 三态：nil / 有限值 / .infinity 视觉对照",
                 view: AnyView(ProposalProbeDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 11 章 · Custom Layout 协议") {
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
        .navigationTitle("Ch. 11 Custom Layout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 11 — Custom Layout") {
    NavigationStack { Chapter11_LayoutCustom() }
}
