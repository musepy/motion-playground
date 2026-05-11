<h3>1.1 动画的两种触发方式：implicit 与 explicit</h3>

<p>SwiftUI 的动画系统建立在 <strong>"状态变化驱动 UI 重算"</strong> 之上。无论 implicit 还是 explicit，本质都是：当某个 <code>@State</code>/<code>@Published</code> 变化引发 view 重新求值时，差异部分按某条 <code>Animation</code> 曲线插值。区别只在于 <em>"谁来声明用哪条曲线"</em>。</p>

<h4>Implicit Animation（隐式）</h4>

<p>用 <code>.animation(_:value:)</code> 修饰符（iOS 15+ 推荐写法，旧的单参数 <code>.animation(_:)</code> 已 deprecated）。它的语义是：<strong>"当我观察的这个 value 变了，我下面这棵子树里所有可动画属性都按这条曲线插"</strong>。</p>

<pre><code class="language-swift">// iOS 15+
struct PlayButton: View {
    @State private var isPlaying = false
    var body: some View {
        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            .scaleEffect(isPlaying ? 1.2 : 1.0)
            .foregroundStyle(isPlaying ? .orange : .secondary)
            .animation(.snappy(duration: 0.25), value: isPlaying)
            .onTapGesture { isPlaying.toggle() }
    }
}</code></pre>

<h4>Explicit Animation（显式）</h4>

<p><code>withAnimation { ... }</code> 把状态变更包裹起来。语义是：<strong>"这次变更产生的所有差异，全部按这条曲线插"</strong>。它跨 view 边界生效（属于事务级别 Transaction），而 implicit 只对它修饰的 subtree 生效。</p>

<pre><code class="language-swift">// iOS 17+
withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
    appState.openedEpisode = episode   // 触发整个 sheet 弹出动画
}</code></pre>

<h4>选哪个？</h4>

<table>
<thead><tr><th>场景</th><th>建议</th><th>理由</th></tr></thead>
<tbody>
<tr><td>单一 view 的视觉反馈（图标缩放、颜色切换）</td><td>implicit</td><td>声明在最近的 modifier，读起来直观</td></tr>
<tr><td>跨 view、多个状态联动（导航/sheet/list 增删）</td><td>explicit</td><td>一次声明，所有 diff 都用这条曲线</td></tr>
<tr><td>同一帧改 N 个 <code>@State</code>，但只想动其中一个</td><td>explicit + implicit 组合</td><td>用 <code>Transaction.animation = nil</code> 关掉不想动的子树</td></tr>
<tr><td>手势驱动（drag/scrub）</td><td>explicit + <code>.interactiveSpring</code></td><td>需要 inject velocity</td></tr>
</tbody></table>

<p>官方资料：<em>WWDC23 "Animate with springs" (Session 10158)</em>、<em>WWDC23 "Wind your way through advanced animations in SwiftUI" (Session 10157)</em>、Apple Developer Documentation: <code>SwiftUI/View/animation(_:value:)</code>、<code>SwiftUI/withAnimation(_:_:)</code>。</p>

<h3>1.2 Animation 类型大全</h3>

<h4>线性与缓动家族（iOS 13+）</h4>

<ul>
<li><code>.linear(duration:)</code> — 匀速；适合进度条、循环刷新指示，不适合任何"位置变化"。</li>
<li><code>.easeIn(duration:)</code> — 慢起快收；元素离场时用。</li>
<li><code>.easeOut(duration:)</code> — 快起慢收；元素入场时用（用户更早看到结果）。</li>
<li><code>.easeInOut(duration:)</code> — 两端慢中间快；通用过渡，不知道选啥就它。</li>
<li><code>.timingCurve(_:_:_:_:duration:)</code> — 三次贝塞尔，控制点 (c1x, c1y, c2x, c2y)；做 Material Design 风格曲线时用。</li>
</ul>

<pre><code class="language-swift">// iOS 13+
Rectangle()
    .frame(width: expanded ? 300 : 80, height: 80)
    .animation(.timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.4), value: expanded)
    // M3 emphasized 曲线 ≈ (0.2, 0.0, 0, 1.0)，这里调过</code></pre>

<h4>Spring 家族（iOS 13+ 老 API）</h4>

