<h3>2.1 Animatable 协议：SwiftUI 动画的物理基础</h3>

<p>SwiftUI 的所有动画底层都通过 <code>Animatable</code> 协议驱动。该协议只有一个 associated type 与一个属性：</p>

<pre><code class="language-swift">// Apple 官方定义（SwiftUI framework, iOS 13+）
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic
    var animatableData: AnimatableData { get set }
}</code></pre>

<p>当一个 <code>View</code>、<code>ViewModifier</code>、<code>Shape</code> 或 <code>GeometryEffect</code> 遵守 <code>Animatable</code>，SwiftUI 在 transaction 内部对其 <code>animatableData</code> 做<strong>插值</strong>（非 view tree diff），由 render server 在每一帧 tick 设新值并触发 <code>body</code>/<code>path(in:)</code>/<code>effectValue(size:)</code> 重算。这意味着真正"动"的不是 view 而是数值，所以理解 <code>VectorArithmetic</code> 是关键。</p>

<p><code>VectorArithmetic</code> 继承自 <code>AdditiveArithmetic</code>，新增 <code>scale(by:)</code> 与 <code>magnitudeSquared</code>。内置实现包含 <code>Float</code>、<code>Double</code>、<code>CGFloat</code>、<code>EmptyAnimatableData</code>，以及递归的 <code>AnimatablePair&lt;First, Second&gt;</code>。SwiftUI 用这些做 catmull-rom / spring / 各种 curve 的逐帧插值。</p>

<p>参考：WWDC23 <em>Explore SwiftUI animation</em>（Session 10156），WWDC23 <em>Wind your way through advanced animations in SwiftUI</em>（Session 10157）；Apple Doc: <a><code>developer.apple.com/documentation/swiftui/animatable</code></a>。</p>

<h3>2.2 AnimatablePair 多维度组合</h3>

<p>当一个值需要同时对两个标量插值，使用 <code>AnimatablePair</code>。它本身是 <code>VectorArithmetic</code>，可以无限嵌套。下例做一个圆环进度，<strong>同时</strong>动画化"已绘制比例"与"线宽"：</p>

<pre><code class="language-swift">// iOS 13+ — AnimatablePair 示例
struct ProgressRing: Shape {
    var progress: CGFloat        // 0...1
    var lineWidth: CGFloat       // 描边宽度

    var animatableData: AnimatablePair&lt;CGFloat, CGFloat&gt; {
        get { AnimatablePair(progress, lineWidth) }
        set {
            progress  = newValue.first
            lineWidth = newValue.second
        }
    }

    func path(in rect: CGRect) -&gt; Path {
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * progress),
            clockwise: false
        )
        return p.strokedPath(.init(lineWidth: lineWidth, lineCap: .round))
    }
}</code></pre>

<p>嵌套示例：3D 翻牌需要 <code>(angleX, angleY, scale)</code>，写成 <code>AnimatablePair&lt;CGFloat, AnimatablePair&lt;CGFloat, CGFloat&gt;&gt;</code>。三个以上参数虽然能写但难维护，更好的做法是<strong>iOS 17+ KeyframeAnimator 多 track</strong>（见 2.6）。</p>

<blockquote><p><code>AnimatableModifier</code> 自 iOS 13 起即<strong>已 deprecated</strong>。直接让你的 <code>ViewModifier</code> 实现 <code>Animatable</code> 即可，效果等价。</p></blockquote>

<h3>2.3 Shape.animatableData 实战：波浪与星形</h3>

<pre><code class="language-swift">// iOS 13+ — 正弦波浪（音频可视化常用）
struct Wave: Shape {
    var phase: CGFloat   // 推进相位 → 横向流动
    var amplitude: CGFloat

    var animatableData: AnimatablePair&lt;CGFloat, CGFloat&gt; {
        get { .init(phase, amplitude) }
        set { phase = newValue.first; amplitude = newValue.second }
    }

