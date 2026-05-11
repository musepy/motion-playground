<h3>7.1 Canvas 入门：完整签名与三大要素</h3>

<p><code>Canvas</code> 是 iOS 15 引入的低层级绘图视图，绕过 SwiftUI 的视图树直接调用 Core Graphics，性能远胜 ZStack 堆叠几百个 <code>Shape</code>。完整签名（iOS 15+）：</p>

<pre><code class="language-swift">// iOS 15+
public init(
    opaque: Bool = false,
    colorMode: ColorRenderingMode = .nonLinear,
    rendersAsynchronously: Bool = false,
    renderer: @escaping (inout GraphicsContext, CGSize) -> Void,
    @ViewBuilder symbols: () -> Symbols
)</code></pre>

<table>
<thead><tr><th>参数</th><th>含义 / 何时改</th></tr></thead>
<tbody>
<tr><td><code>opaque</code></td><td><code>true</code> 时跳过 alpha 合成，背景必须自己填满。深色全屏粒子背景设为 <code>true</code>，节省 ~10% GPU。</td></tr>
<tr><td><code>colorMode</code></td><td><code>.nonLinear</code>（sRGB，默认）/ <code>.linear</code>（线性混合，做 HDR 或正确叠加发光时用）/ <code>.extendedLinear</code>（HDR 显示器）。</td></tr>
<tr><td><code>rendersAsynchronously</code></td><td><code>true</code> 时把 renderer 闭包丢到后台线程跑，主线程只 commit。<strong>代价</strong>：闭包内不能捕获 <code>@MainActor</code> 状态。复杂粒子系统应开。</td></tr>
<tr><td><code>renderer</code></td><td>每帧调用，<code>inout GraphicsContext</code> 是绘图状态，<code>CGSize</code> 是 Canvas 当前尺寸。</td></tr>
<tr><td><code>symbols</code></td><td>预先声明的 SwiftUI 视图集合，每个用 <code>.tag(_)</code> 标识，renderer 内通过 <code>context.resolveSymbol(id:)</code> 取出绘制（详见 7.4）。</td></tr>
</tbody>
</table>

<h3>7.2 GraphicsContext：可变绘图状态</h3>

<p><code>GraphicsContext</code> 是 <strong>值类型</strong>（struct），所有变换都是状态拷贝——这是它能像栈一样压入/弹出 transform 的关键：</p>

<pre><code class="language-swift">// iOS 15+ — GraphicsContext 状态是值语义
Canvas { context, size in
    var inner = context              // 拷贝一份
    inner.translateBy(x: 100, y: 100)
    inner.rotate(by: .degrees(45))
    inner.fill(Path(CGRect(x: -20, y: -20, width: 40, height: 40)),
               with: .color(.orange))
    // 出闭包后 inner 释放，外层 context 不受影响
    context.fill(Path(CGRect(x: 0, y: 0, width: 10, height: 10)),
                 with: .color(.red))
}</code></pre>

<h4>7.2.1 几何绘制 API</h4>

<ul>
<li><code>stroke(_ path: Path, with: Shading, lineWidth: CGFloat = 1)</code> — 描边</li>
<li><code>fill(_ path: Path, with: Shading, style: FillStyle = FillStyle())</code> — 填充</li>
<li><code>draw(_ image: Image, in: CGRect)</code> / <code>draw(_ image: Image, at: CGPoint, anchor: UnitPoint = .center)</code></li>
<li><code>draw(_ text: Text, in: CGRect)</code> / <code>draw(_ text: Text, at: CGPoint)</code></li>
<li><code>draw(_ symbol: ResolvedSymbol, at:)</code> / <code>draw(_ symbol: ResolvedSymbol, in:)</code></li>
<li><code>resolve(_ image: Image)</code> / <code>resolve(_ text: Text)</code> / <code>resolveSymbol(id: AnyHashable)</code> — 把 SwiftUI 视图烘焙成可复用的 <code>Resolved*</code>，避免每帧重排版</li>
</ul>

<blockquote><p><strong>核心优化</strong>：<code>Text</code> 排版很贵。如果文字内容不变，每帧调 <code>context.draw(Text("..."))</code> 会重新做一次 typography 排版；改用 <code>let resolved = context.resolve(Text("..."))</code> 缓存。</p></blockquote>