<ul>
<li><code>.interpolatingSpring(stiffness:damping:initialVelocity:)</code> — 物理弹簧的"刚度+阻尼+初速度"参数化，<strong>完成时间不可控</strong>，靠物理模拟自然停下。</li>
<li><code>.spring(response:dampingFraction:blendDuration:)</code> — Apple 后来推的"易调"参数化，<code>response</code> 控总时间感觉，<code>dampingFraction</code> 控反弹。<code>blendDuration</code> 是和上一个 spring 中途切换时的混合时间，绝大多数场景填 0 就行。</li>
<li><code>.interactiveSpring(response:dampingFraction:blendDuration:)</code> — 和上面参数一致，但默认 <code>response = 0.15</code>、<code>dampingFraction = 0.86</code>，<strong>专为手势设计的低延迟弹簧</strong>。</li>
</ul>

<h4>iOS 17+ 新简写：smooth / snappy / bouncy</h4>

<p>WWDC23 重新设计了 spring API（Session 10158 "Animate with springs"），引入<strong>新参数化方式 <code>(duration:bounce:)</code></strong>，把易调性提到最高。</p>

<ul>
<li><code>.smooth</code> — <code>duration: 0.5, bounce: 0</code>，无反弹，平顺到位。</li>
<li><code>.snappy</code> — <code>duration: 0.5, bounce: 0.15</code>，轻微反弹，"利落"。</li>
<li><code>.bouncy</code> — <code>duration: 0.5, bounce: 0.3</code>，明显弹性，"活泼"。</li>
</ul>

<p>三个都接受 <code>(duration:extraBounce:)</code> 形式微调，例如 <code>.snappy(duration: 0.3, extraBounce: 0.1)</code> 把基准 0.15 加到 0.25。</p>

