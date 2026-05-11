<h3>8. ScrollView 动效：iOS 17 新 API + visualEffect 全景</h3>

<p>iOS 17（WWDC23 Session 10148 <em>Beyond scroll views</em>）一次性补齐了 SwiftUI ScrollView 长期缺失的能力：滚动驱动的转场、目标对齐、容器相对尺寸、可读取 GeometryProxy 的 visualEffect。iOS 18（WWDC24 Session 10148 <em>SwiftUI essentials</em> + 10160 <em>What's new in SwiftUI</em>）又补上 onScrollGeometryChange / onScrollPhaseChange / onScrollVisibilityChange 这三个观察类 API。</p>

<h4>8.1 ScrollTransition：滚动相位驱动的转场</h4>

<p><code>.scrollTransition(_:axis:transition:)</code>（iOS 17+）让每一个 child view 拿到自己的 <code>ScrollTransitionPhase</code>：</p>

<ul>
<li><code>.topLeading</code> — 还没进 visible region（在顶/左）</li>
<li><code>.identity</code> — 完全可见，处于 transition 不施加任何变化的"基准态"</li>
<li><code>.bottomTrailing</code> — 已经离开 visible region（在底/右）</li>
</ul>

<p>phase 提供 <code>isIdentity</code> 布尔与 <code>value: Double</code>（-1...1，<code>topLeading=-1, identity=0, bottomTrailing=1</code>），适合做插值。</p>