<h4>7.2.2 Shading：填充/描边的颜色源</h4>

<pre><code class="language-swift">// iOS 15+
.color(.orange)
.color(in: .sRGB, red: 1, green: 0.5, blue: 0)
.linearGradient(Gradient(colors: [.red, .yellow]),
                startPoint: .zero, endPoint: CGPoint(x: 100, y: 100))
.radialGradient(_, center:, startRadius:, endRadius:)
.conicGradient(_, center:, angle:)
.tiledImage(_ image: Image, origin: .zero, sourceRect: nil, scale: 1)
.style(_ style: any ShapeStyle)</code></pre>

<h4>7.2.3 状态变换</h4>

<pre><code class="language-swift">// iOS 15+
context.translateBy(x: CGFloat, y: CGFloat)
context.scaleBy(x: CGFloat, y: CGFloat)
context.rotate(by: Angle)
context.concatenate(_ matrix: CGAffineTransform)
context.transform = CGAffineTransform.identity

context.clip(to path: Path, style: FillStyle = .init(), options: ClipOptions = [])
context.clipToLayer(opacity: 1, options: [], content: { ctx in /* ... */ })

context.opacity = 0.5
context.blendMode = .screen
context.addFilter(.blur(radius: 8))</code></pre>

<h4>7.2.4 GraphicsContext.Filter 全集</h4>

<table>
<thead><tr><th>Filter</th><th>用途</th></tr></thead>
<tbody>
<tr><td><code>.blur(radius:options:)</code></td><td>高斯模糊</td></tr>
<tr><td><code>.shadow(color:radius:x:y:blendMode:options:)</code></td><td>阴影，可设 .shadowAbove / .shadowOnly / .invertsAlpha</td></tr>
<tr><td><code>.colorMatrix(_)</code></td><td>4×5 色彩矩阵</td></tr>
<tr><td><code>.hueRotation(_)</code></td><td>色相旋转</td></tr>
<tr><td><code>.saturation(_)</code></td><td>饱和度</td></tr>
<tr><td><code>.brightness(_)</code> / <code>.contrast(_)</code></td><td>亮度/对比度</td></tr>
<tr><td><code>.colorMultiply(_)</code></td><td>每像素与给定颜色相乘</td></tr>
<tr><td><code>.colorInvert(amount:)</code></td><td>反色</td></tr>
<tr><td><code>.luminanceToAlpha</code></td><td>把亮度转成 alpha（做发光蒙版利器）</td></tr>
<tr><td><code>.alphaThreshold(min:max:color:)</code></td><td>alpha 阈值，做"金属液体球"融合效果</td></tr>
<tr><td><code>.projectionTransform(_)</code></td><td>3D 投影</td></tr>
</tbody>
</table>

<p><strong>Filter 的作用域</strong>：<code>addFilter</code> 只影响 <strong>之后</strong> 同一个 <code>GraphicsContext</code> 上的绘制。要把 filter 限定在一组绘制内，用 <code>drawLayer</code>：</p>

<pre><code class="language-swift">// iOS 15+ — 局部 filter，融合粒子做"金属球"
Canvas { context, size in
    context.drawLayer { layer in
        layer.addFilter(.alphaThreshold(min: 0.5, color: .orange))
        layer.addFilter(.blur(radius: 12))
        for p in particles {
            let path = Path(ellipseIn: CGRect(x: p.x - 20, y: p.y - 20,
                                              width: 40, height: 40))
            layer.fill(path, with: .color(.white))
        }
    }
}</code></pre>

<h3>7.3 Resolved* 与 symbols ViewBuilder</h3>

<p><code>symbols:</code> 闭包让你在 Canvas 外把 SwiftUI 视图（图标、按钮、复杂渐变）作为"模版"声明出来，每个用 <code>.tag(_)</code> 标识。renderer 内 <code>context.resolveSymbol(id:)</code> 拿到 <code>ResolvedSymbol</code>，可重复绘制——比每帧 <code>resolve(Image)</code> 快得多。</p>