<pre><code class="language-swift">// iOS 17+
struct ToastBanner: View {
    @State private var shown = false
    var body: some View {
        VStack {
            if shown {
                Text("已加入下载队列")
                    .padding()
                    .background(.regularMaterial, in: .capsule)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.snappy, value: shown)
        .onAppear { shown = true }
    }
}</code></pre>

<h3>1.3 新旧 Spring 参数对照</h3>

<p>iOS 17 新简写底层就是 <code>Spring(duration:bounce:)</code>。它和老的 <code>(response:dampingFraction:)</code> 之间数学上是<strong>一一映射</strong>：</p>

<ul>
<li><code>duration</code> ≡ <code>response</code>（都表达"感知动画时长"，单位秒）。</li>
<li><code>bounce</code> 与 <code>dampingFraction</code> 的关系：<code>bounce = 1 - dampingFraction</code>（所以 <code>bounce: 0</code> ↔ <code>dampingFraction: 1.0</code> ↔ critically damped；<code>bounce: 0.3</code> ↔ <code>dampingFraction: 0.7</code>）。</li>
</ul>

<table>
<thead><tr><th>简写</th><th>新参数</th><th>等价旧 spring</th></tr></thead>
<tbody>
<tr><td><code>.smooth</code></td><td><code>(duration: 0.5, bounce: 0)</code></td><td><code>.spring(response: 0.5, dampingFraction: 1.0)</code></td></tr>
<tr><td><code>.snappy</code></td><td><code>(duration: 0.5, bounce: 0.15)</code></td><td><code>.spring(response: 0.5, dampingFraction: 0.85)</code></td></tr>
<tr><td><code>.bouncy</code></td><td><code>(duration: 0.5, bounce: 0.3)</code></td><td><code>.spring(response: 0.5, dampingFraction: 0.7)</code></td></tr>
</tbody></table>

<p>反过来，旧项目里看到 <code>.spring(response: 0.4, dampingFraction: 0.8)</code>，等价于 <code>.spring(duration: 0.4, bounce: 0.2)</code>。</p>

<h3>1.4 Animation 组合：delay / repeat / speed</h3>

<p>Animation 是<strong>不可变值类型</strong>，所有组合都是返回新值的链式调用。顺序无关（除了 <code>.speed</code> 影响后续解释）。</p>

<pre><code class="language-swift">// iOS 13+
Circle()
    .scaleEffect(pulse ? 1.4 : 1.0)
    .opacity(pulse ? 0 : 1)
    .animation(
        .easeOut(duration: 1.0)
            .repeatForever(autoreverses: false)
            .delay(0.2),
        value: pulse
    )
    .onAppear { pulse = true }</code></pre>

<ul>
<li><code>.delay(_:)</code> — 推迟开始，单位秒。Implicit 和 explicit 都生效。</li>
<li><code>.repeatCount(_:autoreverses:)</code> — 整数次重复；<code>autoreverses: true</code> 时正反算两次，所以 <code>repeatCount(3, autoreverses: true)</code> 实际播 1.5 个周期来回。</li>
<li><code>.repeatForever(autoreverses:)</code> — 永久循环，需要在 view 消失或状态切换时主动停（把驱动 value 改回静止值，但 implicit 模式很难"立刻冻住"，常见解法是用 <code>.id()</code> 重建 view）。</li>
<li><code>.speed(_:)</code> — 倍率，<code>0.5</code> 是慢动作，<code>2.0</code> 加速。</li>
</ul>

<h3>1.5 Spring 物理：三套参数化与换算</h3>

<p>iOS 17 引入了<strong>独立的 <code>Spring</code> 值类型</strong>，可以脱离 <code>Animation</code> 单独描述一条物理弹簧，再喂给 <code>Animation.spring(_:)</code> 或 <code>.interactiveSpring(_:)</code>。三种构造方式互相等价：</p>

<pre><code class="language-swift">// iOS 17+
let s1 = Spring(response: 0.5, dampingRatio: 0.8)
let s2 = Spring(duration: 0.5, bounce: 0.2)        // bounce = 1 - dampingRatio
let s3 = Spring(stiffness: 158.0, damping: 20.0, mass: 1.0)
// 三者等价（数值上同一条曲线）

// 直接用 Spring 实例查询任意时刻位置/速度
let pos = s1.value(target: 100, time: 0.2)
let vel = s1.velocity(target: 100, time: 0.2)</code></pre>

<p>底层物理换算（mass 默认 1.0）：</p>

<ul>
<li><strong>stiffness</strong> k = (2π / response)² × mass</li>
<li><strong>damping</strong> c = 4π × dampingRatio × mass / response</li>
</ul>

<p>所以 <code>response: 0.5, dampingRatio: 0.8, mass: 1</code> → <code>k ≈ 158, c ≈ 20.1</code>，正是上面 <code>s3</code>。</p>

<h3>1.6 物理含义直观解释</h3>

<table>
<thead><tr><th>参数</th><th>直观含义</th><th>调大→</th></tr></thead>
<tbody>
<tr><td><code>response</code> / <code>duration</code></td><td>弹簧周期，到位"感觉用了多久"</td><td>整体变慢，更"懒"</td></tr>
<tr><td><code>dampingFraction</code> / <code>dampingRatio</code></td><td>阻尼比，反弹强弱（1.0=刚好不弹，&lt;1 弹，&gt;1 黏）</td><td>越接近 1 越无反弹</td></tr>
<tr><td><code>bounce</code></td><td>= 1 - dampingRatio，反弹强度</td><td>越大越 Q 弹，可以为负（&gt;1 阻尼）</td></tr>
<tr><td><code>mass</code></td><td>"重量"，惯性</td><td>启动更慢、停得更晚，需要更大力</td></tr>
<tr><td><code>stiffness</code> k</td><td>弹簧硬度，回弹力 = -k·x</td><td>来回更快、更刚</td></tr>
<tr><td><code>damping</code> c</td><td>摩擦力 = -c·v</td><td>越大越快停下</td></tr>
</tbody></table>

<p>三种阻尼区间：</p>

<ul>
<li><strong>Underdamped</strong>（dampingRatio &lt; 1）：会过冲、来回振荡。bouncy 风格。</li>
<li><strong>Critically damped</strong>（dampingRatio = 1）：最快"刚好到位"且不过冲。smooth 风格。</li>
<li><strong>Overdamped</strong>（dampingRatio &gt; 1）：像在油里走，缓慢逼近不过冲，会显"肉"。一般避免。</li>
</ul>

<h3>1.7 Velocity 与手势耦合（interactiveSpring 实战）</h3>

<p>从拖拽手势松手时，让动画"接住"最后的速度继续走，是手感的关键。<code>DragGesture</code> 的 <code>onEnded</code> 会给 <code>predictedEndTranslation</code>，但更精细做法是把速度直接喂给 spring：</p>

<pre><code class="language-swift">// iOS 17+
struct DismissibleSheet: View {
    @State private var offsetY: CGFloat = 0
    @GestureState private var dragY: CGFloat = 0

