<h3>9.1 SF Symbols 动画体系总览</h3>

<p>iOS 17（SF Symbols 5）引入了 <strong>universal animations</strong>，让所有 SF Symbol 都能以一致的方式播放 Bounce、Pulse、Variable Color、Scale、Appear/Disappear、Replace 共 6 大类动画。iOS 18（SF Symbols 6）再补 Breathe、Wiggle、Rotate；iOS 26（SF Symbols 7）继续在已有动画家族上扩展 layer 级控制。整个体系建立在三个 modifier 上：</p>

<ul>
<li><code>.symbolEffect(_:options:value:isActive:)</code>——播放动画</li>
<li><code>.symbolRenderingMode(_:)</code> + <code>.foregroundStyle(_:)</code>——决定 symbol 用什么颜色策略渲染</li>
<li><code>.symbolVariant(_:)</code> 与 <code>.contentTransition(.symbolEffect(...))</code>——切换 symbol 名称或变体时的过渡</li>
</ul>

<h3>9.2 .symbolEffect 完整签名</h3>

<pre><code class="language-swift">// 1. 简单触发型
func symbolEffect&lt;T: SymbolEffect&gt;(
    _ effect: T,
    options: SymbolEffectOptions = .default,
    isActive: Bool = true
) -&gt; some View

// 2. 值驱动型
func symbolEffect&lt;T: DiscreteSymbolEffect &amp; SymbolEffect, V: Equatable&gt;(
    _ effect: T,
    options: SymbolEffectOptions = .default,
    value: V
) -&gt; some View</code></pre>

<p>关键差异：</p>

<ul>
<li><strong>Indefinite effects</strong>（如 <code>.pulse</code> / <code>.variableColor</code> / <code>.breathe</code>）支持 <code>isActive</code> 形态，循环到 false</li>
<li><strong>Discrete effects</strong>（如 <code>.bounce</code> / <code>.replace</code> / <code>.wiggle</code> / <code>.rotate</code>）支持 <code>value:</code> 形态，每次值变播一次</li>
<li>有些 effect 同时实现两种 protocol（如 <code>.pulse</code>）</li>
</ul>

<h3>9.3 SymbolEffect 全家桶速查</h3>

<table>
<thead>
<tr><th>Case</th><th>类型</th><th>iOS</th><th>说明</th></tr>
</thead>
<tbody>
<tr><td><code>.bounce</code></td><td>Discrete</td><td>17</td><td>默认向上弹一次</td></tr>
<tr><td><code>.bounce.up</code> / <code>.bounce.down</code></td><td>Discrete</td><td>17</td><td>指定方向</td></tr>
<tr><td><code>.bounce.byLayer</code> / <code>.bounce.wholeSymbol</code></td><td>Discrete</td><td>17</td><td>分层逐个弹 vs 整体弹</td></tr>
<tr><td><code>.pulse</code></td><td>Both</td><td>17</td><td>透明度循环呼吸</td></tr>
<tr><td><code>.scale.up</code> / <code>.scale.down</code></td><td>Indefinite</td><td>17</td><td>静态放大/缩小到目标态</td></tr>
<tr><td><code>.variableColor</code></td><td>Both</td><td>17</td><td>沿 variable layers 顺序点亮</td></tr>
<tr><td><code>.variableColor.iterative</code></td><td>Both</td><td>17</td><td>逐层依次亮</td></tr>
<tr><td><code>.variableColor.cumulative</code></td><td>Both</td><td>17</td><td>叠加亮（亮过的不熄）</td></tr>
<tr><td><code>.variableColor.reversing</code></td><td>Both</td><td>17</td><td>到顶后反向</td></tr>
<tr><td><code>.replace</code></td><td>Discrete</td><td>17</td><td>切换 symbol 默认动画</td></tr>
<tr><td><code>.replace.downUp</code></td><td>Discrete</td><td>17</td><td>旧的下去 → 新的上来</td></tr>
<tr><td><code>.replace.upUp</code></td><td>Discrete</td><td>17</td><td>都向上</td></tr>
<tr><td><code>.replace.offUp</code></td><td>Discrete</td><td>17</td><td>旧消失 → 新上来</td></tr>
<tr><td><code>.replace.magic(fallback:)</code></td><td>Discrete</td><td>18</td><td>"Magic Replace"——共享 strokes 时形变</td></tr>
<tr><td><code>.appear</code> / <code>.disappear</code></td><td>Indefinite</td><td>17</td><td>用 <code>isActive</code> 切换淡入淡出</td></tr>
<tr><td><code>.breathe</code></td><td>Both</td><td>18</td><td>柔和缩放呼吸——比 pulse 更温和</td></tr>
<tr><td><code>.wiggle</code></td><td>Both</td><td>18</td><td>左右抖动；<code>.wiggle.left/.right/.up/.down/.forward/.backward/.clockwise</code></td></tr>
<tr><td><code>.rotate</code></td><td>Both</td><td>18</td><td>整体旋转</td></tr>
<tr><td><code>.drawOn</code> / <code>.drawOff</code></td><td>Discrete</td><td>26</td><td>SF Symbols 7：路径 stroke 绘入/绘出</td></tr>
</tbody>
</table>