<pre><code class="language-swift">// iOS 15+ — 用 symbols 让 Canvas 高效绘制带 SwiftUI 修饰的视图
struct EpisodeArtBurst: View {
    let positions: [CGPoint]
    var body: some View {
        Canvas { ctx, size in
            guard let art = ctx.resolveSymbol(id: 0) else { return }
            for p in positions {
                ctx.draw(art, at: p, anchor: .center)
            }
        } symbols: {
            Image(systemName: "waveform.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(AnycastColor.gold9, AnycastColor.sand4)
                .font(.system(size: 32))
                .tag(0)
        }
    }
}</code></pre>

<h3>7.4 TimelineView：时间驱动的视图刷新</h3>

<p><code>TimelineView</code>（iOS 15+）订阅一个 <code>TimelineSchedule</code>，按 schedule 给定的 <code>Date</code> 序列重建 body。它本身不做动画，只是"在这个时刻请你刷新一次"。</p>

<pre><code class="language-swift">// iOS 15+
TimelineView(_ schedule: some TimelineSchedule) { context in
    // context.date — 本帧应当渲染的时刻
    // context.cadence — .live / .seconds / .minutes
}</code></pre>

<h4>内置 schedule</h4>

<table>
<thead><tr><th>Schedule</th><th>触发频率</th><th>典型场景</th></tr></thead>
<tbody>
<tr><td><code>.everyMinute</code></td><td>每分钟整点</td><td>时钟显示</td></tr>
<tr><td><code>.periodic(from: Date, by: TimeInterval)</code></td><td>固定间隔</td><td>倒计时、轮询</td></tr>
<tr><td><code>.explicit(_)</code></td><td>显式日期序列</td><td>动画关键帧</td></tr>
<tr><td><code>.animation(minimumInterval:paused:)</code></td><td>display link 频率（60/120Hz）</td><td>每帧重绘的 Canvas / 粒子</td></tr>
</tbody>
</table>

<blockquote><p><strong>cadence</strong>：iOS 在低电量 / 后台时会把 cadence 降为 <code>.seconds</code> 或 <code>.minutes</code>，<code>.animation</code> schedule 也不例外。</p></blockquote>

<h3>7.5 实战：完整的粒子系统（烟花 / 庆祝订阅）</h3>

<pre><code class="language-swift">// iOS 17+（用 Observation；iOS 15-16 改 ObservableObject）
import SwiftUI
import Observation

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var birth: TimeInterval
    var lifespan: TimeInterval
    var hue: Double
    var size: CGFloat
}

@Observable
final class FireworksModel {
    var particles: [Particle] = []
    private var lastEmit: TimeInterval = 0

    func tick(now: TimeInterval, bounds: CGSize) {
        particles.removeAll { now - $0.birth &gt; $0.lifespan }
        let gravity = CGVector(dx: 0, dy: 220)
        for i in particles.indices {
            let dt: TimeInterval = 1.0 / 60.0
            particles[i].velocity.dy += gravity.dy * dt
            particles[i].position.x  += particles[i].velocity.dx * dt
            particles[i].position.y  += particles[i].velocity.dy * dt
        }
        if now - lastEmit &gt; 0.6 {
            lastEmit = now
            burst(at: CGPoint(x: .random(in: 60...bounds.width - 60),
                              y: .random(in: 100...bounds.height - 200)),
                  now: now)
        }
    }

    private func burst(at p: CGPoint, now: TimeInterval) {
        let count = 60
        let baseHue = Double.random(in: 0...1)
        for i in 0..&lt;count {
            let angle = (Double(i) / Double(count)) * .pi * 2
            let speed = Double.random(in: 80...200)
            particles.append(Particle(
                position: p,
                velocity: CGVector(dx: cos(angle) * speed,
                                   dy: sin(angle) * speed),
                birth: now,
                lifespan: .random(in: 0.9...1.6),
                hue: (baseHue + Double.random(in: -0.05...0.05))
                    .truncatingRemainder(dividingBy: 1),
                size: .random(in: 2...4)
            ))
        }
    }
}

struct FireworksView: View {
    @State private var model = FireworksModel()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
                Canvas(opaque: true,
                       colorMode: .linear,
                       rendersAsynchronously: true) { ctx, size in
                    ctx.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .color(.black))
                    let now = timeline.date.timeIntervalSinceReferenceDate
                    model.tick(now: now, bounds: size)
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 3))
                        layer.blendMode = .plusLighter
                        for p in model.particles {
                            let age = now - p.birth
                            let life = max(0, 1 - age / p.lifespan)
                            let color = Color(hue: p.hue,
                                              saturation: 0.9,
                                              brightness: 1)
                            let r = p.size * (0.6 + life)
                            let rect = CGRect(x: p.position.x - r,
                                              y: p.position.y - r,
                                              width: r * 2, height: r * 2)
                            var c = layer
                            c.opacity = life
                            c.fill(Path(ellipseIn: rect),
                                   with: .color(color))
                        }
                    }
                }
                .accessibilityRepresentation {
                    Text("订阅成功烟花动画")
                }
            }
        }
        .ignoresSafeArea()
    }
}</code></pre>