    func path(in rect: CGRect) -&gt; Path {
        var p = Path()
        let midY = rect.midY
        let wavelength = rect.width / 2
        p.move(to: .init(x: 0, y: midY))
        for x in stride(from: 0, through: rect.width, by: 1) {
            let relative = (x / wavelength) + phase
            let y = midY + sin(relative * .pi * 2) * amplitude
            p.addLine(to: .init(x: x, y: y))
        }
        return p
    }
}

// 用法：
// .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: phase)</code></pre>

<pre><code class="language-swift">// iOS 13+ — N 角星形 morph，通过 sides 浮点插值实现"边数变化"动画
struct MorphStar: Shape {
    var sides: CGFloat  // 3.0 → 8.0 可插值
    var inset: CGFloat  // 0 = 多边形，&gt;0 = 星形

    var animatableData: AnimatablePair&lt;CGFloat, CGFloat&gt; {
        get { .init(sides, inset) }
        set { sides = newValue.first; inset = newValue.second }
    }

    func path(in rect: CGRect) -&gt; Path {
        let n = max(3, Int(sides.rounded()))
        let r = min(rect.width, rect.height) / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        let step = .pi * 2 / CGFloat(n * 2)
        for i in 0..&lt;(n * 2) {
            let radius = i.isMultiple(of: 2) ? r : r * (1 - inset)
            let angle = -.pi / 2 + step * CGFloat(i)
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath()
        return path
    }
}</code></pre>

<h3>2.4 GeometryEffect：用 transform 矩阵做动画</h3>

<p><code>GeometryEffect</code> 继承 <code>Animatable</code> 与 <code>ViewModifier</code>，关键方法：</p>

<pre><code class="language-swift">func effectValue(size: CGSize) -&gt; ProjectionTransform</code></pre>

<p>每帧 SwiftUI 拿当前 size 算出一个 3x3 投影矩阵（<code>CATransform3D</code> 的 2D 子集），合成到 layer 上。<strong>不会触发 layout</strong>，只走 GPU compositing —— 比 <code>frame</code> / <code>offset</code> + <code>animation</code> 的等价路径便宜。下面三例覆盖 shake、3D flip、弹性卡片。</p>

<pre><code class="language-swift">// iOS 13+ — Shake 抖动（密码错误反馈）
struct Shake: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animatableData: CGFloat   // 外部递增触发动画

    func effectValue(size: CGSize) -&gt; ProjectionTransform {
        let dx = amount * sin(animatableData * .pi * CGFloat(shakesPerUnit))
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}

extension View {
    func shake(times: Int) -&gt; some View {
        modifier(Shake(animatableData: CGFloat(times)))
    }
}

// 触发：每次失败 attempts += 1，配 .animation(.default, value: attempts)</code></pre>

<pre><code class="language-swift">// iOS 13+ — 3D flip（翻牌 / 卡片正反面）
struct FlipEffect: GeometryEffect {
    var angle: Double  // degrees, 0...180
    let axis: (x: CGFloat, y: CGFloat)

    var animatableData: Double {
        get { angle } set { angle = newValue }
    }

    func effectValue(size: CGSize) -&gt; ProjectionTransform {
        var t = CATransform3DIdentity
        t.m34 = -1 / 500   // 透视
        let radians = angle * .pi / 180
        t = CATransform3DRotate(t, radians, axis.x, axis.y, 0)
        let affine = CATransform3DGetAffineTransform(t)   // 兼容 ProjectionTransform
        return ProjectionTransform(t).isIdentity ? .init(affine) : .init(t)
    }
}</code></pre>

<h3>2.5 CustomAnimation 协议（iOS 17+）：自己写曲线 / 物理</h3>

<p>iOS 17 起 <code>Animation</code> 不再是黑盒，可以接管时间映射：</p>

<pre><code class="language-swift">public protocol CustomAnimation: Hashable {
    func animate&lt;V: VectorArithmetic&gt;(value: V, time: TimeInterval, context: inout AnimationContext&lt;V&gt;) -&gt; V?
    func velocity&lt;V: VectorArithmetic&gt;(value: V, time: TimeInterval, context: AnimationContext&lt;V&gt;) -&gt; V?
    func shouldMerge&lt;V: VectorArithmetic&gt;(previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext&lt;V&gt;) -&gt; Bool
}</code></pre>

<ul>
<li><code>animate</code> 返回 <code>nil</code> 表示动画结束</li>
<li><code>velocity</code> 提供给后续 spring 接管初速度（保证打断流畅）</li>
<li><code>shouldMerge</code> 决定新 animation 是否吃掉旧 animation 的 state</li>
<li><code>context.state</code>（PropertyList）可保存中间状态，跨帧共享</li>
</ul>

<pre><code class="language-swift">// iOS 17+ — 弹簧 + 弹跳衰减（自制）
struct BouncySpring: CustomAnimation {
    let mass: Double = 1
    let stiffness: Double = 180
    let damping: Double = 12