    var body: some View {
        Color.orange
            .ignoresSafeArea()
            .offset(y: offsetY + dragY)
            .gesture(
                DragGesture()
                    .updating($dragY) { value, state, _ in
                        state = max(0, value.translation.height)
                    }
                    .onEnded { value in
                        let v = value.velocity.height                // pt/s
                        let shouldDismiss = value.translation.height > 150 || v > 800
                        let target: CGFloat = shouldDismiss ? 900 : 0
                        withAnimation(.interactiveSpring(response: 0.35,
                                                         dampingFraction: 0.86,
                                                         blendDuration: 0.1)) {
                            offsetY = target
                        }
                        // 注：iOS 17 的 .interactiveSpring 在 withAnimation 内部
                        // 会自动从当前 view 速度采样接续，无需手填 initialVelocity
                    }
            )
    }
}</code></pre>

<p>更老的项目里用 <code>.interpolatingSpring(stiffness:damping:initialVelocity:)</code> 显式传 <code>initialVelocity</code>。iOS 17 之后推荐用 <code>.interactiveSpring</code> + <code>withAnimation</code>，框架会自动续上当前动画速度。</p>

<h3>1.8 完成回调 (iOS 17+)</h3>

<p>iOS 17 新增 <code>withAnimation(_:completionCriteria:_:completion:)</code>，终于能精确知道"这次动画播完了"：</p>

<pre><code class="language-swift">// iOS 17+
@State private var loading = false

func startTask() {
    withAnimation(.smooth(duration: 0.4)) {
        loading = true
    } completion: {
        // logicallyComplete (默认): spring 数值上已到稳态时触发
        Task { await fetch() }
    }
}

// 区分两种判定时机
withAnimation(.bouncy, completionCriteria: .removed) {
    showOverlay = false
} completion: {
    // .removed: transition 完全从 view tree 移除后才触发
    // 适合"等 dismiss 动画结束再 navigate"场景
}</code></pre>

<table>
<thead><tr><th>Criteria</th><th>触发时机</th><th>用途</th></tr></thead>
<tbody>
<tr><td><code>.logicallyComplete</code>（默认）</td><td>动画值数学上到达稳态，但 spring 可能还在"回弹尾巴"</td><td>启动后续逻辑（网络请求、状态切换）</td></tr>
<tr><td><code>.removed</code></td><td>所有视图修改、transition 都彻底完成</td><td>清理 view、链式弹窗</td></tr>
</tbody></table>

<h3>1.9 Transaction API：精确控制动画范围</h3>

<p><code>Transaction</code> 是每次状态变更产生的事务对象，承载 <code>animation</code>、<code>disablesAnimations</code> 等元信息。<code>withAnimation</code> 本质就是包了一层 <code>withTransaction(\.animation, ...)</code>。</p>

<pre><code class="language-swift">// iOS 13+ (transaction modifier 自 iOS 13；扩展能力 iOS 14/15 渐进)
struct EpisodeRow: View {
    let title: String
    @Binding var isFavorite: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? .red : .secondary)
                .transaction { tx in
                    // 即使外层 withAnimation 给了 spring，
                    // 这个心形我也只想要瞬切（避免颜色 lerp 出脏色）
                    tx.animation = nil
                }
        }
    }
}</code></pre>

<pre><code class="language-swift">// iOS 17+ 用 transaction(value:_:) 限定触发条件
.transaction(value: scrubbing) { tx in
    if scrubbing { tx.animation = nil }   // 拖动时不动画，松手时恢复
}</code></pre>

<p><code>Transaction.disablesAnimations</code> 是更强的"全局禁动画"开关，连子 view 自己声明的 implicit animation 都会失效，慎用。</p>

<h3>1.10 修饰符顺序对动画的影响</h3>

<p>SwiftUI modifier 是<strong>从内向外作用</strong>。<code>scaleEffect</code> 后接 <code>rotationEffect</code> 等于"先缩放再旋转"，反过来则是"先旋转再缩放"。动画时这会导致<strong>插值轨迹完全不同</strong>。</p>

<pre><code class="language-swift">// iOS 13+
// A: 先 scale 再 rotate —— 旋转的是"被放大的形状"，扫过区域更大
view
    .scaleEffect(big ? 1.5 : 1.0)
    .rotationEffect(.degrees(big ? 90 : 0))
    .animation(.snappy, value: big)

