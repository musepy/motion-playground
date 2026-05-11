<h3>10.1 Liquid Glass 概览：从 Material 到 Glass 的范式跃迁</h3>

<p>iOS 26 推出的 <strong>Liquid Glass</strong> 是 Apple 自 iOS 7 扁平化以来最大的视觉语言重构。与 iOS 15 引入的 <code>Material</code>（半透明高斯模糊）不同，Liquid Glass 是<strong>实时折射的 3D 物理材质</strong>：它会根据下层内容的颜色、亮度自适应地反射、折射、产生镜面高光，并在元素移动时模拟"液体表面"的形变。SwiftUI 把它封装成 <code>.glassEffect(_:in:isEnabled:)</code> 修饰符，仅在 iOS 26+ / iPadOS 26+ / macOS 26+ / visionOS 26+ 可用。</p>

<p>对 Anycast 而言，Liquid Glass 已经是设计基线：浮动播放器（FloatingPlayer）、Inbox 顶部的 category chips、Episode Detail 的 sticky toolbar、Now Playing 的 transport controls 都已迁移。</p>

<h3>10.2 .glassEffect 完整 API</h3>

<pre><code class="language-swift">// iOS 26+
extension View {
    func glassEffect(
        _ glass: Glass = .regular,
        in shape: some Shape = Capsule(),
        isEnabled: Bool = true
    ) -&gt; some View
}</code></pre>

<p>三个参数都是 optional，最简写法 <code>.glassEffect()</code> 等价于 <code>.glassEffect(.regular, in: Capsule())</code>。<code>Glass</code> 是 struct（不是 enum），通过链式修饰符构造：</p>

<table>
<thead><tr><th>Glass 工厂 / 修饰符</th><th>效果</th><th>使用场景</th></tr></thead>
<tbody>
<tr><td><code>.regular</code></td><td>默认材质，含柔和高光 + 折射 + 内阴影</td><td>大多数 UI 元素</td></tr>
<tr><td><code>.clear</code></td><td>更透明、几乎无背景填充</td><td>覆盖在富色彩内容上</td></tr>
<tr><td><code>.tint(Color)</code></td><td>叠加色调（半透明染色）</td><td>品牌色按钮，selected state</td></tr>
<tr><td><code>.interactive(Bool = true)</code></td><td>响应触摸：按下时形变、隆起</td><td>所有可点击元素</td></tr>
</tbody>
</table>

<pre><code class="language-swift">// iOS 26 — 标准浮动按钮
Button {
    app.openInbox()
} label: {
    Image(systemName: "tray.fill")
        .font(.system(size: 20, weight: .semibold))
        .frame(width: 56, height: 56)
}
.glassEffect(.regular.tint(AnycastColor.gold).interactive(),
             in: Circle())</code></pre>

<p>注意 <code>.tint</code> 的颜色不会"覆盖"下层，而是与折射结果做<strong>乘法混合</strong>。所以传 <code>.gold</code> 在白底上偏黄、在黑底上偏暗金。</p>

<h3>10.3 GlassEffectContainer 与多元素融合</h3>

<p>Liquid Glass 的精髓不是单个元素好看，而是<strong>多个 glass 元素彼此靠近时"流体融合"</strong>（metaball 效应）。这必须放在 <code>GlassEffectContainer</code> 内：</p>

<pre><code class="language-swift">// iOS 26 — Anycast Now Playing 的 transport row
GlassEffectContainer(spacing: 8) {
    HStack(spacing: 8) {
        ForEach(transportActions) { action in
            Button(action: action.handler) {
                Image(systemName: action.icon)
                    .frame(width: 44, height: 44)
            }
            .glassEffect(.regular.interactive(), in: Circle())
            .glassEffectID(action.id, in: glassNamespace)
        }
    }
}</code></pre>

<p>当两个 <code>.glassEffect</code> 元素的 frame 间距 ≤ container 的 <code>spacing</code> 时，它们会无缝融合成一个连续的玻璃形状。<code>spacing</code> 默认 <code>20</code>。</p>

