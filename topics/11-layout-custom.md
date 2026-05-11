<h3>11.1 Layout 协议总览</h3>

<p>SwiftUI 在 iOS 16 引入 <code>Layout</code> 协议，让开发者可以编写完全自定义的容器，且可以 <strong>参与 SwiftUI 的动画与几何系统</strong>。区别于早期 <code>GeometryReader + offset</code> 的"假布局"，<code>Layout</code> 协议让自定义容器获得与 <code>HStack</code> 一等公民地位：</p>

<ul>
<li>容器告诉父级"我需要多大"——通过 <code>sizeThatFits</code></li>
<li>容器告诉子级"你被放在哪里、给你多大空间"——通过 <code>placeSubviews</code></li>
<li>整个过程是 <strong>纯函数式</strong> 的</li>
<li>因为 frame 是 SwiftUI 算出来的，所以 <code>matchedGeometryEffect</code>、<code>.animation</code>、<code>geometryGroup</code> 全部生效</li>
</ul>

<p>核心 API 签名（iOS 16+，WWDC22 Session 10056）：</p>

<pre><code class="language-swift">// iOS 16+
public protocol Layout: Animatable {
    associatedtype Cache = Void
    static var layoutProperties: LayoutProperties { get }

    func makeCache(subviews: Subviews) -> Cache
    func updateCache(_ cache: inout Cache, subviews: Subviews)

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    )

    func explicitAlignment(...) -> CGFloat?
    func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing
}</code></pre>

<h4>ProposedViewSize 三态语义</h4>

<table>
<thead><tr><th>值</th><th>含义</th><th>响应策略</th></tr></thead>
<tbody>
<tr><td><code>nil</code></td><td>"理想大小"</td><td>测量子内容总尺寸返回</td></tr>
<tr><td><code>.zero</code></td><td>"最小可压缩到多少"</td><td>返回 minimum bound</td></tr>
<tr><td><code>.infinity</code></td><td>"最大可扩张到多少"</td><td>返回 ideal 或截断到内容</td></tr>
<tr><td>有限值</td><td>"建议你用这个尺寸"</td><td>用它布局，返回实际占用</td></tr>
</tbody></table>

<blockquote>常见错误：直接 <code>proposal.replacingUnspecifiedDimensions()</code> 而忽略 infinity 的语义。FlowLayout / Masonry 这类 width-driven 布局，至少要把 <strong>宽度</strong> 当作硬约束处理。</blockquote>

<h3>11.2 LayoutSubview 与 LayoutValueKey</h3>

<p>给子 view 附加 metadata 的官方方式是 <strong>LayoutValueKey</strong>：</p>

<pre><code class="language-swift">// iOS 16+
private struct RankKey: LayoutValueKey {
    static let defaultValue: Int = 0
}

extension View {
    func flowRank(_ value: Int) -> some View {
        layoutValue(key: RankKey.self, value: value)
    }
}

// 容器内读取：subview[RankKey.self]</code></pre>

<h3>11.3 makeCache / updateCache 正确姿势</h3>

<p>SwiftUI 在一次 layout pass 里会多次调用 <code>sizeThatFits</code>（不同 proposal 探测）+ 一次 <code>placeSubviews</code>。如果每次都重新测量子 view，O(n²)。</p>

<pre><code class="language-swift">// iOS 16+
struct FlowLayout: Layout {
    struct Cache {
        var rows: [Row] = []
        var lastProposalWidth: CGFloat = .nan
        var totalSize: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.lastProposalWidth = .nan
    }

    private func ensureCache(
        _ cache: inout Cache,
        subviews: Subviews,
        proposalWidth: CGFloat
    ) {
        guard cache.lastProposalWidth != proposalWidth else { return }
        let result = computeRows(subviews: subviews, maxWidth: proposalWidth)
        cache.rows = result.rows
        cache.totalSize = result.size
        cache.lastProposalWidth = proposalWidth
    }
}</code></pre>