    private struct State&lt;V: VectorArithmetic&gt; { var velocity: V }

    func animate&lt;V&gt;(value: V, time: TimeInterval, context: inout AnimationContext&lt;V&gt;) -&gt; V? where V: VectorArithmetic {
        var state = context.state[State&lt;V&gt;.self] ?? .init(velocity: .zero)
        let dt = 1.0 / 120.0
        var current: V = .zero
        var t = 0.0
        while t &lt; time {
            // F = -k*x - c*v
            var force = value
            force.scale(by: -stiffness)
            var damp = state.velocity
            damp.scale(by: -damping)
            force += damp
            force.scale(by: dt / mass)
            state.velocity += force
            var step = state.velocity
            step.scale(by: dt)
            current += step
            t += dt
        }
        context.state[State&lt;V&gt;.self] = state
        return current.magnitudeSquared &lt; 0.0001 &amp;&amp; state.velocity.magnitudeSquared &lt; 0.0001 ? nil : current
    }
}

extension Animation {
    static var anycastBounce: Animation { .init(BouncySpring()) }
}</code></pre>

<h3>2.6 KeyframeAnimator（iOS 17+）：多 track 关键帧编排</h3>

<p>API 形态：</p>

<pre><code class="language-swift">KeyframeAnimator(
    initialValue: AnimationValues,
    trigger: triggerValue
) { values in
    content
        .scaleEffect(values.scale)
        .offset(y: values.yOffset)
        .rotationEffect(.degrees(values.angle))
} keyframes: { _ in
    KeyframeTrack(\.scale)   { LinearKeyframe(1.0, duration: 0.1); SpringKeyframe(1.2, duration: 0.4) }
    KeyframeTrack(\.yOffset) { CubicKeyframe(-30, duration: 0.25); SpringKeyframe(0,   duration: 0.6, spring: .bouncy) }
    KeyframeTrack(\.angle)   { CubicKeyframe(-15, duration: 0.3);  CubicKeyframe(0,    duration: 0.4) }
}</code></pre>

<p>四种 keyframe：</p>

<ul>
<li><code>LinearKeyframe</code> — 线性插值，segment 起止匀速</li>
<li><code>CubicKeyframe</code> — Catmull-Rom，自动平滑前后切线</li>
<li><code>SpringKeyframe</code> — 用 <code>Spring</code> 物理模型从当前速度过渡</li>
<li><code>MoveKeyframe</code> — 瞬移（不插值），常用于 reset</li>
</ul>

<pre><code class="language-swift">// iOS 17+ — 完整可编译示例：心跳动画（缩放 + 旋转 + 位移多 track）
struct HeartBeat: View {
    @State private var beats = 0

    struct Values {
        var scale: CGFloat = 1
        var rotation: Angle = .zero
        var yOffset: CGFloat = 0
    }

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundStyle(.pink)
            .keyframeAnimator(initialValue: Values(), trigger: beats) { content, v in
                content
                    .scaleEffect(v.scale)
                    .rotationEffect(v.rotation)
                    .offset(y: v.yOffset)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.3, duration: 0.18, spring: .snappy)
                    SpringKeyframe(0.95, duration: 0.22, spring: .bouncy)
                    LinearKeyframe(1.0, duration: 0.15)
                }
                KeyframeTrack(\.rotation) {
                    CubicKeyframe(.degrees(-8), duration: 0.18)
                    CubicKeyframe(.degrees(8), duration: 0.18)
                    CubicKeyframe(.zero, duration: 0.15)
                }
                KeyframeTrack(\.yOffset) {
                    LinearKeyframe(-12, duration: 0.18)
                    SpringKeyframe(0, duration: 0.4, spring: .bouncy)
                }
            }
            .onTapGesture { beats += 1 }
    }
}</code></pre>

