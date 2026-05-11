// Chapter08_ScrollEffects.swift — 第 8 章：ScrollView 动效（iOS 17 新 API + visualEffect 全景）
// 来自 research/swiftui-motion/topics/08-scrollview-effects.md 的可运行示例。
// 每个示例独立 struct，配 #Preview；末尾 Chapter08_ScrollEffects 是入口列表。
//
// iOS 版本边界：
//   - scrollTransition / containerRelativeFrame / scrollTargetBehavior /
//     scrollPosition(id:) / visualEffect / contentMargins → iOS 17+（Package 已声明）
//   - onScrollGeometryChange / onScrollPhaseChange / onScrollVisibilityChange → iOS 18+
//     用 #available 包起来，iOS 17 走 fallback（GeometryReader 读 minY 写回 @State）
//   - .viewAligned(limitBehavior: .alwaysByOne) → iOS 17.4+
import SwiftUI

// MARK: - Mock 数据：12 张卡片够覆盖 carousel + 列表两类场景
private struct MockEpisode: Identifiable, Hashable {
    let id: Int
    let title: String
    let show: String
    let duration: String
    let tint: Color
}

private let mockEpisodes: [MockEpisode] = [
    .init(id: 0,  title: "When Algorithms Dream",          show: "Latent Space",     duration: "42 min", tint: AnycastColor.orange),
    .init(id: 1,  title: "The Memory Palace, Rebuilt",     show: "Slow Burn",        duration: "31 min", tint: AnycastColor.gold),
    .init(id: 2,  title: "Tides of the Anthropocene",      show: "Ologies",          duration: "58 min", tint: AnycastColor.orangeAlpha80),
    .init(id: 3,  title: "Silicon, After the Boom",        show: "Acquired",         duration: "1h 12m", tint: AnycastColor.sand4),
    .init(id: 4,  title: "Liner Notes from the Margins",   show: "Song Exploder",    duration: "27 min", tint: AnycastColor.gold),
    .init(id: 5,  title: "Ghosts in the Machine Shop",     show: "99% Invisible",    duration: "39 min", tint: AnycastColor.orange),
    .init(id: 6,  title: "Signals from the Pacific Gyre",  show: "Radiolab",         duration: "46 min", tint: AnycastColor.goldAlpha60),
    .init(id: 7,  title: "Field Recording: Antofagasta",   show: "Fieldwork",        duration: "33 min", tint: AnycastColor.sand9),
    .init(id: 8,  title: "Ten Lessons in Quiet Design",    show: "Design Matters",   duration: "55 min", tint: AnycastColor.orange),
    .init(id: 9,  title: "What the River Carried",         show: "Long Now",         duration: "1h 03m", tint: AnycastColor.gold),
    .init(id: 10, title: "A Brief History of Idleness",    show: "Hidden Brain",     duration: "37 min", tint: AnycastColor.orangeAlpha60),
    .init(id: 11, title: "Postcards from the Permafrost",  show: "Outside/In",       duration: "29 min", tint: AnycastColor.sand4)
]


// MARK: - 共用：Carousel 卡片（横向）
private struct CarouselCard: View {
    let ep: MockEpisode
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                .fill(
                    LinearGradient(
                        colors: [ep.tint.opacity(0.9), ep.tint.opacity(0.55), AnycastColor.sand12.opacity(0.85)],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(ep.show.uppercased())
                    .font(AnycastFont.mono(10))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.85))
                Text(ep.title)
                    .font(AnycastFont.display(20))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(ep.duration)
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(18)
        }
        .aspectRatio(0.78, contentMode: .fit)
    }
}


// MARK: - 共用：列表行（纵向 cell）
private struct ListRow: View {
    let ep: MockEpisode
    var body: some View {
        HStack(spacing: AnycastSpacing.gap) {
            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                .fill(ep.tint)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(ep.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AnycastColor.sand12)
                    .lineLimit(1)
                Text("\(ep.show) · \(ep.duration)")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(AnycastSpacing.gap)
        .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AnycastRadius.card)
                .stroke(AnycastColor.sand4.opacity(0.4), lineWidth: 1)
        )
    }
}


// MARK: - 示例 1：3D Carousel —— scrollTransition .interactive + viewAligned 跟手三轴
struct ScrollCarousel3DDemo: View {
    @State private var snappedID: MockEpisode.ID? = mockEpisodes.first?.id