<pre><code class="language-swift">// iOS 17+
ScrollView(.horizontal) {
    LazyHStack(spacing: 16) {
        ForEach(episodes) { ep in
            EpisodeCard(ep: ep)
                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                    content
                        .opacity(phase.isIdentity ? 1 : 0.4)
                        .scaleEffect(phase.isIdentity ? 1 : 0.85)
                        .rotation3DEffect(
                            .degrees(phase.value * -20),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                }
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.viewAligned)
</code></pre>

<h4>8.2 .interactive vs .animated 配置</h4>

<table>
<thead><tr><th>Configuration</th><th>语义</th><th>典型用途</th></tr></thead>
<tbody>
<tr><td><code>.interactive</code></td><td>跟随手指实时插值</td><td>carousel 缩放、视差、模糊渐变</td></tr>
<tr><td><code>.animated</code>（默认）</td><td>phase 切换时走 spring 动画</td><td>淡入淡出、单次 pop-in</td></tr>
<tr><td><code>.identity</code></td><td>不做任何效果（占位/调试用）</td><td>条件 disable</td></tr>
</tbody>
</table>

<p><strong>threshold</strong>：默认 <code>.visible</code>，可改 <code>.visible(0.5)</code>（50% 可见）或 <code>.centered</code>（中心进入）。</p>

<h4>8.3 containerRelativeFrame：让 child 占容器比例</h4>

<pre><code class="language-swift">// iOS 17+ — 一屏显示 1.2 张卡片，spacing 12
ScrollView(.horizontal) {
    LazyHStack(spacing: 12) {
        ForEach(shows) { show in
            ShowCard(show: show)
                .containerRelativeFrame(
                    .horizontal,
                    count: 1, span: 1, spacing: 12,
                    alignment: .center
                )
        }
    }
    .scrollTargetLayout()
}
.contentMargins(.horizontal, 24, for: .scrollContent)
.scrollTargetBehavior(.viewAligned)
</code></pre>

<p><strong>count / span</strong>：把容器分 <code>count</code> 份，child 占 <code>span</code> 份。<code>count: 5, span: 2</code> 表示一屏显示 2.5 张。</p>

<h4>8.4 scrollTargetLayout + scrollTargetBehavior</h4>

<table>
<thead><tr><th>Behavior</th><th>行为</th></tr></thead>
<tbody>
<tr><td><code>.viewAligned</code></td><td>对齐到 layout 内的 view 边界</td></tr>
<tr><td><code>.viewAligned(limitBehavior: .alwaysByOne)</code></td><td>每次 swipe 最多前进一格（iOS 17.4+）</td></tr>
<tr><td><code>.paging</code></td><td>整屏分页</td></tr>
<tr><td>自定义</td><td>实现 <code>ScrollTargetBehavior</code> 协议</td></tr>
</tbody>
</table>

<pre><code class="language-swift">// iOS 17+ — 自定义 snap：永远停在最近的 80pt 倍数
struct GridSnap: ScrollTargetBehavior {
    let step: CGFloat = 80
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let snapped = (target.rect.minX / step).rounded() * step
        target.rect.origin.x = snapped
    }
}

ScrollView(.horizontal) { /* ... */ }
    .scrollTargetBehavior(GridSnap())
</code></pre>

<h4>8.5 scrollPosition：编程式滚动到 id</h4>

<pre><code class="language-swift">// iOS 17+
@State private var visibleEpisodeID: Episode.ID?

ScrollView(.horizontal) {
    LazyHStack { ForEach(episodes) { EpisodeCard(ep: $0).id($0.id) } }
        .scrollTargetLayout()
}
.scrollPosition(id: $visibleEpisodeID)
.scrollTargetBehavior(.viewAligned)

Button("Jump to last") {
    withAnimation { visibleEpisodeID = episodes.last?.id }
}
</code></pre>

<p>iOS 18 升级为 <code>.scrollPosition(_:anchor:)</code>，参数是 <code>ScrollPosition</code> struct，可表达"id / edge / offset"三种位置且可读可写：</p>

<pre><code class="language-swift">// iOS 18+
@State private var position = ScrollPosition(edge: .top)

ScrollView { /* ... */ }
    .scrollPosition($position)

Button("Bottom") { position.scrollTo(edge: .bottom) }
Button("Offset 500") { position.scrollTo(y: 500) }

if let offset = position.point?.y { /* ... */ }
</code></pre>

<h4>8.6 visualEffect：拿到 GeometryProxy 但不改 layout</h4>

<p><code>.visualEffect { content, geometryProxy in ... }</code>（iOS 17+）是过去三年用 GeometryReader 套 ZStack 的终结者。它在渲染阶段执行，不参与 layout pass，因此不会触发布局抖动。</p>

<pre><code class="language-swift">// iOS 17+ — sticky shrink header
ScrollView {
    Color.clear.frame(height: 0)
        .background(alignment: .top) { Header() }
        .visualEffect { content, proxy in
            let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
            return content
                .scaleEffect(y &gt; 0 ? 1 + y / 800 : 1, anchor: .top)
                .offset(y: y &gt; 0 ? -y : 0)
        }
    LazyVStack { /* episodes */ }
}
</code></pre>

<p><strong>关键</strong>：visualEffect 返回的必须是 <code>some VisualEffect</code>，可链式叠 <code>.scaleEffect / .offset / .blur / .opacity / .rotationEffect / .brightness / .colorMultiply / .grayscale</code>。<strong>不能</strong>调用任意 modifier。</p>

<h4>8.7 iOS 18+ 三个观察 API</h4>

<pre><code class="language-swift">// iOS 18+ — 监听任意 scroll metric
@State private var offsetY: CGFloat = 0

ScrollView { /* ... */ }
    .onScrollGeometryChange(for: CGFloat.self) { geo in
        geo.contentOffset.y + geo.contentInsets.top
    } action: { _, newValue in
        offsetY = newValue
    }
</code></pre>

<p><code>onScrollGeometryChange</code> 的第一个参数是要观测的 <strong>Equatable</strong> 类型——闭包从 <code>ScrollGeometry</code>（含 contentOffset / contentSize / containerSize / contentInsets / visibleRect / bounds）抽出关心的部分；只有该值变化才触发 action，自带 dedupe。</p>

<pre><code class="language-swift">// iOS 18+ — phase change
.onScrollPhaseChange { oldPhase, newPhase in
    switch newPhase {
    case .idle:          haptics.idle()
    case .tracking:      hideChrome()
    case .interacting:   break
    case .decelerating:  break
    case .animating:     break
    @unknown default:    break
    }
}

// iOS 18+ — child 进入/离开 viewport
.onScrollVisibilityChange(threshold: 0.5) { isVisible in
    if isVisible { analytics.log("card_seen") }
}
</code></pre>

<h4>8.8 边距 / clip / 滚动条</h4>

<table>
<thead><tr><th>Modifier</th><th>iOS</th><th>说明</th></tr></thead>
<tbody>
<tr><td><code>.contentMargins(edges:length:for:)</code></td><td>17+</td><td>给 scrollContent / scrollIndicators 加 margin</td></tr>
<tr><td><code>.scrollClipDisabled()</code></td><td>17+</td><td>关掉 ScrollView 默认裁剪</td></tr>
<tr><td><code>.safeAreaPadding(_:)</code></td><td>17+</td><td>给 safeArea 加 padding</td></tr>
<tr><td><code>.scrollIndicators(.hidden)</code></td><td>16+</td><td>隐藏滚动条</td></tr>
<tr><td><code>.scrollDisabled(_)</code></td><td>16+</td><td>条件禁用滚动</td></tr>
<tr><td><code>.scrollBounceBehavior(.basedOnSize)</code></td><td>16.4+</td><td>内容不超 viewport 时不弹簧</td></tr>
</tbody>
</table>

<h4>8.9 经典模式 1：Carousel 卡片</h4>

<pre><code class="language-swift">// iOS 17+ — Anycast Inbox 横向卡片
struct EpisodeCarousel: View {
    let episodes: [Episode]
    @State private var snappedID: Episode.ID?

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: AnycastSpacing.gap) {
                ForEach(episodes) { ep in
                    EpisodeCard(ep: ep)
                        .containerRelativeFrame(
                            .horizontal,
                            count: 10, span: 8, spacing: AnycastSpacing.gap
                        )
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                .scaleEffect(1 - abs(phase.value) * 0.08)
                                .opacity(1 - abs(phase.value) * 0.4)
                        }
                        .id(ep.id)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, AnycastSpacing.pageH, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: $snappedID)
        .scrollIndicators(.hidden)
    }
}
</code></pre>

<h4>8.10 经典模式 2：Parallax Header</h4>

