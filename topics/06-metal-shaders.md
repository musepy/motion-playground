<h3>6.1 SwiftUI Shader 三大入口概览</h3>

<p>iOS 17 起，SwiftUI 通过三个 ViewModifier 直接把 Metal Shading Language（MSL）函数挂到任意 View 的渲染管线上，无需 <code>MTKView</code>、无需 <code>CADisplayLink</code>、无需自己写 RenderPass。这套 API 在 WWDC23 Session 10115 "Wonders of shader effects in SwiftUI" 中首次亮相，本质是把 SwiftUI 的离屏纹理交给一段 fragment-style 的 MSL 函数处理后再合成到屏幕。</p>

<table>
<thead><tr><th>Modifier</th><th>用途</th><th>MSL 输入</th><th>MSL 输出</th></tr></thead>
<tbody>
<tr><td><code>.colorEffect(_:isEnabled:)</code></td><td>逐像素重新着色，不改位置</td><td><code>float2 position, half4 color</code></td><td><code>half4</code></td></tr>
<tr><td><code>.distortionEffect(_:maxSampleOffset:isEnabled:)</code></td><td>UV 重映射，移动像素</td><td><code>float2 position</code></td><td><code>float2</code>（采样源坐标）</td></tr>
<tr><td><code>.layerEffect(_:maxSampleOffset:isEnabled:)</code></td><td>访问整张已渲染 layer，可任意采样</td><td><code>float2 position, SwiftUI::Layer layer</code></td><td><code>half4</code></td></tr>
</tbody>
</table>

<p>三者代价递增：<strong>colorEffect</strong> 不需要 SwiftUI 给你纹理（每像素只看自己的颜色），最便宜；<strong>distortionEffect</strong> 输出新 UV、由 SwiftUI 用 linear sampler 取颜色，中等；<strong>layerEffect</strong> 把整张 view 离屏栅格化为 <code>SwiftUI::Layer</code> 后传入，可在 shader 内做模糊、卷积、镜像、毛玻璃，最贵。</p>

<h3>6.2 Shader / ShaderFunction / ShaderLibrary</h3>

<p><code>Shader</code> 是「函数 + 参数列表」的结构体，由 <code>ShaderFunction</code>（指向 .metal 里某个具名函数）和一组 <code>Shader.Argument</code> 组成。<code>ShaderLibrary.default</code> 暴露 main bundle 编译进去的所有 MSL 函数，<code>dynamicMember</code> 让你可以直接 <code>ShaderLibrary.default.myShader</code> 拿到 <code>ShaderFunction</code>；动态函数名时用 <code>library[dynamicMember:]</code> 或 <code>library[function: ShaderFunction(name:library:)]</code>。</p>

<pre><code class="language-swift">import SwiftUI

struct GoldTint: View {
    var body: some View {
        Image("episode-art")
            .resizable()
            .scaledToFit()
            .colorEffect(
                ShaderLibrary.default.goldTint(
                    .float(0.85),
                    .color(AnycastColor.goldAlpha60)
                )
            )
    }
}
</code></pre>

<pre><code class="language-cpp">// AnycastShaders.metal
#include &lt;metal_stdlib&gt;
#include &lt;SwiftUI/SwiftUI_Metal.h&gt;
using namespace metal;

[[ stitchable ]] half4 goldTint(float2 position, half4 color,
                                float strength, half4 tint) {
    half3 mixed = mix(color.rgb, tint.rgb, half(strength) * color.a);
    return half4(mixed, color.a);
}
</code></pre>

<p>关键属性 <code>[[ stitchable ]]</code> 是必须的——它告诉 Metal 编译器把这函数纳入 SwiftUI 在运行时拼接出的渲染管线（function stitching）。没有这个标记，<code>ShaderLibrary</code> 找不到符号，运行期会静默 fallback 到原图。</p>

<h3>6.3 Shader.Argument 全谱</h3>