// B: 先 rotate 再 scale —— 旋转完成后整体放大，路径更"老实"
view
    .rotationEffect(.degrees(big ? 90 : 0))
    .scaleEffect(big ? 1.5 : 1.0)
    .animation(.snappy, value: big)</code></pre>

<p>同理 <code>.offset</code> 在 <code>.rotationEffect</code> 之内 vs 之外：内层会让平移方向"跟着旋转走"，外层则是屏幕坐标系的平移。在做 dock 弹出、card flip 这类组合动画时这是核心要点。</p>

<h3>1.11 iOS 18 / iOS 26 新增能力</h3>

<ul>
<li><strong>iOS 18 (WWDC24 Session 10145 "Enhance your UI animations and transitions")</strong>：
  <ul>
    <li>新的 <code>.transition</code> 协议接口可以读取 <code>phase</code>（identity/willAppear/didDisappear），自定义带阶段的入场/出场。</li>
    <li><code>PhaseAnimator</code> 和 <code>KeyframeAnimator</code>（iOS 17 引入）在 18 上稳定，并新增了与 <code>SymbolEffect</code> 的协同。</li>
    <li>SF Symbols 6 的 <code>.symbolEffect(.wiggle)</code>、<code>.breathe</code>、<code>.rotate</code> 与 <code>SymbolEffectOptions(speed:)</code>。</li>
  </ul>
</li>
<li><strong>iOS 26（Liquid Glass 时代，WWDC25 "Build a SwiftUI app with the new design"、"Meet Liquid Glass" Sessions）</strong>：
  <ul>
    <li><code>.glassEffect()</code> 与 <code>GlassEffectContainer</code> 形变会自动用一条专门优化过的 spring，跨 view 合并/分离时形成"水滴融合"动画。在自定义 spring 时尽量用 <code>.smooth</code>/<code>.snappy</code> 与之协调，不要手填过激 bounce。</li>
    <li>新的 <code>NavigationTransition</code> / <code>matchedTransitionSource</code> / <code>navigationTransition(.zoom(...))</code> 让 push/sheet 共享 hero 元素，底层用 spring 驱动。</li>
    <li><code>Animation</code> 增加了对 reduce-motion 的更细粒度回退支持；建议用 <code>@Environment(\.accessibilityReduceMotion)</code> 在 spring 与 linear 之间切换。</li>
  </ul>
</li>
</ul>

<pre><code class="language-swift">// iOS 17+: PhaseAnimator
struct LoadingDot: View {
    var body: some View {
        Circle()
            .frame(width: 12, height: 12)
            .phaseAnimator([1.0, 0.6, 1.0]) { dot, scale in
                dot.scaleEffect(scale).opacity(scale)
            } animation: { _ in .easeInOut(duration: 0.4) }
    }
}</code></pre>

<pre><code class="language-swift">// iOS 17+: KeyframeAnimator —— 多通道独立时间线
struct LikeBurst: View {
    @State private var trigger = 0
    var body: some View {
        Image(systemName: "heart.fill")
            .foregroundStyle(.red)
            .keyframeAnimator(initialValue: AnimValues(),
                              trigger: trigger) { content, v in
                content.scaleEffect(v.scale).rotationEffect(.degrees(v.angle))
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.6, duration: 0.25, spring: .bouncy)
                    SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
                }
                KeyframeTrack(\.angle) {
                    CubicKeyframe(-15, duration: 0.15)
                    CubicKeyframe(15,  duration: 0.15)
                    CubicKeyframe(0,   duration: 0.20)
                }
            }
            .onTapGesture { trigger += 1 }
    }
    struct AnimValues { var scale = 1.0; var angle = 0.0 }
}</code></pre>

<h3>1.12 implicit vs explicit 的取舍 + 多 @State 同帧的陷阱</h3>

<p>同一帧改多个 <code>@State</code>，又只对其中一个 <code>withAnimation</code>，新手最常翻车。规则：</p>

<ol>
<li>放在 <code>withAnimation</code> 闭包内的<strong>所有</strong> 状态变更，触发的 view diff 都会用这条 animation。</li>
<li>放在闭包外的，沿用各自子树的 implicit <code>.animation(_:value:)</code>；没有就是瞬切。</li>
<li>如果你在 <code>withAnimation</code> 内改了 N 个 state，但只想让 1 个动起来 —— 把不想动的那个的 view 加 <code>.transaction { $0.animation = nil }</code>。</li>
<li>反过来，闭包外改的 state 想动，就在 view 上加 <code>.animation(_:value:)</code>。</li>
</ol>