<h3>2.7 PhaseAnimator（iOS 17+）：自动循环或 trigger 推进的有限状态机</h3>

<p>两种重载：自动循环 phases 序列；trigger 推进。phase 类型只要 <code>Hashable</code>，常用 enum：</p>

<pre><code class="language-swift">// iOS 17+ — 注意力提示无限循环
struct PulseAttention: View {
    enum Phase: CaseIterable { case rest, peak, rest2 }

    var body: some View {
        Image(systemName: "bell.badge.fill")
            .phaseAnimator(Phase.allCases) { content, phase in
                content
                    .scaleEffect(phase == .peak ? 1.25 : 1)
                    .opacity(phase == .peak ? 1 : 0.7)
            } animation: { phase in
                switch phase {
                case .peak:  .easeOut(duration: 0.4)
                case .rest, .rest2: .easeIn(duration: 0.4)
                }
            }
    }
}

// trigger 版（按钮点击推进一次）
struct LikeButton: View {
    @State private var likes = 0
    var body: some View {
        Button { likes += 1 } label: {
            Image(systemName: "heart.fill")
        }
        .phaseAnimator([1.0, 1.4, 0.9, 1.0], trigger: likes) { content, scale in
            content.scaleEffect(scale)
        } animation: { _ in .spring(duration: 0.3, bounce: 0.5) }
    }
}</code></pre>

<p><strong>自定义 enum + RawRepresentable</strong> 让 phase 携带语义：</p>

<pre><code class="language-swift">// iOS 17+ — 多状态切换（loading → success → idle）
enum ToastPhase: CaseIterable {
    case hidden, sliding, settled, fading

    var offsetY: CGFloat {
        switch self { case .hidden, .fading: -80; case .sliding: -10; case .settled: 0 }
    }
    var opacity: Double {
        switch self { case .hidden, .fading: 0; default: 1 }
    }
}

struct Toast: View {
    @State private var trigger = false
    var body: some View {
        Text("Saved")
            .padding()
            .background(.regularMaterial, in: .capsule)
            .phaseAnimator(ToastPhase.allCases, trigger: trigger) { content, phase in
                content.offset(y: phase.offsetY).opacity(phase.opacity)
            } animation: { phase in
                switch phase {
                case .sliding:  .spring(duration: 0.45, bounce: 0.4)
                case .fading:   .easeOut(duration: 0.3)
                default:        .linear(duration: 0)
                }
            }
    }
}</code></pre>

<h3>2.8 Animatable + GeometryEffect 联合：progress-driven 卡片飞入</h3>

<pre><code class="language-swift">// iOS 13+ — progress 0→1 同时驱动位移、缩放、旋转、透视
struct CardFlyIn: GeometryEffect {
    var progress: CGFloat   // 0...1
    var animatableData: CGFloat {
        get { progress } set { progress = newValue }
    }

    func effectValue(size: CGSize) -&gt; ProjectionTransform {
        let p = max(0, min(1, progress))
        let translateY = (1 - p) * 200
        let scale = 0.6 + 0.4 * p
        let angle = (1 - p) * .pi / 6
        var t = CATransform3DIdentity
        t.m34 = -1 / 800
        t = CATransform3DTranslate(t, 0, translateY, 0)
        t = CATransform3DScale(t, scale, scale, 1)
        t = CATransform3DRotate(t, angle, 1, 0, 0)
        return ProjectionTransform(t)
    }
}</code></pre>

<h3>2.9 KeyframeTimeline：脱离 SwiftUI 渲染的关键帧采样</h3>

<p><code>KeyframeTimeline&lt;Value&gt;</code> 可以独立创建并任意时间点采样，常用于 <code>Canvas</code>/<code>TimelineView</code> 自绘场景，不依赖 view tree：</p>