<table>
<thead><tr><th>Swift</th><th>MSL</th><th>用途</th></tr></thead>
<tbody>
<tr><td><code>.float(0.5)</code></td><td><code>float</code></td><td>标量（time、strength）</td></tr>
<tr><td><code>.float2(.init(x,y))</code></td><td><code>float2</code></td><td>UV、中心点</td></tr>
<tr><td><code>.float3 / .float4</code></td><td>同名</td><td>向量（颜色除外）</td></tr>
<tr><td><code>.floatArray([Float])</code></td><td><code>device const float*</code></td><td>直方图、波形数组</td></tr>
<tr><td><code>.color(Color)</code></td><td><code>half4</code></td><td>SwiftUI 颜色，自动转 sRGB→Metal</td></tr>
<tr><td><code>.image(Image)</code></td><td><code>texture2d&lt;half&gt;</code></td><td>额外纹理（mask/lookup）</td></tr>
<tr><td><code>.data(Data)</code></td><td><code>device const uint8_t*</code></td><td>任意二进制 buffer</td></tr>
<tr><td><code>.boundingRect</code></td><td><code>float4 (x,y,w,h)</code></td><td>view 自身 bounds，做 normalize</td></tr>
</tbody>
</table>

<blockquote><strong>语义注意</strong>：<code>.color</code> 在 Swift 侧是 sRGB（display P3 在 iOS 17+），到 MSL 已经是 <em>display-referred</em> 的 <code>half4</code>。如果你又在 shader 里做 <code>pow(color.rgb, 2.2)</code> 等于二次 gamma 校正，画面会发暗。</blockquote>

<h3>6.4 时间动画：TimelineView 注入 time</h3>

<p>SwiftUI 没有「shader uniform 自动 tick」机制，要自己用 <code>TimelineView(.animation)</code> 每帧把 <code>Date</code> 转成 <code>Float</code> 喂进去。<code>.animation</code> 默认 60fps（ProMotion 设备 120fps），按 <code>schedule</code> 调整。</p>

<pre><code class="language-swift">struct ShimmerCard: View {
    let start = Date()
    var body: some View {
        TimelineView(.animation) { ctx in
            let t = Float(ctx.date.timeIntervalSince(start))
            AnycastColor.sand4
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .colorEffect(
                    ShaderLibrary.default.shimmer(
                        .float(t),
                        .boundingRect
                    )
                )
        }
    }
}
</code></pre>

<pre><code class="language-cpp">[[ stitchable ]] half4 shimmer(float2 pos, half4 color,
                               float time, float4 bounds) {
    float u = (pos.x - bounds.x) / bounds.z;
    float wave = 0.5 + 0.5 * sin((u - time * 0.6) * 6.2831);
    half3 sheen = half3(1.0, 0.92, 0.78);
    return half4(mix(color.rgb, sheen, half(wave) * 0.35h), color.a);
}
</code></pre>

<h3>6.5 完整示例：Ripple Distortion（点击涟漪）</h3>

<p>这是最经典的 distortionEffect 用例：用户点击一个点，从中心向外发出一圈正弦涟漪，几百毫秒后衰减消失。</p>

<pre><code class="language-swift">import SwiftUI

struct Ripple: ViewModifier {
    var origin: CGPoint
    var elapsedTime: TimeInterval

    let duration: TimeInterval = 1.2
    let amplitude: Float = 12
    let frequency: Float = 18
    let decay: Float = 4
    let speed: Float = 800

    func body(content: Content) -&gt; some View {
        let shader = ShaderLibrary.default.ripple(
            .float2(.init(x: origin.x, y: origin.y)),
            .float(Float(elapsedTime)),
            .float(amplitude),
            .float(frequency),
            .float(decay),
            .float(speed)
        )
        content.distortionEffect(
            shader,
            maxSampleOffset: CGSize(width: CGFloat(amplitude),
                                    height: CGFloat(amplitude)),
            isEnabled: elapsedTime &lt; duration
        )
    }
}

struct RippleContainer&lt;Content: View&gt;: View {
    @ViewBuilder var content: () -&gt; Content
    @State private var origin: CGPoint = .zero
    @State private var trigger = 0