<pre><code class="language-swift">// iOS 17+
struct MiniPlayerRow: View {
    @State private var expanded = false
    @State private var unread = 0

    var body: some View {
        HStack {
            Text("Episode A")
                .scaleEffect(expanded ? 1.05 : 1.0)
                .animation(.snappy, value: expanded)   // implicit, 只关心 expanded
            Spacer()
            Text("\(unread)")
                .transaction { $0.animation = nil }    // 数字别 lerp
        }
        .onTapGesture {
            withAnimation(.bouncy) {
                expanded.toggle()                      // 这次动
                unread += 1                            // 这次也在 withAnimation 里，
                                                       // 但被 transaction 拦下，瞬切
            }
        }
    }
}</code></pre>

<blockquote class="warning">
<strong>踩坑速查 / Pitfalls</strong>
<ul>
<li><strong>不要用单参数 <code>.animation(_:)</code></strong>（iOS 15 起 deprecated），因为它会监听整个 subtree 的所有变化，频繁误触发；一律用 <code>.animation(_:value:)</code> 显式声明依赖。</li>
<li><strong><code>.repeatForever</code> 切不断</strong>：implicit 模式下把驱动 value 改回去并不会立刻停（动画引擎已经"承诺"了一段曲线）。常见解法是 <code>.id(running)</code> 让 view 随状态重建，或改用 <code>PhaseAnimator</code>/<code>SymbolEffect</code> 这类自带可暂停语义的 API。</li>
<li><strong>Spring 完成时间 ≠ duration</strong>：<code>.spring(duration: 0.5, bounce: 0.3)</code> 的 0.5 是<strong>感知时长</strong>（无反弹时刚好到位），实际尾部回弹会再持续一段。需要等到完全静止用 <code>completion: .removed</code>。</li>
<li><strong>颜色/数字插值产生脏中间态</strong>：红→绿会经过棕色，未读数 3→7 会出现 4/5/6。这种字段加 <code>.transaction { $0.animation = nil }</code> 或 <code>.animation(nil, value: ...)</code>（iOS 17+）。</li>
<li><strong><code>blendDuration</code> 几乎用不上</strong>：除非你在 spring 还没结束时换成另一条 spring 想平滑过渡，否则填 0；非 0 时手势手感会发"糊"。</li>
<li><strong>修饰符顺序坑</strong>：<code>.frame</code> 在 <code>.scaleEffect</code> 之外才会改变布局空间；<code>scaleEffect</code> 只是绘制变换，不影响占位。做"卡片放大挤开邻居"要用 <code>.frame(width:height:)</code> 直接动 size。</li>
<li><strong>同帧多 state + 单 withAnimation</strong>：所有变更都会被这条 animation 接管，数字、计数器这类不希望插值的，必须显式 <code>transaction.animation = nil</code>。</li>
<li><strong>手势 <code>.interactiveSpring</code> 别加 <code>.delay</code></strong>：手感会断；要"延迟启动"用普通 <code>.spring</code>。</li>
<li><strong>iOS 17 <code>.smooth</code>/<code>.snappy</code>/<code>.bouncy</code> 不是常量是函数</strong>：可以传 <code>(duration:extraBounce:)</code>，<code>extraBounce</code> 是<strong>叠加</strong>不是覆盖（<code>.snappy(extraBounce: 0.1)</code> = bounce 0.25）。</li>
<li><strong>Reduce Motion 用户</strong>：spring 反弹会被系统自动弱化，但不会完全关；要彻底关掉装饰性动画请读 <code>\.accessibilityReduceMotion</code> 自己分支到 <code>.linear(duration: 0)</code> 或 <code>nil</code>。</li>
<li><strong>iOS 26 Liquid Glass 与自定义 spring 冲突</strong>：在 <code>GlassEffectContainer</code> 内对成员用激进 bouncy spring 会和系统的形变 spring "打架"，出现两段不同步抖动；优先用 <code>.smooth</code> 与系统协调。</li>
<li><strong><code>withAnimation</code> 完成回调不会在被中途打断时调用</strong>：如果新一次 <code>withAnimation</code> 覆盖了未播完的旧动画，旧的 completion 会被丢弃；需要"无论如何执行一次"的副作用别放 completion，放调用点同步执行。</li>
</ul>
</blockquote>