    var body: some View {
        PlaygroundFrame("3D Carousel — interactive + viewAligned") {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: AnycastSpacing.gap) {
                        ForEach(mockEpisodes) { ep in
                            CarouselCard(ep: ep)
                                // 一屏 1.0 张：count 10 / span 8 留出两侧 peek
                                .containerRelativeFrame(
                                    .horizontal,
                                    count: 10, span: 8, spacing: AnycastSpacing.gap
                                )
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(1 - abs(phase.value) * 0.12)
                                        .opacity(1 - abs(phase.value) * 0.45)
                                        .rotation3DEffect(
                                            .degrees(phase.value * -28),
                                            axis: (x: 0, y: 1, z: 0),
                                            anchor: .center,
                                            perspective: 0.6
                                        )
                                }
                                .id(ep.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: 280)
                .contentMargins(.horizontal, AnycastSpacing.pageHeader, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $snappedID)
                .scrollIndicators(.hidden)

                Text("snapped → \(snappedID.map(String.init) ?? "—")")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand9)
                    .padding(.horizontal, AnycastSpacing.pageH)
            }
            .padding(.vertical, AnycastSpacing.gap)
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("scrollTransition .interactive：phase.value 在 -1...1 区间，scale + opacity + rotation3D 跟手插值。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("scrollTargetLayout + scrollTargetBehavior(.viewAligned) 让卡片 snap 到中心，scrollPosition(id:) 双向同步当前 id。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
            }
        }
    }
}

#Preview("1. Carousel 3D") { ScrollCarousel3DDemo() }


// MARK: - 示例 2：Parallax Header —— visualEffect 读 scrollView frame minY
struct ParallaxHeaderDemo: View {
    private let headerHeight: CGFloat = 220

    var body: some View {
        PlaygroundFrame("Parallax Header — 下拉放大 / 上滑视差") {
            ScrollView {
                VStack(spacing: 0) {
                    // 头图：visualEffect 在渲染阶段读 minY，不参与 layout pass
                    ZStack {
                        LinearGradient(
                            colors: [AnycastColor.orange, AnycastColor.gold, AnycastColor.sand12],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("FEATURED SHOW".uppercased())
                                        .font(AnycastFont.mono(10))
                                        .tracking(1.2)
                                        .foregroundStyle(.white.opacity(0.85))
                                    Text("Long Now Salons")
                                        .font(AnycastFont.display(26))
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                            }
                            .padding(20)
                        }
                    }
                    .frame(height: headerHeight)
                    .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                    .visualEffect { content, proxy in
                        let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        // 下拉（y > 0）：以底为锚放大；上滑（y < 0）：偏移 1/2 形成视差
                        return content
                            .scaleEffect(
                                y > 0 ? 1 + y / headerHeight : 1,
                                anchor: .bottom
                            )
                            .offset(y: y > 0 ? -y / 2 : -y / 2.5)
                    }

                    LazyVStack(spacing: AnycastSpacing.gap) {
                        ForEach(mockEpisodes) { ep in
                            ListRow(ep: ep)
                        }
                    }
                    .padding(.top, AnycastSpacing.sectionGap)
                }
                .padding(.horizontal, AnycastSpacing.pageH)
                .padding(.bottom, AnycastSpacing.sectionGap)
            }
            .scrollIndicators(.hidden)
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("visualEffect 拿到 GeometryProxy 读 .scrollView(axis:) 坐标系的 frame.minY，> 0 是下拉、< 0 是上滑。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("注意：visualEffect 闭包返回 some VisualEffect，只能链 scale / offset / blur / opacity / rotation 等，不能改 layout。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
            }
        }
    }
}

#Preview("2. Parallax Header") { ParallaxHeaderDemo() }


// MARK: - 示例 3：Scroll-Driven Blur Nav Bar —— iOS 18 onScrollGeometryChange，iOS 17 走 GeometryReader fallback
struct ScrollBlurNavBarDemo: View {
    @State private var blurAmount: CGFloat = 0