    var body: some View {
        content()
            .onTapGesture { loc in
                origin = loc
                trigger += 1
            }
            .modifier(RippleEffectModifier(origin: origin, trigger: trigger))
    }
}

private struct RippleEffectModifier: ViewModifier {
    var origin: CGPoint
    var trigger: Int

    func body(content: Content) -&gt; some View {
        content.keyframeAnimator(
            initialValue: 0.0,
            trigger: trigger
        ) { view, elapsed in
            view.modifier(Ripple(origin: origin, elapsedTime: elapsed))
        } keyframes: { _ in
            MoveKeyframe(0)
            LinearKeyframe(1.2, duration: 1.2)
        }
    }
}
</code></pre>

<pre><code class="language-cpp">// Ripple.metal
#include &lt;metal_stdlib&gt;
#include &lt;SwiftUI/SwiftUI_Metal.h&gt;
using namespace metal;

[[ stitchable ]] float2 ripple(float2 position,
                               float2 origin,
                               float time,
                               float amplitude,
                               float frequency,
                               float decay,
                               float speed) {
    float2 d = position - origin;
    float r = length(d);

    float front = time * speed;
    float delta = r - front;

    float wave = sin(frequency * delta * 0.05) *
                 exp(-decay * time) *
                 exp(-abs(delta) * 0.01);

    float2 dir = r &gt; 0.0001 ? d / r : float2(0);
    return position + dir * wave * amplitude;
}
</code></pre>

<p>调用：<code>RippleContainer { Image("artwork").resizable().scaledToFit() }</code>，点哪儿哪儿涟漪。<code>maxSampleOffset</code> 必须给出 ≥ amplitude 的范围，否则边缘像素采样越界会被 clamp 成黑边——SwiftUI 用这个值决定离屏纹理的 padding。</p>

<h3>6.6 layerEffect：访问整张 layer 做卷积</h3>

<p><code>SwiftUI::Layer</code> 提供 <code>sample(float2)</code>，等同于 GLSL 的 <code>texture2D</code>。它已经过 SwiftUI 的离屏栅格化，所以你拿到的是「这一帧 view 的最终纹理」，可以做高斯模糊、菱形抖动、油画、glitch。</p>

<pre><code class="language-swift">struct ChromaticAberration: ViewModifier {
    var amount: Float
    func body(content: Content) -&gt; some View {
        content.layerEffect(
            ShaderLibrary.default.chromaticAberration(.float(amount)),
            maxSampleOffset: CGSize(width: CGFloat(amount),
                                    height: CGFloat(amount))
        )
    }
}
</code></pre>

<pre><code class="language-cpp">[[ stitchable ]] half4 chromaticAberration(float2 pos,
                                           SwiftUI::Layer layer,
                                           float amount) {
    half r = layer.sample(pos + float2( amount, 0)).r;
    half g = layer.sample(pos).g;
    half b = layer.sample(pos + float2(-amount, 0)).b;
    half a = layer.sample(pos).a;
    return half4(r, g, b, a);
}
</code></pre>

<h3>6.7 噪声 / 颗粒 / Vignette（colorEffect）</h3>

<p>colorEffect 因为不需要重采样、SwiftUI 不需要离屏，是性能最低的入口。Anycast 卡片的 sand grain 颗粒就用这个：</p>

<pre><code class="language-swift">extension View {
    func sandGrain(intensity: Float = 0.04, time: Float) -&gt; some View {
        colorEffect(
            ShaderLibrary.default.filmGrain(
                .float(intensity),
                .float(time),
                .boundingRect
            )
        )
    }
}
</code></pre>

<pre><code class="language-cpp">inline float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

[[ stitchable ]] half4 filmGrain(float2 pos, half4 color,
                                 float intensity, float time, float4 bounds) {
    float2 uv = (pos - bounds.xy) / bounds.zw;
    float n  = hash21(uv * 800.0 + time * 60.0) - 0.5;
    half3 grained = color.rgb + half(n * intensity);
    float2 c = uv - 0.5;
    float v = 1.0 - dot(c, c) * 0.6;
    return half4(grained * half(v), color.a);
}
</code></pre>

