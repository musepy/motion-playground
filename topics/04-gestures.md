<h3>4.1 概览：SwiftUI 手势体系的三层抽象</h3>

<p>SwiftUI 的手势系统建立在三个层级之上：<strong>原子手势（primitive gestures）</strong>、<strong>组合手势（composed gestures）</strong>、<strong>自定义手势（custom Gesture）</strong>。所有手势都遵循 <code>Gesture</code> 协议，通过 <code>.gesture(_:)</code>、<code>.simultaneousGesture(_:)</code>、<code>.highPriorityGesture(_:)</code> 三个修饰符附加到 view 上。iOS 17+（WWDC 2023, Session 10168 "What's new in SwiftUI"）引入了 <code>SpatialTapGesture</code>、<code>MagnifyGesture</code>、<code>RotateGesture</code>，并把 <code>DragGesture.Value</code> 的 <code>velocity</code> 类型从隐式改为公开的 <code>CGSize</code>，使得 spring 接力变得稳定。</p>

<p>核心心智模型：手势的生命周期是 <em>identify → updating → ended/cancelled</em>。<code>onChanged</code> 与 <code>updating</code> 在每一帧持续触发，<code>onEnded</code> 在抬手或取消时触发一次。理解这一点是后续所有冲突解决与状态管理的基础。</p>

<h3>4.2 TapGesture：单击 / 双击 / 三击</h3>

<p><code>TapGesture(count:)</code> 通过 <code>count</code> 区分多击。注意：<strong>多击手势会延迟单击响应</strong>，因为系统必须等待第二次点击的判定窗口（约 250ms）。如果同时挂载单击和双击，二者会冲突——必须用 <code>ExclusiveGesture</code> 或 <code>simultaneousGesture</code> 显式表达优先级。</p>

<pre><code class="language-swift">// iOS 13+
struct TapDemo: View {
    @State private var hits = 0
    var body: some View {
        Text("Hits: \(hits)")
            .padding(40)
            .background(AnycastColor.sand4)
            .gesture(
                TapGesture(count: 2)
                    .onEnded { hits += 2 }
            )
            .simultaneousGesture(
                TapGesture(count: 1)
                    .onEnded { hits += 1 }
            )
    }
}</code></pre>

<p>简写 <code>.onTapGesture(count:perform:)</code> 等价于 <code>.gesture(TapGesture(count:).onEnded(_:))</code>，但简写不返回 <code>Gesture</code> 实例，因此无法参与组合。需要组合时必须用完整形式。</p>

<h3>4.3 SpatialTapGesture（iOS 17+）：拿到 hit-tested location</h3>

<p>普通 <code>TapGesture</code> 不告诉你点哪了。<code>SpatialTapGesture</code>（WWDC 2023, Session 10160 "Discover Observation in SwiftUI" 周边发布）的 <code>Value</code> 是 <code>CGPoint</code>，坐标空间默认是被点击 view 的本地坐标，可通过 <code>coordinateSpace:</code> 指定 <code>.global</code> / <code>.local</code> / <code>.named(_:)</code>。</p>

<pre><code class="language-swift">// iOS 17+
struct RippleOnTap: View {
    @State private var ripple: CGPoint?
    var body: some View {
        Rectangle()
            .fill(AnycastColor.sand1)
            .overlay {
                if let p = ripple {
                    Circle().fill(AnycastColor.goldAlpha40)
                        .frame(width: 40, height: 40)
                        .position(p)
                }
            }
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        ripple = value.location
                    }
            )
    }
}</code></pre>

<h3>4.4 LongPressGesture：minimumDuration 与 maximumDistance</h3>

<p>两个关键参数：<code>minimumDuration</code>（默认 0.5s）和 <code>maximumDistance</code>（手指允许漂移的距离，默认 10pt）。超过 <code>maximumDistance</code> 时手势取消。<code>onChanged</code> 在 <em>识别成功的瞬间</em>（达到 minimumDuration）触发一次，<code>onEnded</code> 在抬手时触发——这与 DragGesture 的"持续触发 onChanged"完全不同。</p>

