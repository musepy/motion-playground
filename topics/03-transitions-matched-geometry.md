<h3>3.1 .transition() 修饰符的本质</h3>

<p><code>.transition()</code> 是 SwiftUI 描述 view 在 <strong>插入</strong>（insertion）和 <strong>移除</strong>（removal）时如何动画化的修饰符。它本身不触发动画——动画由外层的 <code>withAnimation</code> 或 <code>.animation()</code> 提供，transition 只声明"用什么样式过渡"。</p>

<p>触发条件本质上是 view tree 的 identity 变化：if/else 分支切换、ForEach 数组增删、optional 解包变化、<code>.id()</code> 修饰符值改变。SwiftUI diff 时如果发现某个 view 从树里消失（或新出现），就会查它身上的 transition 修饰符并执行对应阶段。</p>

<pre><code class="language-swift">// iOS 13+
struct ToastDemo: View {
    @State private var show = false
    var body: some View {
        VStack {
            Button("Toggle") { withAnimation(.spring) { show.toggle() } }
            if show {
                Text("Saved")
                    .padding()
                    .background(.regularMaterial, in: .capsule)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}</code></pre>

<blockquote><p>关键点：<code>withAnimation</code> 必须包裹的是<strong>触发 identity 变化</strong>的状态写入。如果状态变化和 transition view 不在同一个 update cycle 里，transition 会瞬切——这是新人最常见的问题。</p></blockquote>

<h3>3.2 内建 transition 一览</h3>

<table>
<thead><tr><th>Transition</th><th>iOS</th><th>效果</th><th>典型用途</th></tr></thead>
<tbody>
<tr><td><code>.identity</code></td><td>13+</td><td>不动画，直接出现/消失</td><td>覆盖默认</td></tr>
<tr><td><code>.opacity</code></td><td>13+</td><td>淡入淡出（默认 transition）</td><td>通用</td></tr>
<tr><td><code>.slide</code></td><td>13+</td><td>从左 insertion，到右 removal</td><td>List row</td></tr>
<tr><td><code>.move(edge:)</code></td><td>13+</td><td>从指定边滑入/滑出</td><td>Toast、底部条</td></tr>
<tr><td><code>.scale</code></td><td>13+</td><td>从 0 缩放到 1</td><td>icon、勋章</td></tr>
<tr><td><code>.scale(scale:anchor:)</code></td><td>13+</td><td>指定起始 scale 和锚点</td><td>从某点弹出</td></tr>
<tr><td><code>.offset(_:)</code></td><td>13+</td><td>位移变化</td><td>精确控制位置</td></tr>
<tr><td><code>.push(from:)</code></td><td>17+</td><td>双向 push（旧的推走、新的进入）</td><td>步骤切换</td></tr>
<tr><td><code>.blurReplace</code></td><td>17+</td><td>模糊+缩放+淡化</td><td>iOS 17 新原生美感</td></tr>
<tr><td><code>.symbolEffect</code></td><td>17+</td><td>SF Symbol 内部动画</td><td>icon 变形</td></tr>
</tbody>
</table>

<pre><code class="language-swift">// iOS 17+ — push 和 blurReplace 是新增的双向 transition
struct StepCard: View {
    @State private var step = 0
    var body: some View {
        VStack {
            Group {
                if step == 0 { Text("Step 1") }
                else if step == 1 { Text("Step 2") }
                else { Text("Done").bold() }
            }
            .font(.largeTitle)
            .transition(.push(from: .trailing))   // 新内容从右推入，旧的推到左

            Button("Next") {
                withAnimation(.snappy) { step = (step + 1) % 3 }
            }
        }
    }
}</code></pre>

<h3>3.3 组合与非对称：combined / asymmetric</h3>

<p><code>.combined(with:)</code> 把多个 transition 叠加（同时进行），<code>.asymmetric(insertion:removal:)</code> 让出现和消失走不同样式——这两个组合起来能覆盖 95% 的常见场景。</p>

<pre><code class="language-swift">// iOS 13+
extension AnyTransition {
    static var dropIn: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.92, anchor: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }
}

// 用法
NotificationBanner()
    .transition(.dropIn)</code></pre>

<h3>3.4 AnyTransition.modifier(active:identity:) 自定义</h3>

<p>iOS 13–16 的自定义 transition 唯一手段：传两个 <code>ViewModifier</code>——<code>active</code> 是"消失/未出现"状态，<code>identity</code> 是"完全显示"状态。SwiftUI 在两者间插值。</p>

<pre><code class="language-swift">// iOS 13+
struct ScaleBlurModifier: ViewModifier {
    let amount: Double
    func body(content: Content) -> some View {
        content
            .scaleEffect(1 - amount * 0.2)
            .blur(radius: amount * 8)
            .opacity(1 - amount)
    }
}

extension AnyTransition {
    static var scaleBlur: AnyTransition {
        .modifier(
            active: ScaleBlurModifier(amount: 1),
            identity: ScaleBlurModifier(amount: 0)
        )
    }
}</code></pre>

<h3>3.5 iOS 17+ Transition 协议——拿到 phase</h3>

<p><code>AnyTransition</code> 的限制是只能在 active/identity 两点插值，搞不出"先弹出再回弹"这种多阶段。iOS 17 的 <code>Transition</code> 协议引入 <code>TransitionPhase</code>（<code>.willAppear / .identity / .didDisappear</code>），<code>body(content:phase:)</code> 可以根据 phase 给完全不同的修饰：</p>

<pre><code class="language-swift">// iOS 17+
struct BounceTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(phase.isIdentity ? 1 : 0.3)
            .opacity(phase.isIdentity ? 1 : 0)
            .rotationEffect(.degrees(phase == .willAppear ? -15 : (phase == .didDisappear ? 15 : 0)))
            .blur(radius: phase.isIdentity ? 0 : 6)
    }
}