<p><strong>glassEffectUnion(id:namespace:)</strong> — 强制把多个非邻近元素绑定为同一融合组：</p>

<pre><code class="language-swift">// iOS 26
@Namespace private var glass

GlassEffectContainer(spacing: 40) {
    HStack(spacing: 60) {
        capsule(label: "Subscribed").glassEffectUnion(id: "filter", namespace: glass)
        capsule(label: "Played").glassEffectUnion(id: "filter", namespace: glass)
        capsule(label: "Saved").glassEffectUnion(id: "filter", namespace: glass)
    }
}
// → 三个 capsule 仍被一根细玻璃"管道"连接</code></pre>

<p><strong>glassEffectID(_:in:)</strong> — 在容器内做 <code>matchedGeometryEffect</code> 风格的 morphing：</p>

<pre><code class="language-swift">// iOS 26 — toggle 状态切换时玻璃流动
@Namespace private var ns
@State private var expanded = false

GlassEffectContainer {
    if expanded {
        VStack { ... }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .glassEffectID("player", in: ns)
    } else {
        Capsule().fill(.clear).frame(width: 200, height: 56)
            .glassEffect(.regular, in: Capsule())
            .glassEffectID("player", in: ns)
    }
}
.animation(.spring(duration: 0.45, bounce: 0.25), value: expanded)</code></pre>

<h3>10.4 .glassEffectTransition — 进出场动画</h3>

<pre><code class="language-swift">// iOS 26
extension View {
    func glassEffectTransition(_ transition: GlassEffectTransition = .matchedGeometry,
                               isEnabled: Bool = true) -&gt; some View
}

// .matchedGeometry — 默认，跟随 glassEffectID
// .identity         — 关闭过渡（直接淡入淡出）</code></pre>

<h3>10.5 Toolbar / NavigationBar / TabBar 的 glass 默认</h3>

<p>iOS 26 起，<strong>所有系统 bar 的 background 默认就是 Liquid Glass</strong>，无需手动加。这意味着以下旧写法应被移除：</p>

<pre><code class="language-swift">// iOS 18 老写法 — iOS 26 不再需要
.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)

// iOS 26 — 仅在你想强制透明 / 强制隐藏时才用
.toolbarBackgroundVisibility(.hidden, for: .navigationBar)</code></pre>

<p><code>ToolbarItem</code> 内的按钮自动获得 glass 容器：</p>

<pre><code class="language-swift">// iOS 26
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Edit") { isEditing.toggle() }
    }
    ToolbarSpacer(.fixed, placement: .topBarTrailing)
    ToolbarItem(placement: .topBarTrailing) {
        Menu("More") { ... }
    }
}</code></pre>

<h3>10.6 buttonStyle(.glass) / .glassProminent</h3>

<pre><code class="language-swift">// iOS 26
Button("Subscribe") { ... }
    .buttonStyle(.glass)             // 中性

Button("Play Episode") { ... }
    .buttonStyle(.glassProminent)    // 强调
    .tint(AnycastColor.gold)

Button("Save") { ... }
    .buttonStyle(.glass)
    .controlSize(.large)</code></pre>

<p>这两个 style 自动包含 <code>.interactive()</code>、自动响应 dynamic type、自动支持 disabled 状态淡化。</p>

<h3>10.7 Material vs Liquid Glass 对照表</h3>