    var body: some View {
        PlaygroundFrame("Scroll-Driven Blur Nav Bar") {
            ZStack(alignment: .top) {
                scrollContent
                    .scrollIndicators(.hidden)

                // overlay 导航：背景透明 → 模糊跟着 blurAmount 0...1 渐变
                navBar
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("offset 0pt → 80pt 映射到 blurAmount 0 → 1，map .ultraThinMaterial.opacity() 与底色 opacity。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("iOS 18+ 用 onScrollGeometryChange（自带 dedupe）；iOS 17 fallback：内层 GeometryReader 读 minY 写回 @State。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
                Text("blurAmount = \(String(format: "%.2f", blurAmount))")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.gold)
            }
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        let inner = ScrollView {
            VStack(spacing: AnycastSpacing.gap) {
                Spacer().frame(height: 56)   // 给 nav bar 留位
                ForEach(mockEpisodes) { ep in
                    ListRow(ep: ep)
                }
            }
            .padding(.horizontal, AnycastSpacing.pageH)
            .padding(.bottom, AnycastSpacing.sectionGap)
            // iOS 17 fallback：GeometryReader 读自己在 .named("blurScroll") 里的 minY
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: -proxy.frame(in: .named("blurScroll")).minY
                    )
                }
            )
        }
        .coordinateSpace(name: "blurScroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { y in
            // iOS 17 路径：手动 quantize（避免每帧高频触发）
            let q = (y / 8).rounded() * 8
            let mapped = min(max(q / 80, 0), 1)
            if abs(mapped - blurAmount) > 0.01 { blurAmount = mapped }
        }

        if #available(iOS 18.0, *) {
            inner.onScrollGeometryChange(for: CGFloat.self) { geo in
                // iOS 18 路径：observe Equatable 量化值（先 round 再返回，避免每像素触发）
                let raw = geo.contentOffset.y + geo.contentInsets.top
                return (raw / 4).rounded() * 4
            } action: { _, newValue in
                blurAmount = min(max(newValue / 80, 0), 1)
            }
        } else {
            inner
        }
    }

    @ViewBuilder
    private var navBar: some View {
        HStack {
            Text("Library")
                .font(AnycastFont.display(22))
                .foregroundStyle(AnycastColor.sand12)
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AnycastColor.sand12)
        }
        .padding(.horizontal, AnycastSpacing.pageHeader)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial.opacity(blurAmount))
        .background(AnycastColor.sand1.opacity(blurAmount * 0.6))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AnycastColor.sand4.opacity(blurAmount * 0.5))
                .frame(height: 1)
        }
        .animation(.smooth(duration: 0.18), value: blurAmount)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview("3. Blur Nav Bar") { ScrollBlurNavBarDemo() }


// MARK: - 示例 4：scrollPosition + 编程式跳转 —— Jump to first / last / random
struct ScrollPositionJumpDemo: View {
    @State private var visibleID: MockEpisode.ID? = mockEpisodes.first?.id