<blockquote class="warning"><strong>cache 不是状态</strong>。它必须是"输入相同则输出相同"的 memoization。</blockquote>

<h3>11.4 完整实例：FlowLayout（标签流换行）</h3>

<pre><code class="language-swift">// iOS 16+
struct FlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8
    var alignment: HorizontalAlignment = .leading

    struct Row {
        var range: Range&lt;Int&gt;
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
            if !rowSizes.isEmpty && needed &gt; maxWidth {
                cache.rows.append(.init(
                    range: rowStart..&lt;i,
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
                range: rowStart..&lt;subviews.endIndex,
                sizes: rowSizes,
                width: rowWidth,
                height: rowHeight
            ))
            totalHeight += rowHeight
            totalWidth = max(totalWidth, rowWidth)
        }
        cache.totalSize = CGSize(width: totalWidth, height: totalHeight)
    }
}</code></pre>

<h3>11.5 完整实例：RadialLayout（圆形菜单）</h3>

<pre><code class="language-swift">// iOS 16+
struct RadialLayout: Layout {
    var startAngle: Angle = .degrees(-90)
    var clockwise: Bool = true

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let side = min(
            proposal.width ?? 200,
            proposal.height ?? 200
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
        let radius = (min(bounds.width, bounds.height) - maxChild) / 2

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
}</code></pre>

<p>使用：</p>

<pre><code class="language-swift">RadialLayout(startAngle: .degrees(-90)) {
    ForEach(speeds, id: \.self) { speed in
        SpeedChip(speed: speed)
    }
}
.frame(width: 240, height: 240)
.animation(.spring(duration: 0.45, bounce: 0.3), value: speeds.count)</code></pre>

<h3>11.6 AnyLayout 切换 + Spring 动画</h3>

<p><code>AnyLayout</code>（iOS 16+）类型擦除，让你在 <strong>同一组子 view</strong> 上切换布局策略。条件：</p>

<ol>
<li>子 view 的 <strong>identity 必须保持稳定</strong>（用 <code>ForEach(id:)</code> 或显式 <code>.id()</code>）</li>
<li>把 <code>AnyLayout</code> 实例直接当 view builder 调用，不要用 <code>if/else</code> 分别写两个容器</li>
</ol>

<pre><code class="language-swift">// iOS 16+
struct EpisodeGalleryView: View {
    enum Mode: Hashable { case list, grid, radial }
    @State private var mode: Mode = .list
    let episodes: [Episode]

    private var layout: AnyLayout {
        switch mode {
        case .list:   return AnyLayout(VStackLayout(spacing: 12))
        case .grid:   return AnyLayout(FlowLayout(hSpacing: 12, vSpacing: 12))
        case .radial: return AnyLayout(RadialLayout())
        }
    }

