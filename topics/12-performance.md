<h3>12.1 渲染管线基础：SwiftUI 如何把 View 变成像素</h3>

<p>SwiftUI 的渲染分四个相对独立的阶段：<strong>body 求值</strong>（构造 View 值树）→ <strong>Diff</strong>（与上次树对比）→ <strong>Layout</strong>（自顶向下 propose / 自底向上 return）→ <strong>Display</strong>（合成到 Render Server）。WWDC 2023 "Demystify SwiftUI performance" 与 2024 "Explore SwiftUI performance" 反复强调：性能问题几乎都在前两步——<em>body 求值过频</em>或<em>identity 不稳定</em>。</p>

<p>调试时第一步永远是问：<strong>这个 body 一秒被调多少次？</strong>用 <code>let _ = Self._printChanges()</code> 插到 body 顶部。</p>

<pre><code class="language-swift">struct EpisodeRow: View {
    let episode: Episode
    var body: some View {
        let _ = Self._printChanges()
        HStack { /* ... */ }
    }
}</code></pre>

<h3>12.2 三种合成 modifier：drawingGroup / compositingGroup / geometryGroup</h3>

<h4>drawingGroup(opaque:colorMode:) — 离屏 Metal 栅格化</h4>

<p>把整个子树先用 Metal 栅格化到一张离屏 texture，再贴回去。<strong>真正适合的场景非常窄</strong>：</p>

<ul>
<li>子树包含大量 <code>Path</code> / <code>Shape</code> / <code>Canvas</code>，每帧重画很贵，但内容静态</li>
<li>子树要做整体的 <code>blur</code> / <code>colorMultiply</code> 等 expensive filter</li>
</ul>

<p><strong>反过来不该用</strong>：UIKit-style 普通布局；任何尺寸/内容会逐帧变；包含 text 的子树。</p>

<pre><code class="language-swift">// 差：静态复杂矢量没有缓存，每帧重画
struct WaveformView: View {
    let samples: [Float]
    var body: some View {
        Canvas { ctx, size in /* 上千段 path */ }
            .frame(height: 60)
    }
}

// 优：内容相对静态，整体只做 offset 滚动
struct WaveformView: View {
    let samples: [Float]
    var body: some View {
        Canvas { ctx, size in /* 上千段 path */ }
            .frame(height: 60)
            .drawingGroup()
    }
}</code></pre>

<h4>compositingGroup() — 强制中间合成层</h4>

<pre><code class="language-swift">// 差：两个重叠 circle 各自 0.5，重叠处实际 ≈ 0.75
ZStack {
    Circle().fill(.orange)
    Circle().fill(.gold).offset(x: 20)
}
.opacity(0.5)

// 优：先合成成一张图再整体 0.5
ZStack {
    Circle().fill(.orange)
    Circle().fill(.gold).offset(x: 20)
}
.compositingGroup()
.opacity(0.5)</code></pre>

<h4>geometryGroup() (iOS 17+) — 坐标快照原子化</h4>