<h3>9.4 SymbolEffectOptions</h3>

<pre><code class="language-swift">// 单次（默认）
.symbolEffect(.bounce, options: .default, value: tapCount)

// 重复 N 次
.symbolEffect(.pulse, options: .repeat(.continuous), isActive: isLoading)
.symbolEffect(.bounce, options: .repeat(3), value: tapCount)

// iOS 18+ 推荐
.symbolEffect(.wiggle, options: .repeat(.periodic(2, delay: 1.5)), value: shake)

// 调速
.symbolEffect(.variableColor, options: .speed(2.0).repeat(.continuous), isActive: isDownloading)

// 显式不重复
.symbolEffect(.bounce, options: .nonRepeating, value: count)</code></pre>

<h3>9.5 Rendering Mode 与 Palette</h3>

<pre><code class="language-swift">// 4 种模式（iOS 15+）
Image(systemName: "speaker.wave.3.fill")
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(AnycastColor.gold)

Image(systemName: "exclamationmark.triangle.fill")
    .symbolRenderingMode(.palette)
    .foregroundStyle(.white, AnycastColor.orangeAlpha9, .black)

Image(systemName: "applelogo")
    .symbolRenderingMode(.multicolor)

Image(systemName: "heart")
    .symbolRenderingMode(.monochrome)</code></pre>

<blockquote>
<p>注意：<code>.bounce.byLayer</code> / <code>.pulse.byLayer</code> 的视觉差异要 <strong>render mode 是 <code>.hierarchical</code> 或 <code>.palette</code></strong> 才看得出。</p>
</blockquote>

<h3>9.6 .symbolVariant</h3>

<pre><code class="language-swift">Image(systemName: "heart")
    .symbolVariant(.fill)           // 等价于 "heart.fill"

Label("Subscribed", systemImage: "checkmark")
    .symbolVariant(.circle.fill)    // checkmark.circle.fill</code></pre>

<h3>9.7 Content Transitions 全集</h3>

<pre><code class="language-swift">// iOS 16+
.contentTransition(.identity)
.contentTransition(.opacity)
.contentTransition(.interpolate)
.contentTransition(.numericText())
.contentTransition(.numericText(value: Double(count)))
.contentTransition(.numericText(countsDown: true))

// iOS 17+
.contentTransition(.symbolEffect(.replace))
.contentTransition(.symbolEffect(.replace.downUp))</code></pre>

<p><strong>关键</strong>：<code>.contentTransition</code> 必须包在一个 <code>withAnimation { ... }</code> 里改变内容才会触发。</p>