<pre><code class="language-swift">// iOS 13+
LongPressGesture(minimumDuration: 0.4, maximumDistance: 12)
    .onChanged { _ in
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    .onEnded { _ in
        app.openedEpisode = ep   // 长按打开详情
    }</code></pre>

<h3>4.5 DragGesture：核心数据 7 件套</h3>

<p>DragGesture 的 <code>Value</code> 暴露 7 个字段，全部基于指定的 <code>coordinateSpace</code>：</p>

<table>
<thead><tr><th>字段</th><th>类型</th><th>含义</th></tr></thead>
<tbody>
<tr><td><code>time</code></td><td><code>Date</code></td><td>事件时间戳</td></tr>
<tr><td><code>location</code></td><td><code>CGPoint</code></td><td>当前手指位置</td></tr>
<tr><td><code>startLocation</code></td><td><code>CGPoint</code></td><td>手势开始位置</td></tr>
<tr><td><code>translation</code></td><td><code>CGSize</code></td><td>location − startLocation</td></tr>
<tr><td><code>predictedEndTranslation</code></td><td><code>CGSize</code></td><td>UIKit deceleration 模型预测的最终偏移</td></tr>
<tr><td><code>predictedEndLocation</code></td><td><code>CGPoint</code></td><td>预测最终位置</td></tr>
<tr><td><code>velocity</code> (iOS 17+)</td><td><code>CGSize</code></td><td>当前速度，单位 pt/s</td></tr>
</tbody>
</table>

<p>iOS 16 及以前没有公开 <code>velocity</code>，常见 hack 是用 <code>predictedEndTranslation - translation</code> 反推一个粗略速度。iOS 17 起 Apple 把 <code>velocity</code> 提升为公开 API（WWDC 2023 What's new in SwiftUI），<strong>这是 spring 接力能稳定工作的前提</strong>。</p>

<pre><code class="language-swift">// iOS 17+
DragGesture(minimumDistance: 0, coordinateSpace: .local)
    .onChanged { v in
        print("loc=\(v.location) t=\(v.translation) vel=\(v.velocity)")
    }
    .onEnded { v in
        print("predEnd=\(v.predictedEndTranslation)")
    }</code></pre>

<h3>4.6 MagnifyGesture / RotateGesture（iOS 17+）</h3>

<p>iOS 17 把 <code>MagnificationGesture</code> 改名为 <code>MagnifyGesture</code>、<code>RotationGesture</code> 改名为 <code>RotateGesture</code>，并在 <code>Value</code> 上新增 <code>velocity</code>、<code>startAnchor</code>、<code>startLocation</code>。旧名继续可用但标记 deprecated。</p>

<pre><code class="language-swift">// iOS 17+
struct PinchZoom: View {
    @State private var scale: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    var body: some View {
        Image("cover")
            .resizable().scaledToFit()
            .scaleEffect(scale * pinch)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in
                        state = value.magnification
                    }
                    .onEnded { value in
                        scale *= value.magnification
                    }
            )
    }
}</code></pre>

<h3>4.7 @GestureState vs @State：自动重置的妙用</h3>

<p><code>@GestureState</code> 会在手势 ended/cancelled 时<strong>自动恢复初值</strong>，因此特别适合"临时位移"。它<em>只能</em>通过 <code>updating(_:body:)</code> 写入，不能直接赋值。<code>@State</code> 则保留最后的值，适合"提交后的最终状态"。</p>