<pre><code class="language-swift">// iOS 17+ — 用 KeyframeTimeline 喂给 Canvas
struct ParticleBurst: View {
    let timeline = KeyframeTimeline(initialValue: CGPoint.zero) {
        KeyframeTrack(\.x) {
            CubicKeyframe(120, duration: 0.6)
            CubicKeyframe(0,   duration: 0.6)
        }
        KeyframeTrack(\.y) {
            SpringKeyframe(-200, duration: 0.5, spring: .bouncy)
            SpringKeyframe(0,    duration: 0.7, spring: .smooth)
        }
    }

    var body: some View {
        TimelineView(.animation) { ctx in
            Canvas { gc, size in
                let elapsed = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: timeline.duration)
                let pt = timeline.value(time: elapsed)
                gc.fill(Path(ellipseIn: .init(x: size.width/2 + pt.x - 8,
                                              y: size.height/2 + pt.y - 8,
                                              width: 16, height: 16)),
                        with: .color(.orange))
            }
        }
    }
}</code></pre>

<p><code>timeline.duration</code> 自动算出所有 track 总时长；<code>timeline.value(time:)</code> 返回该时间点合成值。这条路径还能用于 <code>SpriteKit</code>、<code>SceneKit</code> 桥接动画，或导出到 metal compute shader。</p>

<h3>2.10 iOS 18 / iOS 26 新能力</h3>

<ul>
<li><strong>iOS 18</strong>：<code>SymbolEffect</code> 增加 <code>.replace</code> / <code>.wiggle</code> / <code>.breathe</code>，可视为 phase animator 的官方专用版；<code>MeshGradient</code> 自带可动画顶点（点本身是 <code>Animatable</code>）；<code>TextRenderer</code> 协议允许逐字 transform，与 <code>PhaseAnimator</code> 联用做打字与抖动效果。</li>
<li><strong>iOS 26</strong>：<code>Animation</code> 新增 <code>.materialBounce</code> / <code>.glassPop</code> 等 Liquid Glass 专用 spring preset；<code>KeyframeAnimator</code> 支持 <code>repeating: .infinite</code> + <code>autoreverses</code> 直接闭环（之前需要外层 trigger 重新触发）；新增 <code>PhaseTimeline</code>，等价于 <code>KeyframeTimeline</code> 但基于 enum phases，可被 <code>TimelineView</code> 单独驱动。</li>
<li>WWDC25 <em>Build a SwiftUI app with the new design</em>（Liquid Glass session）演示了 <code>matchedTransitionSource</code> + custom <code>Animation</code> 用于 zoom transition 的物理一致性。</li>
</ul>

<h3>2.11 选型决策表</h3>

<table>
<thead><tr><th>需求</th><th>首选 API</th><th>理由</th></tr></thead>
<tbody>
<tr><td>外部数值（progress、loading 百分比）单纯插值</td><td><code>Animatable</code> + 普通 <code>.animation(_, value:)</code></td><td>最轻、声明最少</td></tr>
<tr><td>shape / 自定义路径插值</td><td><code>Shape.animatableData</code></td><td>不会触发 layout，直接 path 重画</td></tr>
<tr><td>shake / 3D / 矩阵变换 / 不希望触发 layout</td><td><code>GeometryEffect</code></td><td>纯 compositing，便宜</td></tr>
<tr><td>多个属性同时多关键帧、有时间编排</td><td><code>KeyframeAnimator</code></td><td>多 track 各自独立曲线</td></tr>
<tr><td>有限状态循环 / 单次推进、状态语义清晰</td><td><code>PhaseAnimator</code></td><td>enum 表意，无需手算时间</td></tr>
<tr><td>非标准曲线 / 自实现物理 / 需要打断时保留速度</td><td><code>CustomAnimation</code></td><td>接管 animate/velocity/shouldMerge</td></tr>
<tr><td>不依赖 view 渲染，自绘 Canvas / Metal</td><td><code>KeyframeTimeline</code></td><td>纯采样、无 SwiftUI lifecycle</td></tr>
</tbody>
</table>