extension Transition where Self == BounceTransition {
    static var bounce: BounceTransition { BounceTransition() }
}

// 用法
Image(systemName: "checkmark.circle.fill")
    .font(.system(size: 80))
    .transition(.bounce)</code></pre>

<p>参考：WWDC23 <em>Session 10157 "Wind your way through advanced animations in SwiftUI"</em> 详细演示了 Transition 协议的多阶段能力，以及与 <code>PhaseAnimator</code> 的协同。</p>

<h3>3.6 ContentTransition——值变化的过渡</h3>

<p>和 <code>.transition()</code>（修饰 view 出现/消失）不同，<code>.contentTransition()</code> 修饰的是<strong>同一个 view 内部内容值变化</strong>的过渡。最常见的场景是数字滚动、SF Symbol 替换：</p>

<pre><code class="language-swift">// iOS 16+ 数字插值；iOS 17+ symbolEffect 和更丰富的 numeric
struct PriceLabel: View {
    @State private var price: Double = 19.9
    var body: some View {
        VStack(spacing: 24) {
            Text(price, format: .currency(code: "USD"))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: price))   // iOS 17+
                .animation(.snappy, value: price)

            Image(systemName: price > 50 ? "flame.fill" : "leaf.fill")
                .font(.system(size: 40))
                .contentTransition(.symbolEffect(.replace))      // iOS 17+

            Stepper("Price", value: $price, in: 0...100, step: 5.5)
        }.padding()
    }
}</code></pre>

<table>
<thead><tr><th>ContentTransition</th><th>iOS</th><th>说明</th></tr></thead>
<tbody>
<tr><td><code>.identity</code></td><td>16+</td><td>无过渡</td></tr>
<tr><td><code>.opacity</code></td><td>16+</td><td>淡入淡出</td></tr>
<tr><td><code>.interpolate</code></td><td>16+</td><td>SwiftUI 尝试逐属性插值</td></tr>
<tr><td><code>.numericText(value:)</code></td><td>17+</td><td>数字滚轮效果，传 value 给方向判断</td></tr>
<tr><td><code>.symbolEffect(.replace)</code></td><td>17+</td><td>SF Symbol 智能替换</td></tr>
</tbody>
</table>

<h3>3.7 matchedGeometryEffect——同源 view 之间的"传送门"</h3>

<p><code>matchedGeometryEffect(id:in:properties:anchor:isSource:)</code> 让 SwiftUI 把同一 namespace 下、同 id 的两个 view 的几何属性（frame / position / size）<strong>桥接起来</strong>。当 view tree 切换时，SwiftUI 不是把 source view "搬运"过去，而是<strong>把 target 的几何属性插值到 source 的值</strong>，视觉上像传送。</p>

<p>关键参数：</p>