<pre><code class="language-swift">// iOS 17 — 数字滚动
@State private var unread = 12

Text("\(unread)")
    .font(AnycastFont.display(28))
    .foregroundStyle(AnycastColor.sand12)
    .contentTransition(.numericText(value: Double(unread)))
    .animation(.snappy, value: unread)

Button("+1") {
    withAnimation { unread += 1 }
}</code></pre>

<h3>9.8 实战：播放器 play / pause 切换</h3>

<pre><code class="language-swift">// iOS 17 — 推荐写法
struct PlayPauseButton: View {
    @ObservedObject var player: PlaybackService
    var body: some View {
        Button {
            withAnimation(.snappy) { player.togglePlayPause() }
        } label: {
            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(AnycastColor.sand12)
                .contentTransition(.symbolEffect(.replace.downUp))
        }
        .buttonStyle(.plain)
    }
}</code></pre>

<h3>9.9 实战：心形点赞 bounce + fill 切换</h3>

<pre><code class="language-swift">// iOS 17
struct LikeButton: View {
    @State private var liked = false
    var body: some View {
        Button {
            withAnimation(.bouncy) { liked.toggle() }
        } label: {
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(liked ? AnycastColor.gold : AnycastColor.sand9)
                .symbolEffect(.bounce.up.byLayer, value: liked)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
    }
}</code></pre>

<h3>9.10 实战：未读 badge 数字滚动</h3>

<pre><code class="language-swift">// iOS 17 — Inbox 未读数
struct UnreadBadge: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(AnycastColor.orangeAlpha9, in: Capsule())
            .contentTransition(.numericText(value: Double(count)))
            .animation(.snappy(duration: 0.35), value: count)
    }
}</code></pre>

<blockquote>
<p>提示：<code>.monospacedDigit()</code> 是配 <code>.numericText</code> 的黄金搭档——避免数字宽度抖动。</p>
</blockquote>

<h3>9.11 实战：下载 / 加载 indicator</h3>

<pre><code class="language-swift">// iOS 17 — 下载中循环 variableColor
Image(systemName: "arrow.down.circle")
    .font(.system(size: 24))
    .symbolRenderingMode(.hierarchical)
    .foregroundStyle(AnycastColor.gold)
    .symbolEffect(
        .variableColor.iterative.reversing,
        options: .repeat(.continuous).speed(0.9),
        isActive: download.isInProgress
    )

// iOS 18+ — 同样场景换 breathe，更轻
Image(systemName: "icloud.and.arrow.down")
    .symbolEffect(.breathe, options: .repeat(.continuous), isActive: isSyncing)</code></pre>

<h3>9.12 实战：设置 toggle 状态切换 + 收藏星星</h3>

<pre><code class="language-swift">// iOS 17 — toggle 图标 hierarchical 切色
struct StateIcon: View {
    let on: Bool
    var body: some View {
        Image(systemName: on ? "bell.badge.fill" : "bell.slash.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                on ? AnycastColor.gold : AnycastColor.sand9,
                AnycastColor.sand4
            )
            .contentTransition(.symbolEffect(.replace.downUp))
            .symbolEffect(.bounce, value: on)
    }
}

// 收藏星星——fill 形态切换 + iOS 18 wiggle
struct StarButton: View {
    @State private var saved = false
    var body: some View {
        Button {
            withAnimation { saved.toggle() }
        } label: {
            Image(systemName: "star")
                .symbolVariant(saved ? .fill : .none)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(saved ? AnycastColor.gold : AnycastColor.sand9)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.wiggle, value: saved)
        }
    }
}</code></pre>

<h3>9.13 实战：呼吸感 loading + Magic Replace（iOS 18）</h3>

<pre><code class="language-swift">// iOS 18 — Magic Replace
Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
    .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))