<h3>6.8 Shader 与 Animatable / 物理插值</h3>

<p>Shader 本身不是 <code>Animatable</code>。要让 amplitude / hue / threshold 等参数被 SwiftUI 动画系统插值，把外层 ViewModifier 标记为 <code>Animatable</code>，由 SwiftUI 每帧重建 Shader：</p>

<pre><code class="language-swift">struct PulseHue: ViewModifier, Animatable {
    var hue: Double
    var animatableData: Double {
        get { hue } set { hue = newValue }
    }
    func body(content: Content) -&gt; some View {
        content.colorEffect(
            ShaderLibrary.default.hueShift(.float(Float(hue)))
        )
    }
}

.modifier(PulseHue(hue: isPlaying ? 0.15 : 0))
.animation(.easeInOut(duration: 1.2).repeatForever(), value: isPlaying)
</code></pre>

<p>这样每一帧 SwiftUI 都拿到一个新的 hue，重建 Shader 实例。Shader 结构体是 cheap 的——它只是参数包，真正的 GPU pipeline 状态被 Metal 缓存。</p>

<h3>6.9 MetalKit 路线（MTKView via UIViewRepresentable）</h3>

<p>什么时候离开 SwiftUI shader API、改用 MTKView？</p>
<ul>
<li>需要多 pass 渲染（feedback、流体模拟、GPU 粒子）</li>
<li>需要 compute kernel + draw 混合</li>
<li>需要自定义 vertex shader（SwiftUI 只给 fragment-style）</li>
<li>帧率严格保 120fps，不能容忍 SwiftUI 离屏带来的合成开销</li>
<li>需要直接读 <code>CVMetalTexture</code>（视频纹理）</li>
</ul>

<pre><code class="language-swift">struct FluidView: UIViewRepresentable {
    func makeUIView(context: Context) -&gt; MTKView {
        let v = MTKView()
        v.device = MTLCreateSystemDefaultDevice()
        v.colorPixelFormat = .bgra8Unorm_srgb
        v.framebufferOnly = false
        v.delegate = context.coordinator
        v.preferredFramesPerSecond = 120
        return v
    }
    func updateUIView(_ uiView: MTKView, context: Context) {}
    func makeCoordinator() -&gt; Renderer { Renderer() }
}
</code></pre>

<p>性能对比：SwiftUI shader 的 overhead 主要来自 <code>distortion/layerEffect</code> 的离屏栅格化（一张 view 走一次 render pass 才能交给 shader）。简单 colorEffect 实测和直接 Metal pipeline 几乎一致。复杂多 pass 场景，MTKView 仍然完胜。</p>

<h3>6.10 Compute Shader 桥接</h3>

<p>SwiftUI 三大入口都是 fragment-style，没法直接挂 <code>kernel</code> 函数。两条路：</p>
<ol>
<li>把 compute pass 包进 <code>CIFilter</code>（<code>CIKernel(functionName:fromMetalLibraryData:)</code>），再用 <code>Image(uiImage:)</code> 显示</li>
<li>离屏跑 compute → 写到 <code>MTLTexture</code> → 包成 <code>CIImage</code> / <code>UIImage</code> → SwiftUI <code>Image</code></li>
</ol>

<h3>6.11 性能：每帧重建 Shader 与 maxSampleOffset</h3>

<p><code>TimelineView(.animation)</code> 每帧 invalidate 整个子树。Shader 实例本身是值类型——重建无压力，但若每帧 view body 还做了昂贵的视图重组，会在 main thread 上掉帧。建议把 Shader 局部限定，外层包 <code>.drawingGroup()</code> 让 Metal 一次性合成（避免合成层数过多）。</p>