<ul>
<li><code>id</code>：标识符，必须在 namespace 内唯一且<strong>同一时刻只有一个 isSource = true 的 view</strong></li>
<li><code>in:</code>：<code>Namespace.ID</code>，由 <code>@Namespace</code> 提供</li>
<li><code>properties</code>：<code>.frame</code>（默认）/ <code>.position</code> / <code>.size</code> — 控制哪些属性被匹配</li>
<li><code>anchor</code>：决定如何把目标 view 对齐到几何区域</li>
<li><code>isSource</code>：默认 <code>true</code>。决定谁提供几何"权威"，跨 view tree 切换时通常都 true，由是否在场决定真实 source</li>
</ul>

<pre><code class="language-swift">// iOS 14+ — 经典的 hero animation：cell 展开成详情
struct HeroEpisode: View {
    @Namespace private var ns
    @State private var expanded: Episode?
    let items: [Episode] = .sample

    var body: some View {
        ZStack {
            // 列表态
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 160))], spacing: 16) {
                    ForEach(items) { ep in
                        if expanded?.id != ep.id {
                            EpisodeCard(ep: ep)
                                .matchedGeometryEffect(id: ep.id, in: ns)
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                                        expanded = ep
                                    }
                                }
                        } else {
                            // 占位，保持布局
                            Color.clear.frame(height: 200)
                        }
                    }
                }.padding()
            }

            // 详情态
            if let ep = expanded {
                EpisodeDetail(ep: ep)
                    .matchedGeometryEffect(id: ep.id, in: ns)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.linear(duration: 0.001)),
                        removal: .opacity.animation(.linear(duration: 0.2))
                    ))
                    .zIndex(1)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                            expanded = nil
                        }
                    }
            }
        }
    }
}</code></pre>

<p>这个套路的关键：列表 cell 在 expanded 时换成 <code>Color.clear</code> 占位（保留布局），详情态里给同 id 的 view 加 <code>matchedGeometryEffect</code>——SwiftUI 自动从 cell 的 frame 插值到详情 frame。<code>zIndex(1)</code> 防止动画过程中详情被遮挡。</p>

<h3>3.8 iOS 18 NavigationTransition：.zoom + matchedTransitionSource</h3>

<p>iOS 18 把 hero animation "官方化"——<code>NavigationStack</code> push 和 <code>sheet/fullScreenCover</code> 都支持 <code>.navigationTransition(.zoom(sourceID:in:))</code>。它内部基于 matchedGeometryEffect 但帮你处理了所有边界情况（zIndex、interactive dismiss、interruption）。</p>

<pre><code class="language-swift">// iOS 18+ — 推荐用法
struct ZoomNavDemo: View {
    @Namespace private var ns
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 140))]) {
                    ForEach(Episode.sample) { ep in
                        NavigationLink(value: ep) {
                            EpisodeCard(ep: ep)
                                .matchedTransitionSource(id: ep.id, in: ns)
                        }
                    }
                }
            }
            .navigationDestination(for: Episode.self) { ep in
                EpisodeDetail(ep: ep)
                    .navigationTransition(.zoom(sourceID: ep.id, in: ns))
            }
        }
    }
}</code></pre>

<p>同样的 API 用在 sheet 上：</p>

<pre><code class="language-swift">// iOS 18+
struct ZoomSheetDemo: View {
    @Namespace private var ns
    @State private var openedEp: Episode?
    var body: some View {
        ScrollView {
            ForEach(Episode.sample) { ep in
                Button { openedEp = ep } label: {
                    EpisodeCard(ep: ep)
                        .matchedTransitionSource(id: ep.id, in: ns)
                }
            }
        }
        .sheet(item: $openedEp) { ep in
            EpisodeDetail(ep: ep)
                .navigationTransition(.zoom(sourceID: ep.id, in: ns))
        }
    }
}</code></pre>

<p>参考：WWDC24 <em>Session 10145 "Enhance your UI animations and transitions"</em>。Apple 的 official guidance 是 iOS 18+ 优先使用 zoom navigation transition，旧的 matchedGeometryEffect 路线只在需要更精细控制（比如 mid-animation transform）时才用。</p>

<h3>3.9 自定义 Transition 协议实例</h3>

<p>下面三个是常见的"高级"自定义。都基于 iOS 17+ Transition 协议：</p>