    var body: some View {
        layout {
            ForEach(episodes) { ep in
                EpisodeCard(episode: ep)
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.28), value: mode)
        .padding(AnycastSpacing.pageH)
    }
}</code></pre>

<h3>11.7 .geometryGroup() 与 matchedGeometryEffect</h3>

<p>iOS 17 引入 <code>.geometryGroup()</code>。问题场景：父 view 在动画期间改变自己的 frame，子 view 又用 <code>matchedGeometryEffect</code> 绑定到另一棵子树——SwiftUI 默认会把"父位移 + 子位移"展平成单次插值，导致 jitter。</p>

<pre><code class="language-swift">// iOS 17+
ZStack {
    if expanded {
        DetailCard(episode: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
    } else {
        MiniCard(episode: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
    }
}
.geometryGroup()
.animation(.spring(duration: 0.5, bounce: 0.25), value: expanded)</code></pre>

<h3>11.8 explicitAlignment / ViewSpacing / anchor</h3>

<p><code>explicitAlignment(of:in:...)</code> 让你的 Layout 暴露给外层 alignment guide 系统。</p>

<p><code>spacing(subviews:cache:)</code> 返回 <code>ViewSpacing</code>，告诉 <strong>父级</strong>"我和你之间四条边各应留多少"。</p>

<p><code>place(at:anchor:proposal:)</code> 的 <code>anchor</code> 控制"point 指向 subview 的哪个角"。常用：<code>.topLeading</code>、<code>.center</code>、<code>.firstTextBaseline</code>。</p>

<h3>11.9 性能与 ScrollView 边界</h3>

<table>
<thead><tr><th>场景</th><th>能用 Layout 吗</th><th>替代</th></tr></thead>
<tbody>
<tr><td>10–200 个 chip 一次性显示</td><td>OK，FlowLayout + cache</td><td>—</td></tr>
<tr><td>1000+ 元素瀑布流</td><td>不要，全量 sizeThatFits 会卡</td><td>LazyVGrid + 自定义 GridItem</td></tr>
<tr><td>水平无限滚动 carousel</td><td>不要</td><td><code>LazyHStack</code> in <code>ScrollView</code></td></tr>
<tr><td>Sheet detent 内的小型自适应栅格</td><td>OK</td><td>—</td></tr>
</tbody></table>

<p>本质：<code>Layout</code> 是 <strong>eager</strong> 的——它对所有 subviews 调用 <code>sizeThatFits</code>。<code>LazyHStack/LazyVGrid</code> 是 <strong>lazy</strong> 的——只测量可见。</p>

<h3>11.10 在 Layout 内做 spring 动画</h3>

<pre><code class="language-swift">// iOS 16+
struct RadialLayout: Layout, Animatable {
    var startAngle: Angle
    var radius: CGFloat

    var animatableData: AnimatablePair&lt;Double, CGFloat&gt; {
        get { AnimatablePair(startAngle.radians, radius) }
        set {
            startAngle = .radians(newValue.first)
            radius = newValue.second
        }
    }
}

RadialLayout(startAngle: .degrees(spin), radius: r) { ... }
    .animation(.spring(duration: 0.7, bounce: 0.3), value: spin)</code></pre>

<h3>11.11 iOS 18 / iOS 26 增量</h3>

<ul>
<li><strong>iOS 18</strong>：<code>Layout</code> 协议本身 API 没新增，但 <code>.animation</code> 引入了 <code>CustomAnimation</code> 协议</li>
<li><strong>iOS 18</strong>：<code>ScrollView</code> 新增 <code>.containerRelativeFrame</code></li>
<li><strong>iOS 26（Liquid Glass）</strong>：<code>Layout</code> 与 <code>.glassEffectContainer</code> 的合作</li>
<li><strong>iOS 26</strong>：<code>ProposedViewSize</code> 新增了对 <code>contentMargins</code> 的隐式传递</li>
</ul>

<blockquote class="warning"><strong>踩坑速查 / Pitfalls</strong>
<ul>
<li><strong>cache 不是 state</strong>：只放可由输入推导的 memoization</li>
<li><strong>proposal 三态必须区分</strong>：直接 <code>proposal.width ?? 100</code> 当默认值会塌成 100pt</li>
<li><strong>.unspecified 提案传递</strong>：<code>subviews[i].sizeThatFits(.unspecified)</code> 测出的是子的"理想大小"</li>
<li><strong>place 必须给所有 subviews 落位</strong>：漏掉一个会有鬼影</li>
<li><strong>AnyLayout 切换无动画</strong>：99% 是 ForEach 没带 stable id</li>
<li><strong>RadialLayout 在 List/Form row 里塌成 0</strong></li>
<li><strong>Layout 内嵌 GeometryReader</strong>：GeometryReader 会向父级要 infinity，污染 sizing</li>
<li><strong>cache invalidation</strong>：用 proposal width 做 cache key，宽度变了就重算</li>
<li><strong>geometryGroup vs drawingGroup</strong>：前者影响坐标系合成；后者把子树光栅化</li>
<li><strong>Liquid Glass 容器内 Layout 的 frame 不能跳变</strong>：iOS 26 的 glass morph 需要连续插值</li>
</ul>
</blockquote>