<h3>7.6 经典模式 2：实时音频波形可视化</h3>

<pre><code class="language-swift">// iOS 15+
struct WaveformBars: View {
    @ObservedObject var player: PlaybackService
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { ctx, size in
                let bins = player.fftBins
                let barWidth = size.width / CGFloat(bins.count) - 2
                for (i, mag) in bins.enumerated() {
                    let h = CGFloat(mag) * size.height
                    let rect = CGRect(
                        x: CGFloat(i) * (barWidth + 2),
                        y: size.height - h,
                        width: barWidth,
                        height: h)
                    let path = Path(roundedRect: rect, cornerRadius: 2)
                    ctx.fill(path, with: .linearGradient(
                        Gradient(colors: [AnycastColor.gold9,
                                          AnycastColor.orangeAlpha80]),
                        startPoint: CGPoint(x: 0, y: rect.maxY),
                        endPoint: CGPoint(x: 0, y: rect.minY)))
                }
            }
        }
        .accessibilityLabel("音频频谱")
    }
}</code></pre>

<h3>7.7 经典模式 3：环形 progress + 飞舞文字</h3>

<pre><code class="language-swift">// iOS 15+
struct LoadingPulse: View {
    let label: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 20

                var ring = Path()
                ring.addArc(center: center, radius: radius,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360),
                            clockwise: false)
                var rotated = ctx
                rotated.translateBy(x: center.x, y: center.y)
                rotated.rotate(by: .radians(t.truncatingRemainder(dividingBy: 2 * .pi)))
                rotated.translateBy(x: -center.x, y: -center.y)
                rotated.stroke(ring,
                               with: .color(AnycastColor.goldAlpha60),
                               style: StrokeStyle(lineWidth: 3,
                                                  dash: [4, 8]))

                let resolved = ctx.resolve(Text(label)
                    .font(AnycastFont.display(20))
                    .foregroundColor(AnycastColor.sand12))
                ctx.draw(resolved, at: center, anchor: .center)
            }
        }
        .frame(width: 160, height: 160)
        .accessibilityLabel(label)
    }
}</code></pre>

<h3>7.8 Canvas + Shader 边界（iOS 17+）</h3>

<p>iOS 17 的 <code>.colorEffect</code> / <code>.layerEffect</code> / <code>.distortionEffect</code> 是 SwiftUI <strong>视图修饰器</strong>。<strong>不能</strong>在 <code>GraphicsContext</code> 内部对单个 path/image 加 shader。两条路：</p>

<ul>
<li><strong>Canvas 在外，shader 套整个 Canvas</strong>：<code>Canvas { ... }.colorEffect(ShaderLibrary.myEffect())</code></li>
<li><strong>把单个粒子换成 SwiftUI View 走 symbols 路径</strong>，然后在外层视图 <code>.colorEffect</code></li>
</ul>

<h3>7.9 性能优化清单</h3>

<ul>
<li><strong>开 <code>rendersAsynchronously: true</code></strong>：复杂场景必开，闭包内严禁 MainActor 状态</li>
<li><strong>缓存 Path</strong>：圆形/矩形等不变形几何放 <code>let</code>，避免每帧分配</li>
<li><strong>缓存 ResolvedText / ResolvedImage</strong></li>
<li><strong>预算 transform</strong>：连续旋转用单个 <code>CGAffineTransform</code> concatenate</li>
<li><strong>opaque + 自填背景</strong></li>
<li><strong>limitFps</strong>：<code>.animation(minimumInterval: 1/60)</code> 显式封顶</li>
<li><strong>低电量降级</strong>：<code>context.cadence != .live</code> 时跳过物理积分</li>
</ul>

<h3>7.10 Accessibility</h3>

<p>Canvas 默认对 VoiceOver 完全不可见——它只是一块位图。</p>