    var body: some View {
        PlaygroundFrame("scrollPosition — 编程式滚动") {
            VStack(spacing: AnycastSpacing.gap) {
                ScrollView {
                    LazyVStack(spacing: AnycastSpacing.gap) {
                        ForEach(mockEpisodes) { ep in
                            ListRow(ep: ep)
                                // 高亮当前 snap 行
                                .overlay(
                                    RoundedRectangle(cornerRadius: AnycastRadius.card)
                                        .stroke(
                                            ep.id == visibleID ? AnycastColor.orange : .clear,
                                            lineWidth: 2
                                        )
                                )
                                .id(ep.id)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, AnycastSpacing.pageH)
                    .padding(.vertical, AnycastSpacing.gap)
                }
                .frame(height: 320)
                .scrollPosition(id: $visibleID)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .background(AnycastColor.sand1, in: RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                HStack(spacing: AnycastSpacing.gap) {
                    jumpButton("First", icon: "arrow.up.to.line") {
                        withAnimation(.smooth(duration: 0.5)) {
                            visibleID = mockEpisodes.first?.id
                        }
                    }
                    jumpButton("Random", icon: "die.face.5") {
                        withAnimation(.bouncy(duration: 0.6)) {
                            visibleID = mockEpisodes.randomElement()?.id
                        }
                    }
                    jumpButton("Last", icon: "arrow.down.to.line") {
                        withAnimation(.smooth(duration: 0.5)) {
                            visibleID = mockEpisodes.last?.id
                        }
                    }
                }
                .padding(.horizontal, AnycastSpacing.pageH)
            }
            .padding(.vertical, AnycastSpacing.gap)
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("scrollPosition(id: $visibleID) 双向同步：用户拖时读出当前 id；按钮 + withAnimation 反向写回触发滚动。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("当前可见：id = \(visibleID.map(String.init) ?? "—")")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.gold)
            }
        }
    }

    private func jumpButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(AnycastColor.sand12.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
        }
    }
}

#Preview("4. scrollPosition Jump") { ScrollPositionJumpDemo() }


// MARK: - 示例 5：scrollTransition .animated —— cell 进入 viewport 时 spring 弹入
struct ScrollAnimatedPopInDemo: View {
    var body: some View {
        PlaygroundFrame("scrollTransition .animated — 进入弹入") {
            ScrollView {
                LazyVStack(spacing: AnycastSpacing.gap) {
                    ForEach(mockEpisodes) { ep in
                        ListRow(ep: ep)
                            // .animated 走 spring：phase 在 topLeading/bottomTrailing 与 identity 切换时有动画
                            // threshold .visible(0.3) 让 cell 露出 30% 才算进入 identity
                            .scrollTransition(
                                .animated(.bouncy(duration: 0.55)).threshold(.visible(0.3)),
                                axis: .vertical
                            ) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.7,
                                                 anchor: phase == .topLeading ? .top : .bottom)
                                    .blur(radius: phase.isIdentity ? 0 : 6)
                            }
                    }
                }
                .padding(.horizontal, AnycastSpacing.pageH)
                .padding(.vertical, AnycastSpacing.gap)
            }
            .scrollIndicators(.hidden)
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text(".animated 配置：phase 切换时走 spring 动画（不像 .interactive 跟手）。配 .threshold(.visible(0.3)) 让 30% 可见才弹入。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("根据 phase（.topLeading vs .bottomTrailing）选 anchor，让弹入方向自然指回入场边。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
            }
        }
    }
}

#Preview("5. scrollTransition Animated") { ScrollAnimatedPopInDemo() }


// MARK: - 示例 6：containerRelativeFrame Paging —— count/span 切换 1 / 1.5 / 2.5 张
struct ContainerRelativePagingDemo: View {
    @State private var spanIndex = 0
    private let presets: [(label: String, count: Int, span: Int)] = [
        ("1.0 张", 1, 1),    // 一屏 1 张（整屏）
        ("1.5 张", 3, 2),    // 一屏 1.5 张
        ("2.5 张", 5, 2)     // 一屏 2.5 张
    ]