<table>
<thead><tr><th>维度</th><th>Material（iOS 15+）</th><th>Liquid Glass（iOS 26+）</th></tr></thead>
<tbody>
<tr><td>渲染模型</td><td>2D 高斯模糊 + 半透明色</td><td>3D 折射 + 镜面高光 + 边缘内阴影</td></tr>
<tr><td>触摸响应</td><td>无</td><td><code>.interactive()</code> 提供形变</td></tr>
<tr><td>多元素融合</td><td>不支持</td><td>GlassEffectContainer 自动 metaball 融合</td></tr>
<tr><td>形状</td><td>跟随 <code>.background(_:in:)</code> 的 shape</td><td>同左，但额外渲染折射边缘</td></tr>
<tr><td>动态 tint</td><td>需要叠 overlay</td><td><code>.tint(Color)</code> 物理混合</td></tr>
<tr><td>自适应亮 / 暗背景</td><td>颜色固定</td><td>实时采样下层颜色，自动调整 tint 与高光</td></tr>
<tr><td>性能</td><td>高斯模糊</td><td>Metal 着色器，比 Material 略贵但 GPU 已优化</td></tr>
<tr><td>API</td><td><code>.thinMaterial / .ultraThin / .regular / .thick / .ultraThick / .bar</code></td><td><code>Glass.regular / .clear</code> + 修饰符</td></tr>
<tr><td>SwiftUI 接入</td><td><code>.background(.thinMaterial)</code></td><td><code>.glassEffect(.regular, in: shape)</code></td></tr>
<tr><td>仍然适用</td><td>iOS 15–25 兼容、Lock Screen widget 背景</td><td>iOS 26+ 所有交互式悬浮元素</td></tr>
</tbody>
</table>

<p><strong>结论：</strong>新写 iOS 26+ 代码默认 Glass；要兼容 iOS 18 用 Material；Lock Screen / Widget / 深色 modal sheet 内容区仍可用 Material。</p>

<h3>10.8 .background(_:in:) 的统一接口</h3>

<pre><code class="language-swift">// 通用统一签名
.background(Color.red, in: Capsule())
.background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
.background(LinearGradient(...), in: Circle())

// iOS 26 — Glass 不走 .background(_:in:)，必须用专用 .glassEffect(_:in:)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))</code></pre>

<h3>10.9 Vibrancy：foregroundStyle 在 glass 上的表现</h3>

<pre><code class="language-swift">// iOS 26 — 自动 vibrancy
HStack {
    Image(systemName: "play.fill")
        .foregroundStyle(.primary)
    Text("Now Playing")
        .foregroundStyle(.secondary)
    Text("3:24")
        .foregroundStyle(.tertiary)
}
.padding(.horizontal, 16)
.padding(.vertical, 10)
.glassEffect(.regular, in: Capsule())</code></pre>

<p>关键：<strong>不要在 glass 上用具体 Color</strong>。优先 <code>.primary / .secondary / .tertiary / .quaternary</code>。如果必须 brand 色，用 <code>.tint(AnycastColor.gold)</code>。</p>

<h3>10.10 .scrollEdgeEffectStyle — 滚动边缘融化</h3>

<pre><code class="language-swift">// iOS 26
ScrollView { ... }
    .scrollEdgeEffectStyle(.soft, for: .top)
    .scrollEdgeEffectStyle(.hard, for: .bottom)</code></pre>

<h3>10.11 自适应：glass 如何感知背景</h3>

<p>Glass 内部对其下方约 20pt 范围做实时采样，决定：</p>

<ul>
<li>表层 tint 浓度</li>
<li>镜面高光位置</li>
<li>vibrancy 反相强度</li>
</ul>

<h3>10.12 sheet / popover 的 glass 默认</h3>

<pre><code class="language-swift">// iOS 26
.sheet(isPresented: $showSettings) {
    SettingsView()
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)  // 想退回 Material 时显式指定
}</code></pre>

<h3>10.13 性能：offscreen pass 与 glass 合并</h3>

<p>Liquid Glass 单个 glass 元素的 GPU 成本约为单 Material 的 1.3–1.6 倍。但有两点利好：</p>

<ol>
<li><strong>同一 GlassEffectContainer 内的多个 glass 共享一次 pass</strong></li>
<li><strong>静止状态下 glass 会被 cached</strong></li>
</ol>

<p>实战建议：</p>
<ul>
<li>Toolbar 自动在系统 container 里</li>
<li>自定义浮动 UI 显式包 <code>GlassEffectContainer</code></li>
<li>列表 cell 内独立 glass 元素 → 性能陷阱</li>
</ul>

<h3>10.14 兼容性：iOS 18 fallback</h3>