<pre><code class="language-swift">// iOS 15+
Canvas { ... }
    .accessibilityRepresentation {
        VStack {
            Text("当前进度 \(Int(progress * 100))%")
            Text("剩余时间 \(remaining)")
        }
    }

Canvas { ... }
    .accessibilityElement()
    .accessibilityLabel("音频频谱可视化")
    .accessibilityValue("当前响度 \(Int(level * 100)) 分贝")</code></pre>

<h3>7.11 Canvas vs Animatable Shape</h3>

<table>
<thead><tr><th>选 Canvas 的场景</th><th>选 Shape + animatableData 的场景</th></tr></thead>
<tbody>
<tr><td>50+ 个独立元素同时动</td><td>1-10 个元素</td></tr>
<tr><td>需要 blendMode / filter 组合</td><td>简单形变（描边动画、波浪）</td></tr>
<tr><td>每帧物理模拟、生成式</td><td>SwiftUI 隐式动画驱动（<code>withAnimation</code>）</td></tr>
<tr><td>不需要触摸命中测试单个元素</td><td>需要 <code>.onTapGesture</code> 命中单个元素</td></tr>
<tr><td>不需要被 VoiceOver 单独读出</td><td>需要每个元素是独立 accessibility node</td></tr>
</tbody>
</table>

<p>Anycast 的封面墙、章节进度条、单个剧集卡片用 <strong>Shape</strong>；播放页粒子背景、波形、订阅成功烟花用 <strong>Canvas</strong>。</p>

<h3>7.12 iOS 18 / iOS 26 新增</h3>

<ul>
<li><strong>iOS 17</strong>：<code>MeshGradient</code> 不在 Canvas 内，但可作为 SwiftUI 背景</li>
<li><strong>iOS 18</strong>：<code>MeshGradient</code> 视图原生，Canvas 内可通过 <code>symbols</code> 嵌入</li>
<li><strong>iOS 26（Liquid Glass）</strong>：<code>GraphicsContext</code> 新增 <code>addFilter(.glass(...))</code> 系列；<code>TimelineView</code> 增加 <code>.frameDuration(_)</code> 显式帧间隔</li>
</ul>

<blockquote class="warning">
<p><strong>踩坑速查 / Pitfalls</strong></p>
<ul>
<li><strong>Async renderer 捕获主线程状态会崩</strong>：<code>rendersAsynchronously: true</code> 时闭包跑在后台，捕获 <code>@ObservableObject</code> 属性 → "Modifying state during view update" 或随机 EXC_BAD_ACCESS</li>
<li><strong>opaque=true 忘填背景 → 黑屏闪烁</strong>：opaque 模式下未绘制区域是<em>未定义内存</em></li>
<li><strong>Filter 顺序影响结果</strong>：<code>blur</code> 后加 <code>alphaThreshold</code> 是"金属球融合"，反过来是"模糊的硬边"</li>
<li><strong>TimelineView 后台不停</strong>：<code>.animation</code> schedule 在 app 进后台后仍会被偶发调用，看 <code>context.cadence</code></li>
<li><strong>Text resolve 只在 renderer 内有效</strong>：<code>ctx.resolve(Text(...))</code> 不能跨帧存到 <code>@State</code></li>
<li><strong>SF Symbol palette 模式必须走 symbols ViewBuilder</strong>：直接 <code>ctx.draw(Image(systemName:).symbolRenderingMode(.palette))</code> 会被忽略</li>
<li><strong>Canvas + .layerEffect 不可混用单元素</strong>：shader 只能套整个 Canvas 或外层包装视图</li>
<li><strong>VoiceOver 完全看不到 Canvas 内容</strong>：忘加 <code>accessibilityRepresentation</code> = 视障用户面对一块空白</li>
<li><strong>低电量模式 cadence 降级</strong>：粒子物理积分必须乘真实 dt（<code>now - lastFrame</code>），不能写死 <code>1/60</code></li>
<li><strong>linear colorMode 看起来会变暗</strong>：UI 设计稿对色得选 nonLinear</li>
<li><strong>ResolvedSymbol id 必须 Hashable 且稳定</strong>：用 <code>0, 1, 2</code> Int 最快</li>
<li><strong>drawLayer 内的 transform 不会泄漏到外层</strong></li>
</ul>
</blockquote>