<h3>2.12 性能与 invalidation 模型</h3>

<ul>
<li><strong>每帧开销</strong>：<code>animatableData</code> 的 setter 每帧调用一次（120Hz ProMotion 即 8.3ms 内必须返回）。在 setter 里做 <code>sin</code>/<code>sqrt</code> 没问题，但避免分配（无 <code>Array</code> 创建、无 <code>String</code> 拼接）。</li>
<li><strong>body 重算</strong>：<code>KeyframeAnimator</code> 与 <code>PhaseAnimator</code> 的 closure 每帧调用，但只重算<strong>该闭包内</strong>的 view subtree，不会冒泡到父 view。把动画放在叶子节点能最小化 invalidation 半径。</li>
<li><strong>GeometryEffect vs offset</strong>：前者只走 layer transform；<code>.offset</code> 在 SwiftUI 中也是 transform，但 <code>.position</code>/<code>.frame</code> 会触发 layout pass。shake/flip 必须用 GeometryEffect。</li>
<li><strong>Spring 物理求解</strong>：<code>SpringKeyframe</code> 与 <code>.spring</code> 在内部用 closed-form 解析解（不是逐步积分），比手写欧拉法稳定且快。<code>CustomAnimation</code> 里如果需要积分，<strong>不要</strong>每次从 t=0 重算（如 2.5 示例那样），应在 <code>context.state</code> 里缓存上一帧 position/velocity，仅推进 <code>time - lastTime</code>。</li>
<li><strong>Repeating animation 内存</strong>：<code>repeatForever</code> + 复杂闭包会在 view 重 identity 时残留旧 driver；建议绑到稳定的 <code>id</code> 上。</li>
<li><strong>Reduce Motion</strong>：<code>@Environment(\.accessibilityReduceMotion)</code>，在 wave/shake/3D 场景下要降级为 fade。</li>
</ul>

<blockquote class="warning">
<p><strong>踩坑速查 / Pitfalls</strong></p>
<ul>
<li><code>animatableData</code> 必须既有 <code>get</code> 又有 <code>set</code>。漏掉 setter 编译过但<strong>不动</strong>。</li>
<li>多个 <code>animation()</code> modifier 顺序敏感：离 view 越近的越先生效，<code>animation(_, value:)</code> 只对其上方 modifier 生效。</li>
<li><code>GeometryEffect</code> 不影响 hit-testing 区域 —— 翻转 180° 后点击仍在原位，需手动 <code>.contentShape</code>。</li>
<li><code>CustomAnimation.animate</code> 返回 <code>nil</code> 才会停；忘记返回 nil 会让动画"假装结束"但 driver 还在跑，CPU 持续占用。</li>
<li><code>PhaseAnimator</code> 的 <code>animation:</code> 参数描述的是<strong>从该 phase 切到下一个</strong>的动画，不是停在该 phase 时的动画。容易写反。</li>
<li><code>KeyframeTrack</code> 的 keyframes 是<strong>累加时长</strong>，不是绝对时间戳。每个 keyframe 的 <code>duration</code> 是从前一帧到当前帧花的时间。</li>
<li><code>SpringKeyframe</code> 接力前一段速度，所以前段是 <code>LinearKeyframe(... duration: 0)</code> 时弹簧会直接从静止启动 —— 想要"突然弹"应该让前段有真实位移。</li>
<li>iOS 17 之前 <code>AnimatableModifier</code> 写法仍可编译但已 deprecated；改用 <code>ViewModifier &amp; Animatable</code>。</li>
<li>嵌套 <code>AnimatablePair</code> 超过 3 层时，<code>get/set</code> 解包错位极易写错；用 keyframe 多 track 替代。</li>
<li>Anycast 项目内 <code>PlaybackService</code> 时间观察 closure 在 main actor 上做 <code>@Published</code> 写入，若用此值驱动 <code>animatableData</code>，需要 <code>animation(.linear(duration: 0.5), value:)</code> 平滑跳变，否则进度环会"跳格"。</li>
</ul>
</blockquote>