<pre><code class="language-swift">// iOS 17+ — 旋转门效果
struct DoorTransition: Transition {
    var edge: HorizontalEdge = .leading
    func body(content: Content, phase: TransitionPhase) -> some View {
        let angle: Double = phase.isIdentity ? 0 : 90
        content
            .rotation3DEffect(
                .degrees(edge == .leading ? -angle : angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: edge == .leading ? .leading : .trailing,
                perspective: 0.6
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

// iOS 17+ — 3D 翻页（书页效果）
struct PageFlipTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotation3DEffect(
                .degrees(phase == .willAppear ? -180 : (phase == .didDisappear ? 180 : 0)),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.5
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

// iOS 17+ — 拉伸出现（橡皮筋）
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
}</code></pre>

<h3>3.10 多 view 同时 transition 的协调</h3>

<p>当多个 view 在同一帧内被插入/移除时，SwiftUI 默认<strong>同时</strong>给它们应用 transition。要做错峰效果，最干净的工具是 iOS 17+ 的<strong>delay 在 animation 上叠加</strong>，或者用 <code>PhaseAnimator</code> 把单个动画拆成多 phase。如果是 ForEach 里多 row 同进同出，<code>.animation(_, value:)</code> 配合 <code>enumerated()</code> 给每行不同 delay 是经典写法：</p>

<pre><code class="language-swift">// iOS 15+
struct StaggeredList: View {
    @State private var visible = false
    let items = (0..<8).map { "Row \($0)" }
    var body: some View {
        VStack(spacing: 8) {
            if visible {
                ForEach(Array(items.enumerated()), id: \.element) { idx, item in
                    Text(item)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(idx) * 0.06),
                            value: visible
                        )
                }
            }
            Button("Toggle") { visible.toggle() }
        }
    }
}</code></pre>

<h3>3.11 transaction 与 transition 的关系</h3>

<p><code>Transaction</code> 是 SwiftUI 用来携带"本次 update 怎么动画"的容器。<code>.transaction { $0.animation = ... }</code> 可以在 view 链路上覆盖动画曲线——这在你想<strong>对单个 view 的 transition 单独换曲线</strong>，又不想让外层 <code>withAnimation</code> 影响其他兄弟节点时极其有用。</p>

<pre><code class="language-swift">// iOS 13+
struct LayeredAnim: View {
    @State private var on = false
    var body: some View {
        ZStack {
            if on {
                BackgroundDim()
                    .transition(.opacity)
                    .transaction { $0.animation = .easeInOut(duration: 0.4) }

                Card()
                    .transition(.move(edge: .bottom))
                    .transaction { $0.animation = .spring(response: 0.45, dampingFraction: 0.75) }
            }
            Button("Toggle") { withAnimation { on.toggle() } }
        }
    }
}</code></pre>

<p>iOS 17 还提供 <code>.transaction(value:_:)</code> 让 transaction 只在 value 变化时触发，避免误伤兄弟节点的隐式动画。</p>

<h3>3.12 完整 hero animation 范例（matchedGeometryEffect 全套）</h3>

<pre><code class="language-swift">// iOS 17+ — 列表 → 详情，cover art 跨 view tree 传送
struct PodcastHero: View {
    @Namespace private var ns
    @State private var openedID: UUID?
    let shows: [Show] = .sample

    var body: some View {
        ZStack {
            // 列表
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(shows) { show in
                        HStack(spacing: 12) {
                            CoverArt(url: show.artwork)
                                .frame(width: 64, height: 64)
                                .matchedGeometryEffect(
                                    id: "cover-\(show.id)",
                                    in: ns,
                                    isSource: openedID != show.id
                                )
                            VStack(alignment: .leading) {
                                Text(show.title)
                                    .matchedGeometryEffect(
                                        id: "title-\(show.id)",
                                        in: ns,
                                        isSource: openedID != show.id
                                    )
                                Text(show.author).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                                openedID = show.id
                            }
                        }
                    }
                }
            }
            .opacity(openedID == nil ? 1 : 0.3)

            // 详情
            if let id = openedID, let show = shows.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(spacing: 20) {
                        CoverArt(url: show.artwork)
                            .frame(width: 280, height: 280)
                            .matchedGeometryEffect(id: "cover-\(show.id)", in: ns)

                        Text(show.title)
                            .font(.title.bold())
                            .matchedGeometryEffect(id: "title-\(show.id)", in: ns)

                        Text(show.summary)
                            .padding(.horizontal)
                            .transition(.opacity.animation(.easeIn.delay(0.15)))
                    }.padding(.top, 60)
                }
                .background(.regularMaterial)
                .ignoresSafeArea()
                .zIndex(1)
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        openedID = nil
                    }
                }
            }
        }
    }
}</code></pre>