<pre><code class="language-swift">// iOS 13+
struct DragCard: View {
    @State private var offset: CGSize = .zero      // 累积位移
    @GestureState private var drag: CGSize = .zero  // 临时位移
    var body: some View {
        RoundedRectangle(cornerRadius: AnycastRadius.card)
            .fill(AnycastColor.sand4)
            .frame(width: 200, height: 120)
            .offset(x: offset.width + drag.width,
                    y: offset.height + drag.height)
            .gesture(
                DragGesture()
                    .updating($drag) { value, state, _ in
                        state = value.translation       // 自动 reset
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
    }
}</code></pre>

<p>对比三种回调：</p>
<ul>
<li><code>updating(_:body:)</code>：写入 <code>@GestureState</code>，手势结束自动 reset。<strong>不能</strong>触发普通 <code>@State</code> 的副作用。</li>
<li><code>onChanged</code>：每帧触发，可任意写 <code>@State</code>，但需自己处理"中途取消"的回退。</li>
<li><code>onEnded</code>：抬手/取消时触发一次，常用于"提交"。</li>
</ul>

<h3>4.8 优先级三选一：gesture / simultaneousGesture / highPriorityGesture</h3>

<table>
<thead><tr><th>修饰符</th><th>行为</th><th>典型用例</th></tr></thead>
<tbody>
<tr><td><code>.gesture(_:)</code></td><td>默认优先级，子 view 已识别的手势会"赢"</td><td>普通 tap/drag</td></tr>
<tr><td><code>.simultaneousGesture(_:)</code></td><td>与子 view 手势<strong>并行</strong>识别</td><td>tap 在 ScrollView 上</td></tr>
<tr><td><code>.highPriorityGesture(_:)</code></td><td>父手势<strong>抢先</strong>，阻断子 view</td><td>大 cell 想自己处理 tap，盖掉里头的 Button</td></tr>
</tbody>
</table>

<pre><code class="language-swift">// iOS 13+ — Cell 内有 Button，整体也想响应 tap
HStack {
    Button("Play") { play() }
    Spacer()
    Text("Episode title")
}
.contentShape(Rectangle())
.highPriorityGesture(
    TapGesture().onEnded { app.openedEpisode = ep }
)
// 注意：这样 Button 不会响应！要让 Button 工作改成 .simultaneousGesture</code></pre>

<h3>4.9 组合手势：Simultaneous / Sequence / Exclusive</h3>

<p>三种组合器返回新的 <code>Gesture</code>，可继续叠加。运算符语法：<code>g1.simultaneously(with: g2)</code>、<code>g1.sequenced(before: g2)</code>、<code>g1.exclusively(before: g2)</code>。</p>

<pre><code class="language-swift">// iOS 13+ — 长按后才能拖动（典型 reorder）
struct LongPressThenDrag: View {
    @State private var offset: CGSize = .zero
    @GestureState private var dragState: DragState = .inactive
    enum DragState {
        case inactive, pressing, dragging(CGSize)
    }
    var body: some View {
        let press = LongPressGesture(minimumDuration: 0.3)
        let drag = DragGesture()
        let combined = press.sequenced(before: drag)
            .updating($dragState) { value, state, _ in
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
                if case .second(true, let drag?) = value {
                    offset.width += drag.translation.width
                    offset.height += drag.translation.height
                }
            }
        return Circle().fill(AnycastColor.orangeAlpha60)
            .frame(width: 60, height: 60)
            .offset(x: offset.width, y: offset.height)
            .gesture(combined)
    }
}</code></pre>

<p><code>SequenceGesture</code> 的 <code>Value</code> 是嵌套枚举 <code>.first(_) | .second(_, _?)</code>，必须模式匹配解包。<code>ExclusiveGesture</code> 则是 <code>.first(_) | .second(_)</code>，先识别成功的赢。</p>

<h3>4.10 ScrollView × DragGesture 的冲突</h3>

<p>这是日常最容易踩雷的地方。<code>ScrollView</code> 内部本身有一个 pan 手势用于滚动。如果在它的子 view 上挂 <code>DragGesture()</code>（默认 <code>minimumDistance: 10</code>），系统会在两个手势之间做一次"歧义解析"，常见现象是<strong>滚不动</strong>或<strong>拖不动</strong>。</p>

<p>解法：</p>
<ul>
<li>设 <code>DragGesture(minimumDistance: 0)</code>：手势"立即"生效——但会完全吃掉滚动，仅在自定义 drawer / 全屏交互时这么干。</li>
<li>用 <code>.simultaneousGesture(_:)</code>：scroll 与你的手势并行识别。</li>
<li>iOS 16+ 在 <code>ScrollView</code> 上配 <code>.scrollDisabled(condition)</code> 临时关掉滚动，常配合自定义 pull-to-reveal。</li>
<li>iOS 17+ 用 <code>.scrollTargetBehavior(_:)</code> 接管 paging，避免再用 DragGesture 模拟。</li>
</ul>

<blockquote>
<p>项目中已知技术债：pull-to-reveal Clear 用鼠标拖不出（iOS rubber-band 只对真触控响应）。这是 sim 的 mouse 事件不会触发 UIKit overscroll path 的限制，不是手势本身的 bug。</p>
</blockquote>

<h3>4.11 自定义 Gesture：遵守 Gesture 协议</h3>

<p>大部分场景用组合就够了。需要"完全自定义识别逻辑"时，实现 <code>Gesture</code> 协议，把 <code>body</code> 委托给已有的手势组合：</p>

<pre><code class="language-swift">// iOS 13+ — 把"水平 swipe ≥ 80pt 触发回调"封装成可复用 Gesture
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

// 用法
.gesture(SwipeAction(onLeft: { delete() }, onRight: { archive() }))</code></pre>

<h3>4.12 完整实战：swipe-to-dismiss + velocity 接力 spring</h3>

<p>以 Anycast 的 NowPlaying 全屏为例：下滑超过阈值 <em>或</em> 速度足够大时关闭，否则 spring 回弹。关键是把 <code>velocity</code> 喂给 <code>.interactiveSpring(initialVelocity:)</code>，让动画有"延续感"而不是从零起步。</p>

<pre><code class="language-swift">// iOS 17+
struct NowPlayingSheet: View {
    @EnvironmentObject var app: AppState
    @State private var dragY: CGFloat = 0
    @State private var dismissing = false

    private let dismissDistance: CGFloat = 140
    private let dismissVelocity: CGFloat = 800   // pt/s

    var body: some View {
        VStack { /* ... player UI ... */ }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnycastColor.sand1)
            .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.cardLarge))
            .offset(y: max(0, dragY))
            .gesture(
                DragGesture(minimumDistance: 8, coordinateSpace: .local)
                    .onChanged { v in
                        dragY = v.translation.height
                    }
                    .onEnded { v in
                        let dy = v.translation.height
                        let vy = v.velocity.height          // iOS 17+
                        let shouldDismiss =
                            dy > dismissDistance || vy > dismissVelocity

                        if shouldDismiss {
                            withAnimation(.interactiveSpring(
                                response: 0.42,
                                dampingFraction: 0.86,
                                blendDuration: 0
                            )) {
                                dragY = UIScreen.main.bounds.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                                app.presentNowPlaying = false
                                dragY = 0
                            }
                        } else {
                            withAnimation(.spring(
                                response: 0.38, dampingFraction: 0.78
                            )) {
                                dragY = 0
                            }
                        }
                    }
            )
    }
}</code></pre>