    var body: some View {
        PlaygroundFrame("containerRelativeFrame — count / span 切换") {
            VStack(spacing: AnycastSpacing.gap) {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: AnycastSpacing.gap) {
                        ForEach(mockEpisodes) { ep in
                            CarouselCard(ep: ep)
                                .containerRelativeFrame(
                                    .horizontal,
                                    count: presets[spanIndex].count,
                                    span: presets[spanIndex].span,
                                    spacing: AnycastSpacing.gap
                                )
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .opacity(1 - abs(phase.value) * 0.3)
                                        .scaleEffect(1 - abs(phase.value) * 0.06)
                                }
                                .id(ep.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: 240)
                .contentMargins(.horizontal, AnycastSpacing.pageHeader, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                // 切 preset 时给个动画过渡（layout 重排会跟着平滑）
                .animation(.smooth(duration: 0.4), value: spanIndex)
            }
            .padding(.vertical, AnycastSpacing.gap)
        } controls: {
            VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
                Picker("Span", selection: $spanIndex) {
                    ForEach(presets.indices, id: \.self) { i in
                        Text(presets[i].label).tag(i)
                    }
                }
                .pickerStyle(.segmented)

                Text("count: \(presets[spanIndex].count) / span: \(presets[spanIndex].span) — 容器分 count 份，每张占 span 份。spacing 必须 = LazyHStack spacing。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("6. containerRelativeFrame") { ContainerRelativePagingDemo() }


// MARK: - 示例 7：Sticky Shrink Header —— visualEffect 上滑收缩 / 下拉放大
struct StickyShrinkHeaderDemo: View {
    private let baseHeight: CGFloat = 180

    var body: some View {
        PlaygroundFrame("Sticky Shrink Header — visualEffect") {
            ScrollView {
                VStack(spacing: 0) {
                    // 头部：上滑 offset 自身抵消 → 视觉上贴顶；下拉时放大
                    ZStack {
                        RoundedRectangle(cornerRadius: AnycastRadius.cardLarge)
                            .fill(
                                LinearGradient(
                                    colors: [AnycastColor.gold, AnycastColor.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        VStack(spacing: 6) {
                            Image(systemName: "headphones")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Now Playing")
                                .font(AnycastFont.display(20))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(height: baseHeight)
                    .visualEffect { content, proxy in
                        let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        return content
                            // 下拉放大（以底为锚自然撑开）
                            .scaleEffect(y > 0 ? 1 + y / (baseHeight * 1.5) : 1, anchor: .top)
                            // 上滑：偏移自身一半，看起来 sticky 但更轻
                            .offset(y: y > 0 ? -y * 0.5 : -y * 0.5)
                            // 上滑时降亮度，强化 "退场" 暗示
                            .brightness(y < 0 ? max(y / 600, -0.3) : 0)
                    }

                    LazyVStack(spacing: AnycastSpacing.gap) {
                        ForEach(mockEpisodes) { ep in
                            ListRow(ep: ep)
                        }
                    }
                    .padding(.top, AnycastSpacing.sectionGap)
                }
                .padding(.horizontal, AnycastSpacing.pageH)
                .padding(.bottom, AnycastSpacing.sectionGap)
            }
            .scrollIndicators(.hidden)
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("visualEffect 链 scaleEffect + offset + brightness：下拉放大、上滑自身偏移做出 sticky 效果且降亮度。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("VisualEffect 链上的 modifier 限定子集（不能调任意 modifier），但 scale/offset/blur/opacity/rotation/brightness/grayscale/colorMultiply 都可以。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.8))
            }
        }
    }
}

#Preview("7. Sticky Shrink Header") { StickyShrinkHeaderDemo() }


// MARK: - Chapter root —— 章节入口列表
struct Chapter08_ScrollEffects: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "Carousel 3D",
                 subtitle: "scrollTransition .interactive + viewAligned，rotation3D + scale + opacity 跟手",
                 view: AnyView(ScrollCarousel3DDemo())),
            Demo(number: 2, title: "Parallax Header",
                 subtitle: "visualEffect 读 minY，下拉放大、上滑视差",
                 view: AnyView(ParallaxHeaderDemo())),
            Demo(number: 3, title: "Blur Nav Bar",
                 subtitle: "iOS 18 onScrollGeometryChange + iOS 17 GeometryReader fallback，offset 0-80 → blur 0-1",
                 view: AnyView(ScrollBlurNavBarDemo())),
            Demo(number: 4, title: "scrollPosition Jump",
                 subtitle: "First / Random / Last 编程式滚动 + 高亮当前 cell",
                 view: AnyView(ScrollPositionJumpDemo())),
            Demo(number: 5, title: "scrollTransition Animated",
                 subtitle: "cell 进入 viewport 时 spring + blur 弹入，threshold .visible(0.3)",
                 view: AnyView(ScrollAnimatedPopInDemo())),
            Demo(number: 6, title: "containerRelativeFrame",
                 subtitle: "count / span 切换：一屏 1 / 1.5 / 2.5 张",
                 view: AnyView(ContainerRelativePagingDemo())),
            Demo(number: 7, title: "Sticky Shrink Header",
                 subtitle: "visualEffect 链 scale + offset + brightness 做 sticky 退场",
                 view: AnyView(StickyShrinkHeaderDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 8 章 · ScrollView 动效") {
                ForEach(demos) { demo in
                    NavigationLink {
                        ScrollView { demo.view }
                            .background(AnycastColor.sand1.ignoresSafeArea())
                            .navigationTitle(demo.title)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: AnycastSpacing.gap) {
                            Text("\(demo.number)")
                                .font(AnycastFont.mono(13))
                                .foregroundStyle(AnycastColor.gold)
                                .frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(demo.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AnycastColor.sand12)
                                Text(demo.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnycastColor.sand9)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            Section("说明") {
                Text("scrollTransition / containerRelativeFrame / visualEffect / scrollPosition 是 iOS 17+；onScrollGeometryChange 是 iOS 18+，本章用 #available 包起来，iOS 17 走 GeometryReader + PreferenceKey fallback。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ch. 8 ScrollView Effects")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 8 — ScrollView Effects") {
    NavigationStack { Chapter08_ScrollEffects() }
}