<p><code>maxSampleOffset</code> 决定 SwiftUI 给你的离屏纹理 padding：值越大，离屏纹理越大，带宽越高。给个比真实最大偏移略大的 ceil 即可，不要无脑写 <code>CGSize(width: 100, height: 100)</code>。</p>

<h3>6.12 iOS 18 / 26 更新</h3>

<ul>
<li>iOS 18：Shader API 稳定，新增对 <code>Color</code> 在 P3 / extended sRGB 下的更准确转换；<code>SwiftUI::Layer</code> 支持 <code>sample()</code> 的 mipmap 提示</li>
<li>iOS 26（Liquid Glass）：Apple 重写 Material 系统，<code>.glassEffect()</code> 内部就是一组 layerEffect + Gaussian + 边缘光，但 API 不暴露 shader 给 user code；用户自定义 shader 仍走 iOS 17 三入口</li>
<li>iOS 26 引入 <code>MeshGradient</code>，部分原本要 shader 实现的渐变可以直接用 mesh 完成，性能更好</li>
</ul>

<h3>6.13 调试技巧</h3>

<ul>
<li>shader 写错（如缺 <code>[[ stitchable ]]</code>），SwiftUI 不报错、不闪退，画面静默 fallback 为原图——养成<strong>第一次接入就在 shader 里返回 <code>half4(1,0,1,1)</code> 验通路</strong>的习惯</li>
<li>Xcode → Product → Scheme → Run → Options → 勾选 <em>Metal API Validation</em> + <em>GPU Frame Capture: Metal</em>，可在 SwiftUI render pass 之间抓帧</li>
<li>Simulator 在 Apple Silicon Mac 用真 GPU，行为接近真机；Intel Mac 模拟器走软栅格，复杂 shader 可能黑屏——只信真机 / Apple Silicon sim</li>
</ul>

<blockquote class="warning"><strong>踩坑速查 / Pitfalls</strong>
<ul>
<li><strong>忘加 <code>[[ stitchable ]]</code></strong>：shader 静默 no-op，画面是原图。任何新 shader 第一步先输出 magenta 验通路</li>
<li><strong>函数名拼错</strong>：<code>ShaderLibrary.default.ripple</code> 找不到 <code>ripple</code>，同样静默 fallback</li>
<li><strong>参数顺序错位</strong>：MSL 签名前两个固定（position [+ color/layer]），之后必须严格按 Swift 侧 <code>.float / .color</code> 出现顺序</li>
<li><strong>maxSampleOffset 太小</strong>：distortion / layer effect 边缘出黑边或被 clamp，按最大偏移 ceil 给</li>
<li><strong>sRGB 二次 gamma</strong>：<code>.color</code> 进 shader 已经是 display-referred，别再 <code>pow(c, 2.2)</code></li>
<li><strong>每帧 TimelineView 重建上层 view</strong>：把 <code>TimelineView</code> 放在尽可能内层，避免触发整页重组</li>
<li><strong>colorEffect 想读邻居像素</strong>：做不到——colorEffect 输入只有自己这个像素的颜色。要读邻居用 layerEffect</li>
<li><strong>Image 类参数频繁变化</strong>：<code>.image(Image)</code> 每次新建 <code>Image</code> 实例可能触发纹理重传，缓存住 Image 引用</li>
<li><strong>Animatable 不生效</strong>：必须把 <code>animatableData</code> 暴露在 ViewModifier 上，<code>Shader</code> 自己不参与插值</li>
<li><strong>Intel Mac Simulator 黑屏</strong>：换 Apple Silicon 或真机；本项目专用 iPhone 17 Pro sim 没问题</li>
<li><strong>Liquid Glass 与自定义 shader 叠加</strong>：把 <code>.glassEffect()</code> 放在 shader 之上，否则 shader 输出会被 glass 重新模糊覆盖</li>
<li><strong>shader 改完没生效</strong>：.metal 文件加进 target 但 build phase 是 "Sources" 而不是 "Compile Sources"，Xcode 不重编 metallib，需要 clean build</li>
</ul>
</blockquote>