<p>iOS 17 的 <code>.interactiveSpring</code> 与 iOS 18 的 <code>Animation.spring(.snappy)</code> presets 都接受 spring 物理参数。<code>predictedEndLocation</code> 的物理意义是"如果手指按当前速度滑行直到 UIKit 默认 deceleration 衰减到 0 时的终点"——它适合做 <em>paging snap</em>（判断该不该翻到下一页），不适合直接喂给 spring。</p>

<h3>4.13 实战模式合集</h3>

<h4>Pinch-to-zoom 图片（pan + scale + rotate 联合，iOS 17+）</h4>

<pre><code class="language-swift">// iOS 17+
struct PhotoViewer: View {
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var rotation: Angle = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var pan: CGSize = .zero
    @GestureState private var spin: Angle = .zero

    var body: some View {
        let pinchG = MagnifyGesture()
            .updating($pinch) { v, s, _ in s = v.magnification }
            .onEnded { v in scale = max(1, scale * v.magnification) }
        let panG = DragGesture()
            .updating($pan) { v, s, _ in s = v.translation }
            .onEnded { v in
                offset.width += v.translation.width
                offset.height += v.translation.height
            }
        let spinG = RotateGesture()
            .updating($spin) { v, s, _ in s = v.rotation }
            .onEnded { v in rotation = rotation + v.rotation }

        return Image("hero")
            .resizable().scaledToFit()
            .scaleEffect(scale * pinch)
            .rotationEffect(rotation + spin)
            .offset(x: offset.width + pan.width,
                    y: offset.height + pan.height)
            .gesture(pinchG.simultaneously(with: spinG)
                     .simultaneously(with: panG))
    }
}</code></pre>

<h4>自定义 drawer（高度可拖、释放后 snap）</h4>