// 呼吸 loader
Image(systemName: "circle.dotted")
    .font(.system(size: 28))
    .foregroundStyle(AnycastColor.sand9)
    .symbolEffect(.breathe.pulse.byLayer,
                  options: .repeat(.continuous),
                  isActive: isLoading)</code></pre>

<h3>9.14 触发模式 cheat sheet</h3>

<table>
<thead>
<tr><th>需求</th><th>API 形态</th></tr>
</thead>
<tbody>
<tr><td>tap 一下弹一下</td><td><code>.symbolEffect(.bounce, value: tapCount)</code> + <code>tapCount += 1</code></td></tr>
<tr><td>切换 symbol 名字</td><td><code>.contentTransition(.symbolEffect(.replace))</code> + <code>withAnimation { name = ... }</code></td></tr>
<tr><td>持续动画到状态变化</td><td><code>.symbolEffect(.pulse, isActive: isOn)</code></td></tr>
<tr><td>状态变化触发一次 + 持续</td><td>同时挂两个 <code>.symbolEffect</code>（顺序无关，SwiftUI 会合并）</td></tr>
<tr><td>数字内容</td><td><code>.contentTransition(.numericText(value:))</code> + <code>.animation(_, value:)</code></td></tr>
</tbody>
</table>

<h3>9.15 iOS 26 / SF Symbols 7 增量</h3>

<ul>
<li><strong>Draw On / Draw Off</strong>：<code>.symbolEffect(.drawOn, value: ...)</code> 让支持的 symbol 沿其 stroke path 绘入</li>
<li><strong>Wiggle / Rotate / Breathe 的 layer 控制</strong>更细</li>
<li>Replace 系列接受更多 fallback 组合，<code>.replace.magic</code> 在更多 symbol 上有 path morph 效果</li>
<li><code>SymbolEffectOptions</code> 完善了与 <code>.speed</code> 的组合行为</li>
</ul>

<blockquote class="warning">
<h4>踩坑速查 / Pitfalls</h4>
<ul>
<li><strong>Discrete effect 的 trigger 是值变化而不是 boolean 真值</strong>。<code>.symbolEffect(.bounce, value: isOn)</code> 中 <code>isOn</code> 从 <code>true</code> 变 <code>false</code> 也会触发</li>
<li><strong>不要把 <code>.bounce.byLayer</code> / <code>.pulse.byLayer</code> 配 <code>.monochrome</code></strong>，看起来和 wholeSymbol 完全一样</li>
<li><strong><code>.contentTransition(.symbolEffect(.replace))</code> 必须配合 <code>withAnimation</code></strong>，直接 <code>state.toggle()</code> 不会有动画</li>
<li><strong>切换 <code>Image(systemName:)</code> 的字符串要在同一个 <code>Image</code> 节点上发生</strong>。<code>if/else</code> 写两个 Image 视为不同 view，<code>contentTransition</code> 不生效</li>
<li><strong><code>.appear</code> / <code>.disappear</code> 不等于把 view 删掉</strong></li>
<li><strong><code>.scale.up</code> / <code>.scale.down</code> 不会自己循环</strong>，要"一直 pulse 缩放"用 <code>.breathe</code>（iOS 18+）或 <code>.pulse</code></li>
<li><strong><code>.numericText</code> 要给 <code>value:</code></strong>，否则方向判错</li>
<li><strong>SymbolEffectOptions 是 value type，<code>.repeat(...)</code> 返回新 options</strong></li>
<li><strong>iOS 18 <code>.wiggle</code> 在某些 symbol 上方向参数被忽略</strong></li>
<li><strong>不要在 <code>List</code> row 重用环境里挂 <code>isActive: true</code> 的 indefinite effect</strong>——电量开销大</li>
<li><strong><code>.symbolVariant(.fill)</code> 不会触发 contentTransition</strong>——明确写两个 systemName 字符串三元</li>
<li><strong>不要在同一个 <code>Image</code> 上挂超过 3 个 <code>.symbolEffect</code></strong></li>
</ul>
</blockquote>