<pre><code class="language-swift">// 差：matched + 父级 frame 同时动，子里的 image 会"先跳后拉"
ZStack {
    if expanded {
        ArtworkLarge(ep: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
    } else {
        ArtworkSmall(ep: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
    }
}

// 优：子树几何先打包再插值，过渡丝滑
ZStack {
    if expanded {
        ArtworkLarge(ep: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
            .geometryGroup()
    } else {
        ArtworkSmall(ep: ep)
            .matchedGeometryEffect(id: ep.id, in: ns)
            .geometryGroup()
    }
}</code></pre>

<h3>12.3 命中测试与 .allowsHitTesting</h3>

<pre><code class="language-swift">// 差：装饰用的渐变光晕也要参与 hit-test
ZStack {
    LinearGradient(...).blur(radius: 80)
    EpisodeContent(...)
}

// 优：装饰排除在 hit-test 之外
ZStack {
    LinearGradient(...).blur(radius: 80)
        .allowsHitTesting(false)
    EpisodeContent(...)
}</code></pre>

<h3>12.4 View Identity 与稳定性</h3>

<p>SwiftUI 决定"这个 view 是上一帧那个还是新的"靠 identity。Identity 一变 → 整个子树 teardown + recreate → @State 重置、动画重启、onAppear 再触发。</p>

<pre><code class="language-swift">// 差：ForEach 用 indices，插入/删除时 index 漂移
ForEach(episodes.indices, id: \.self) { i in
    EpisodeRow(episode: episodes[i])
}

// 优：用稳定业务 id
ForEach(episodes, id: \.id) { ep in
    EpisodeRow(episode: ep)
}

// 差：刷新数据时强行重建整个 ScrollView
ScrollView { LazyVStack { ForEach(items) { ... } } }
    .id(refreshCounter)

// 优：让 LazyVStack 自己 diff
ScrollView { LazyVStack { ForEach(items) { ... } } }</code></pre>

<h3>12.5 状态系统：@State / @Binding / @ObservableObject / @Observable / @Environment 失效边界</h3>

<table>
<thead><tr><th>Property Wrapper</th><th>失效粒度</th><th>iOS 版本</th><th>典型坑</th></tr></thead>
<tbody>
<tr><td><code>@State</code></td><td>当前 view 自身</td><td>13+</td><td>放进容易重建的子树会丢值</td></tr>
<tr><td><code>@Binding</code></td><td>读写 → 父级 invalidate</td><td>13+</td><td>不缓存身份</td></tr>
<tr><td><code>@ObservedObject</code></td><td>对象任何 <code>@Published</code> 变 → 持有方 invalidate</td><td>13+</td><td>"全有或全无"</td></tr>
<tr><td><code>@StateObject</code></td><td>同上，但生命周期绑 view</td><td>14+</td><td>放进 if 分支里会被反复创建</td></tr>
<tr><td><code>@Observable</code></td><td>只读哪个属性才订阅哪个</td><td>17+</td><td>必须 class</td></tr>
<tr><td><code>@Environment</code></td><td>该 key 变 → invalidate</td><td>13+</td><td>注入 ObservableObject 仍是粗粒度</td></tr>
</tbody>
</table>

<h4>iOS 17 Observation framework 的优化原理</h4>

<pre><code class="language-swift">// 差（iOS 16 风格）：读 player.currentTime 但 isPlaying / volume 任一变都重算
final class PlayerStore: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var isPlaying = false
    @Published var volume: Float = 1
}
struct ProgressLabel: View {
    @ObservedObject var store: PlayerStore
    var body: some View { Text(store.currentTime.formatted()) }
}

// 优（iOS 17+）：仅 currentTime 变才重算
@Observable final class PlayerStore {
    var currentTime: Double = 0
    var isPlaying = false
    var volume: Float = 1
}
struct ProgressLabel: View {
    let store: PlayerStore   // 普通 let，不需要 wrapper
    var body: some View { Text(store.currentTime.formatted()) }
}</code></pre>

<blockquote>项目内 <code>PlaybackService</code> 仍用 <code>@Published</code>，timer closure 60Hz 更新进度，导致整张 NowPlaying view 每秒重算 60 次。迁移到 <code>@Observable</code> 后，仅 <code>ScrubSlider</code> 与 <code>Text(time)</code> 命中失效。</blockquote>

<h3>12.6 EquatableView / View: Equatable / .equatable()</h3>

<pre><code class="language-swift">struct EpisodeRow: View, Equatable {
    let episode: Episode
    let isPlaying: Bool
    let now: Date

    static func == (l: Self, r: Self) -> Bool {
        l.episode.id == r.episode.id && l.isPlaying == r.isPlaying
    }
    var body: some View { /* ... */ }
}

EpisodeRow(episode: ep, isPlaying: playing, now: now).equatable()</code></pre>

<h3>12.7 PreferenceKey 的成本</h3>

<p>PreferenceKey 是子→父反向通信通道，但 reduce 在每次 layout 都跑一次，且会把消息冒泡到祖先链上。长列表里给每行加 <code>.preference(key:)</code> 收集 frame 是常见性能黑洞。能用 <code>onGeometryChange</code> (iOS 18+) 或者直接 <code>GeometryReader</code> 局部测量就别冒泡。</p>

<h3>12.8 Lazy 容器 cell reuse 与 onAppear</h3>

<p><code>LazyVStack</code> / <code>LazyHStack</code> / <code>LazyVGrid</code> 只在 cell 进入<strong>可视 + prefetch 区</strong>时才求值 body。两个推论：</p>

<ul>
<li><code>onAppear</code> 在 cell 滚回来时<strong>会再次触发</strong></li>
<li>cell 内 <code>@State</code> 滚出去再滚回来会丢值</li>
</ul>

<pre><code class="language-swift">// 差：用 VStack（非 Lazy），1000 行全部立即求值
ScrollView {
    VStack {
        ForEach(episodes) { EpisodeRow(episode: $0) }
    }
}

// 优：LazyVStack 仅渲染可视附近
ScrollView {
    LazyVStack(spacing: AnycastSpacing.gap) {
        ForEach(episodes) { EpisodeRow(episode: $0) }
    }
}</code></pre>

<h3>12.9 动画 Animatable：选错插值字段的代价</h3>

<p>SwiftUI 的动画通过 <code>Animatable</code> protocol 的 <code>animatableData</code> 在每个 display frame 重算 view。<strong>插 frame.width / height 等几何字段 → 触发整子树 layout invalidation</strong>，<strong>插 scale / offset / rotation → 走 transform 路径，layout 不变</strong>。</p>

<pre><code class="language-swift">// 差：动 width 触发每帧 layout
ArtworkView(ep: ep)
    .frame(width: expanded ? 320 : 64,
           height: expanded ? 320 : 64)
    .animation(.spring, value: expanded)

// 优：固定 frame，用 scaleEffect 走 transform
ArtworkView(ep: ep)
    .frame(width: 64, height: 64)
    .scaleEffect(expanded ? 5 : 1, anchor: .topLeading)
    .animation(.spring, value: expanded)</code></pre>

<p><strong>基准</strong>（iPhone 17 Pro / iOS 26 / Release / 50 行 ScrollView）：frame 插值平均 ≈ 18ms（持续掉帧 ~55fps），scaleEffect 平均 ≈ 5.4ms（稳 120fps）。</p>

<p><code>blur(radius:)</code> 与 <code>shadow</code> 走 GPU 模糊 pass，半径越大成本越高，动画 blur 半径几乎一定掉帧；改用预渲两份 + opacity 切换。</p>

<h3>12.10 transaction / withAnimation 的失效边界</h3>

<pre><code class="language-swift">// 局部禁动画
List(episodes) { ep in
    EpisodeRow(episode: ep)
}
.transaction { $0.animation = nil }   // reload 整列不动画
</code></pre>

<h3>12.11 Canvas / Shader：GPU vs CPU 权衡</h3>

<p><code>Canvas</code> 在 main thread 跑 closure 把命令录入 displayList，再交给 Metal 上 GPU 画。优势是 path 数量大时仍只有一次 draw call。<code>colorEffect / layerEffect / distortionEffect</code>（iOS 17+）走真正的 Metal Shading Language fragment shader，能做实时变形/调色。简单视觉效果优先 SwiftUI 原生 modifier；复杂矢量大量绘制选 <code>Canvas</code>；像素级实时滤镜才考虑 Shader。</p>

<h3>12.12 60Hz vs ProMotion 120Hz：TimelineView 与 CADisplayLink</h3>

<p>iPhone 13 Pro 起的 ProMotion 屏幕 1–120Hz 自适应。要让动画真跑 120Hz 必须满足两个条件：(1) 屏幕被驱动到 120Hz；(2) 你的渲染 closure 也按 120Hz 节奏更新 state。</p>

<p><code>TimelineView(.animation)</code> 默认绑 display refresh，会在每个 vsync 重算 closure。播客 waveform 这种"每帧推进"的场景用它而不是 <code>Timer</code>。</p>

<pre><code class="language-swift">// 优：vsync-aligned，ProMotion 自动 120Hz
TimelineView(.animation) { ctx in
    Canvas { gc, size in
        drawWave(at: ctx.date, in: gc, size: size)
    }
}</code></pre>

<h3>12.13 Instruments：SwiftUI / Animation Hitches / Time Profiler</h3>

<ol>
<li><strong>SwiftUI template</strong>（Xcode 15+）：含 "View Body" 与 "View Properties" track</li>
<li><strong>Animation Hitches template</strong>：以 hitch ratio 标红</li>
<li><strong>Time Profiler</strong>：传统 sampling profiler</li>
<li><strong>Core Animation</strong> template：看 commit、prepare、render-server 三阶段时间</li>
</ol>

<h4>命令行 profiling 流程（搭配本项目 swiftc 构建）</h4>

<pre><code class="language-swift">// 1. Release build (build_anycast.sh 加 -O -whole-module-optimization)
// 2. Boot + install 同 CLAUDE.md
// 3. 启动并 attach Instruments
//    xcrun xctrace record \
//      --template 'SwiftUI' \
//      --device 7DBDB4C8-B748-4693-B7C9-2A4E2E046E54 \
//      --launch -- com.anycast.app \
//      --output /tmp/anycast.trace
// 4. open /tmp/anycast.trace</code></pre>

<h3>12.14 减少 ViewBody 计算的工程手段</h3>

<ul>
<li><strong>拆 struct，不要拆函数</strong>：<code>@ViewBuilder</code> 子函数返回的 view 仍属于父 view 的 body</li>
<li>把"频繁变 + 视觉无关"的 state 从 view 里移出去</li>
<li>computed property 避免在 body 里跑 O(n) 工作</li>
<li>避免在 body 里 <code>Date()</code> / <code>UUID()</code> / 立即执行闭包</li>
</ul>

<pre><code class="language-swift">// 差：closure 里 capture 大对象 + 在 body 里建
struct EpisodeList: View {
    let episodes: [Episode]
    let store: PlayerStore
    var body: some View {
        let formatter = DateFormatter()      // 每帧新建
        formatter.dateStyle = .medium
        return ForEach(episodes) { ep in
            Button { store.play(ep) } label: {
                Text(formatter.string(from: ep.publishedAt))
            }
        }
    }
}

// 优：拆子 struct + static formatter
private let episodeDateFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateStyle = .medium; return f
}()

struct EpisodeList: View {
    let episodes: [Episode]
    let store: PlayerStore
    var body: some View {
        ForEach(episodes) { ep in
            EpisodeRowButton(episode: ep, store: store)
        }
    }
}
private struct EpisodeRowButton: View {
    let episode: Episode
    let store: PlayerStore
    var body: some View {
        Button { store.play(episode) } label: {
            Text(episodeDateFormatter.string(from: episode.publishedAt))
        }
    }
}</code></pre>

<h3>12.15 Memory：ImageCache、Drawable、Canvas</h3>

<p><code>AsyncImage</code> 不缓存，每次 view 出现重下；项目里 <code>EpisodeArtwork</code> 用了自建 <code>ImageCache</code>。<code>Canvas</code> 内 <code>ctx.resolve(Image(...))</code> 返回的 <code>ResolvedImage</code> 持有 GPU drawable，长列表对每行 resolve 大图会迅速吃满 IOSurface。</p>

<ul>
<li>大图先 downsample 到展示尺寸再 cache</li>
<li><code>NSCache.totalCostLimit</code> 设到设备 RAM 1/8</li>
<li>大型 <code>Canvas</code> 配 <code>drawingGroup</code> 会吃大块 IOSurface</li>
</ul>

<h3>12.16 反模式合集</h3>

<pre><code class="language-swift">// 反模式 1：在 body 里直接 await
struct Bad: View {
    var body: some View {
        Text(await loadTitle())   // 编译错；正确：.task { ... }
    }
}

// 反模式 2：ScrollView 加非必要 .id() 强制 rebuild
ScrollView { ... }.id(refreshCounter)

// 反模式 3：ForEach 用 indices 当 id
ForEach(items.indices, id: \.self) { ... }

// 反模式 4：在 body 里 capture 大对象的 closure
Button { let copy = bigArray; process(copy) } label: { ... }

// 反模式 5：每个 cell 都加 .preference(key:) 冒泡 frame
ForEach(items) { $0.background(GeometryReader { ... .preference(...) }) }

// 反模式 6：动 frame.width 而非 scaleEffect
.frame(width: w).animation(.spring, value: w)

// 反模式 7：把 @StateObject 放进 if 分支
if shown { Foo(store: StateObject(wrappedValue: Store())) }</code></pre>

<blockquote class="warning"><strong>踩坑速查 / Pitfalls</strong>
<ul>
<li><strong>drawingGroup 不是性能开关</strong>：动态内容用它每帧重 rasterize，比不用还慢；含 text 子树用了会失去字体 metrics</li>
<li><strong>ForEach id 永远用业务 stable id</strong>，<code>indices</code> / <code>\.self</code> 在数据可变时引发整列 rebuild</li>
<li><strong>animate frame.width / height = 必掉帧</strong>，用 <code>.scaleEffect</code> / <code>.offset</code> / <code>.rotationEffect</code></li>
<li><strong>blur 半径不能动画</strong>，每帧重跑 GPU 模糊 pass</li>
<li><strong>@ObservedObject 是粗粒度订阅</strong>，能升 iOS 17 就用 <code>@Observable</code></li>
<li><strong>@ViewBuilder 子函数 ≠ 独立 view identity</strong>，要复用必须拆子 struct</li>
<li><strong>不要在 body 里 <code>Date()</code> / <code>DateFormatter()</code> / 立即执行闭包</strong></li>
<li><strong>ScrollView 上加 <code>.id()</code> 让 contentOffset 归零、cell <code>onAppear</code> 全部重跑</strong></li>
<li><strong>PreferenceKey 在长列表逐 cell 上报 = 性能黑洞</strong></li>
<li><strong>compositingGroup 与 drawingGroup 都会建中间层 IOSurface</strong></li>
<li><strong>Debug build 的 SwiftUI runtime 多埋点</strong>，profile 必须 Release + <code>-O</code></li>
<li><strong>TimelineView(.animation) 与 Timer 行为不同</strong>，前者绑 vsync，后者按 wall clock</li>
</ul>
</blockquote>