<pre><code class="language-swift">extension View {
    @ViewBuilder
    func anycastGlass&lt;S: Shape&gt;(_ shape: S, tint: Color? = nil) -&gt; some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(), in: shape)
            } else {
                self.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            self.background(.thinMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        }
    }
}</code></pre>

<h3>10.15 实战：Anycast 四个典型场景</h3>

<p><strong>(1) 浮动 Mini Player（底部悬浮 capsule）</strong></p>

<pre><code class="language-swift">// iOS 26
struct MiniPlayer: View {
    @EnvironmentObject var app: AppState
    @Namespace private var glass

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: app.currentArtwork) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(app.currentTitle).font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary).lineLimit(1)
                    Text(app.currentShow).font(.system(size: 12))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)

                Button { app.togglePlay() } label: {
                    Image(systemName: app.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .glassEffect(.regular.interactive(), in: Circle())
                .glassEffectID("playBtn", in: glass)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule())
            .glassEffectID("miniBg", in: glass)
        }
        .padding(.horizontal, AnycastSpacing.pageH)
    }
}</code></pre>

<p><strong>(2) 浮动 Search Bar</strong></p>

<pre><code class="language-swift">// iOS 26
HStack(spacing: 8) {
    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
    TextField("Search episodes", text: $query)
        .textFieldStyle(.plain)
    if !query.isEmpty {
        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
            .foregroundStyle(.tertiary)
    }
}
.padding(.horizontal, 14).padding(.vertical, 10)
.glassEffect(.regular, in: Capsule())
.padding(.horizontal, AnycastSpacing.pageH)
.scrollEdgeEffectStyle(.soft, for: .top)</code></pre>

<p><strong>(3) Toolbar 多 action 自动融合</strong></p>

<pre><code class="language-swift">// iOS 26 — 系统自动包 GlassEffectContainer
.toolbar {
    ToolbarItemGroup(placement: .topBarTrailing) {
        Button { share() } label: { Image(systemName: "square.and.arrow.up") }
        Button { save() }  label: { Image(systemName: "bookmark") }
        Menu { /* ... */ } label: { Image(systemName: "ellipsis") }
    }
}</code></pre>

<p><strong>(4) 通知 Capsule</strong></p>

<pre><code class="language-swift">// iOS 26
struct ToastCapsule: View {
    let text: String
    @State private var visible = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.tint)
            Text(text).foregroundStyle(.primary)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 16).padding(.vertical, 10)
        .glassEffect(.regular.tint(AnycastColor.gold), in: Capsule())
        .glassEffectTransition(.matchedGeometry)
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : -20)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.25)) { visible = false }
            }
        }
    }
}</code></pre>

<blockquote class="warning">
<strong>踩坑速查 / Pitfalls</strong>
<ul>
<li><strong>Deployment target 必须 iOS 26+</strong>。<code>.glassEffect</code> 在 iOS 25 及以下会编译警告或运行时崩溃</li>
<li><strong>过度堆叠 glass 会变浑浊</strong>。规则：一个层级路径上最多一层 glass</li>
<li><strong>tint contrast</strong>：<code>.tint</code> 是物理混合，深色 tint 放在亮底上几乎看不见</li>
<li><strong>不要在 glass 上写硬编码 Color 文字</strong>。用 <code>.primary/.secondary/.tertiary</code> 才能拿到 vibrancy</li>
<li><strong>GlassEffectContainer 必须包裹直接子视图</strong>，跨 NavigationStack / sheet 的 glass 不会融合</li>
<li><strong>列表 cell 每行一个 .glassEffect = 性能炸弹</strong></li>
<li><strong>不要 <code>.toolbarBackground(.thinMaterial, ...)</code></strong> 覆盖 iOS 26 的默认 glass</li>
<li><strong>SwiftUI Preview 渲染 glass 不准</strong>。Xcode 26 Preview 仍用 Material approximation</li>
<li><strong>动画化 glass 形状必须在 GlassEffectContainer 内</strong></li>
<li><strong>Accessibility / Reduce Transparency</strong>：用户开启 "降低透明度" 时，glass 自动退化为不透明纯色</li>
</ul>
</blockquote>