<pre><code class="language-swift">// iOS 17+ — 节目详情顶图视差 + 下拉放大
struct ShowDetailParallax: View {
    let show: Show
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(show.artwork)
                    .resizable().scaledToFill()
                    .frame(height: 320)
                    .clipped()
                    .visualEffect { content, proxy in
                        let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        return content
                            .scaleEffect(
                                y &gt; 0 ? 1 + y / 320 : 1,
                                anchor: .bottom
                            )
                            .offset(y: y &gt; 0 ? -y / 2 : -y / 3)
                    }

                EpisodeListSection(show: show)
                    .padding(.top, AnycastSpacing.sectionGap)
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}
</code></pre>

<h4>8.11 经典模式 3：Scroll-Driven Blur Nav Bar</h4>

<pre><code class="language-swift">// iOS 18+ — 滚动到一定 offset 后导航栏从透明变模糊
struct LibraryView: View {
    @State private var blurAmount: CGFloat = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AnycastSpacing.gap) {
                ForEach(subscriptions) { ShowRow(show: $0) }
            }
            .padding(AnycastSpacing.pageH)
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y + geo.contentInsets.top
        } action: { _, y in
            blurAmount = min(max(y / 80, 0), 1)
        }
        .overlay(alignment: .top) {
            NavBar(title: "Library")
                .background(.ultraThinMaterial.opacity(blurAmount))
                .background(AnycastColor.sand1.opacity(blurAmount * 0.6))
                .animation(.smooth(duration: 0.2), value: blurAmount)
        }
    }
}
</code></pre>

<h4>8.12 老 API：ScrollViewReader</h4>

<p>iOS 14 起的 <code>ScrollViewReader { proxy in ... proxy.scrollTo(id, anchor: .top) }</code> 仍然有效，但只能写不能读，且必须包裹在 ScrollView 外面。iOS 17 起优先用 <code>.scrollPosition</code>。</p>

<h4>8.13 性能：和 LazyVStack / LazyHGrid 配合</h4>

<ul>
<li><strong>Lazy 容器是必需的</strong>：scrollTransition 给每个 child 加 effect，非 lazy 一次实例化几百个会卡</li>
<li><strong>id 稳定</strong>：<code>ForEach</code> 用 stable Identifiable.id</li>
<li><strong>visualEffect 内部不要分配</strong>：closure 每帧都跑，不要 <code>let formatter = DateFormatter()</code> 这类</li>
<li><strong>onScrollGeometryChange dedupe</strong>：observed type 一定是 Equatable 且粒度合适</li>
<li><strong>scrollTransition 的 threshold</strong> 不影响性能但影响节奏感</li>
<li><strong>ContainerRelativeFrame 不要嵌套</strong></li>
</ul>

<h4>8.14 iOS 26 新增</h4>

<ul>
<li><strong>Liquid Glass 与 ScrollView 的天然耦合</strong>：<code>.glassEffect()</code> 套在 overlay nav bar 上，配合 <code>onScrollGeometryChange</code> 驱动 <code>tint</code> / <code>intensity</code></li>
<li><strong>ScrollEdgeEffectStyle</strong>（iOS 26）：<code>.scrollEdgeEffectStyle(.soft, for: .top)</code></li>
<li><strong>scrollInputBehavior(_:for:)</strong>（iOS 26）</li>
<li><strong>视觉刷新</strong>：<code>.scrollIndicators(.automatic)</code> 在 iOS 26 自动跟随 Liquid Glass 折射</li>
</ul>

<blockquote class="warning">
<p><strong>踩坑速查 / Pitfalls</strong></p>
<ul>
<li><strong>scrollTargetLayout 一定要写</strong>：少了它 <code>.scrollTargetBehavior(.viewAligned)</code> 会无声失效</li>
<li><strong>containerRelativeFrame 的 spacing 必须 = LazyHStack spacing</strong></li>
<li><strong>scrollClipDisabled 不配 contentMargins 等于自杀</strong>：边缘 child 会画到 ScrollView 外面</li>
<li><strong>visualEffect 里读 frame 的 CoordinateSpace</strong>：用 <code>.scrollView(axis:)</code> 而不是 <code>.global</code></li>
<li><strong>visualEffect 不能改 layout</strong>：里面调 <code>.frame(width:)</code> 不会报错但完全不生效</li>
<li><strong>scrollPosition 双向绑定的写入要在 withAnimation 内</strong></li>
<li><strong>onScrollPhaseChange 的 .animating 包含 scrollPosition 触发的程序滚动</strong></li>
<li><strong>onScrollGeometryChange 不要 observe CGFloat 全精度</strong>：先 round / 量化再返回</li>
<li><strong>scrollTransition + drag gesture 冲突</strong></li>
<li><strong>iOS 17.0 vs 17.4 行为差异</strong>：<code>.viewAligned(limitBehavior: .alwaysByOne)</code> 是 17.4+</li>
<li><strong>ScrollViewReader 与 .scrollPosition 不要混用</strong></li>
<li><strong>contentMargins for: 参数选错</strong>：<code>.scrollContent</code> 影响实际内容布局；<code>.scrollIndicators</code> 只缩进滚动条</li>
</ul>
</blockquote>