<p>这里 <code>isSource: openedID != show.id</code> 是关键——同一时刻 namespace 内每个 id 只能有一个 source。当详情打开，列表 cell 让出 source 身份，几何由详情提供。</p>

<blockquote class="warning">
<p><strong>踩坑速查 / Pitfalls</strong></p>
<ul>
<li><strong>zIndex 必须显式设</strong>：动画期间，新插入的 view 默认 zIndex 0，可能被同层 sibling 遮挡。hero animation 的 detail view 务必加 <code>.zIndex(1)</code>，否则会看到"穿模"现象。</li>
<li><strong>id 唯一性</strong>：同一 <code>Namespace</code> 内同一时刻不能有两个 view 同 id 且 <code>isSource = true</code>，否则 SwiftUI 行为未定义（通常表现为闪烁、不动画）。在过渡瞬间用 <code>isSource</code> 控制谁是真 source，或者保证旧 source 已从 view tree 移除。</li>
<li><strong>namespace 必须同源</strong>：<code>@Namespace</code> 在 view 重新创建时会重新生成 ID。如果父 view 因为状态变化被 rebuild，namespace 会变，所有 matchedGeometry 失效。所以 namespace 必须放在生命周期稳定的祖先上。</li>
<li><strong>withAnimation 必须包状态写</strong>：触发 transition 的 <code>@State</code> 改动必须在 <code>withAnimation { ... }</code> 块里，而不是 transition view 本身被 <code>.animation()</code> 修饰——后者只动画属性变化，不动画 transition。</li>
<li><strong>ForEach id 不稳定</strong>：用数组下标做 id（<code>ForEach(items.indices)</code>）会让插入/删除时所有 row 都"重新认识自己"，transition 错乱。永远用 <code>Identifiable</code> 或稳定的值。</li>
<li><strong>NavigationStack push 时 matchedGeometryEffect 跨不过去</strong>：iOS 17 之前没有官方跨 navigation 的方式；iOS 18 必须用 <code>navigationTransition(.zoom)</code> + <code>matchedTransitionSource</code>，老的 matchedGeometryEffect 在 push 边界会失效。</li>
<li><strong>sheet 默认动画会盖掉 transition</strong>：sheet/fullScreenCover 自带 presentation 动画。如果你又给 sheet 内容加 <code>.transition()</code>，两者会打架，常见结果是只看到 sheet 默认动画。要么用 <code>.presentationBackgroundInteraction</code> 系列调，要么改用 ZStack + transition 自己撸。</li>
<li><strong>Transition 协议的 phase 容易判错</strong>：<code>.willAppear</code> 是即将出现（动画起点），<code>.didDisappear</code> 是已经消失（动画终点），<code>.identity</code> 是稳定态。判断方向常见错误是用 <code>phase != .identity</code> 当成"动画进行中"——其实进出方向需要分别判断。</li>
<li><strong>contentTransition 不动画 view 替换</strong>：<code>.contentTransition()</code> 修饰的是同一个 view 的 content 变化（比如 <code>Text</code> 内文字、SF Symbol name），如果你换的是不同 view（if/else 切换），它不生效——那种情况要用 <code>.transition()</code>。</li>
<li><strong>numericText 需要 value</strong>：<code>.numericText(value:)</code> 必须传当前数值，SwiftUI 用它判断滚动方向（增大向上滚、减小向下滚）。不传 value 退化成普通替换。</li>
<li><strong>combined 顺序影响插值</strong>：<code>.scale.combined(with: .opacity)</code> 和 <code>.opacity.combined(with: .scale)</code> 视觉上几乎一样，但当组合复杂修饰（带 anchor 的 scale + offset）时，先后顺序决定 transform 矩阵相乘顺序，结果会差。</li>
<li><strong>Anycast 项目特别注意</strong>：本项目用 <code>app.openedEpisode = ep</code> 触发 <code>sheet(item:)</code>，这是 sheet presentation 路径，不能直接套 matchedGeometryEffect；要做 hero animation 要么改成 ZStack + custom transition，要么 iOS 18 的 <code>.navigationTransition(.zoom)</code>（项目已 iOS 26+ 兼容）。</li>
</ul>
</blockquote>