<pre><code class="language-swift">// iOS 17+
struct Drawer<Content: View>: View {
    @Binding var open: Bool
    @ViewBuilder var content: () -> Content
    @State private var dragY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            content()
                .frame(maxWidth: .infinity)
                .frame(height: geo.size.height * 0.6)
                .background(AnycastColor.sand1)
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.cardLarge))
                .offset(y: open ? max(0, dragY) : geo.size.height)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in dragY = v.translation.height }
                        .onEnded { v in
                            let snapOpen =
                                v.translation.height < 100 && v.velocity.height < 600
                            withAnimation(.spring(response: 0.35,
                                                  dampingFraction: 0.82)) {
                                open = snapOpen
                                dragY = 0
                            }
                        }
                )
        }
    }
}</code></pre>

<h4>HoverGesture（iPad / Mac）</h4>

<p><code>.onHover { hovering in ... }</code> 是简写；更细可用 <code>.onContinuousHover { phase in ... }</code>（iOS 16+）拿到 <code>active(CGPoint)</code> / <code>ended</code>。这是 iPad pointer 与 Mac Catalyst 上获得 hover affordance 的唯一途径。</p>

<pre><code class="language-swift">// iOS 16+
.onContinuousHover(coordinateSpace: .local) { phase in
    switch phase {
    case .active(let p): hoverPoint = p
    case .ended: hoverPoint = nil
    }
}</code></pre>

<blockquote class="warning">
<h4>踩坑速查 / Pitfalls</h4>
<ul>
<li><strong>Hit testing</strong>：透明背景的 view <em>不参与</em> hit test。给整个区域加 <code>.contentShape(Rectangle())</code> 才能在空白处响应手势。<code>Spacer()</code> 撑出的空白默认也吃不到 tap。</li>
<li><strong>ScrollView 冲突</strong>：在 ScrollView 子 view 上挂 <code>DragGesture()</code> 会和滚动打架。要么 <code>simultaneousGesture</code>，要么 iOS 16+ 用 <code>.scrollDisabled</code> 临时关闭，要么 iOS 17+ 直接换 <code>.scrollTargetBehavior</code>。</li>
<li><strong>@GestureState 重置时机</strong>：是在 <em>下一帧</em> reset，不是同一帧。如果在 <code>onEnded</code> 里读 <code>@GestureState</code> 拿到的是即将被清掉的值；要保留最终位移必须用 <code>onEnded</code> 的 <code>value.translation</code> 写到 <code>@State</code>。</li>
<li><strong>updating 不能写 @State</strong>：编译能过，运行时 SwiftUI 会触发 "Modifying state during view update" 警告甚至循环刷新。状态副作用一律放 <code>onChanged</code>。</li>
<li><strong>highPriorityGesture 会吃掉子 Button</strong>：父 view 的 highPriority tap 会让里层 <code>Button</code>、<code>NavigationLink</code> 失效；想兼容必须改成 <code>simultaneousGesture</code> 并自己分流。</li>
<li><strong>velocity 单位</strong>：<code>DragGesture.velocity</code>（iOS 17+）是 pt/s，可以直接喂给 <code>.interactiveSpring(initialVelocity:)</code>；<code>predictedEndTranslation</code> 是位移，<em>不是</em>速度，别搞混。</li>
<li><strong>iOS 16 及以下没有公开 velocity</strong>：用 <code>(predictedEndTranslation - translation) / 0.5</code> 近似（UIKit deceleration 假设 0.5s 衰减），但精度差，能升 iOS 17 就升。</li>
<li><strong>SpatialTapGesture 默认坐标空间是 local</strong>：跨 view 比较位置必须显式 <code>.named(_:)</code> 或 <code>.global</code>，否则数字毫无可比性。</li>
<li><strong>LongPressGesture 的 onChanged 只触发一次</strong>：不要期待它像 DragGesture 那样持续刷新——想做"长按后跟手缩放"必须用 <code>sequenced(before: MagnifyGesture())</code>。</li>
<li><strong>Simulator 鼠标 ≠ 手指</strong>：rubber-band overscroll、3D Touch、双指捏合在 sim 上要么不触发要么需要按住 Option 键。功能验证以真机为准，sim 截图只能验视觉。</li>
<li><strong>Anycast/Anycast-sources 镜像</strong>：手势相关代码改完别忘了 <code>cp</code> 到 <code>Anycast-sources/</code>，否则下一次清理 build 缓存就回滚了。</li>
</ul>
</blockquote>