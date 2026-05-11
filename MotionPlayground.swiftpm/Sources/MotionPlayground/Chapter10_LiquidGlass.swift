// Chapter10_LiquidGlass.swift — 第 10 章：iOS 26 Liquid Glass
// 来自 research/swiftui-motion/topics/10-liquid-glass.md 的可运行示例。
// 每个示例独立 struct，配 #Preview；末尾 Chapter10_LiquidGlass 是入口列表。
//
// 重要：.glassEffect / GlassEffectContainer / .buttonStyle(.glass) 仅 iOS 26+。
// 包文件 deployment target 是 iOS 17，所以每个示例内部都用
// `if #available(iOS 26.0, *)` 包裹真实玻璃效果，旧系统 fallback 一段提示文字。
import SwiftUI

// MARK: - 示例 1：单按钮 .glassEffect —— .interactive() + .tint
struct GlassSingleButtonDemo: View {
    @State private var liked = false

    var body: some View {
        PlaygroundFrame(".glassEffect 单按钮（interactive + tint）") {
            ZStack {
                // 底层富色彩内容：玻璃要折射的就是它
                LinearGradient(
                    colors: [AnycastColor.goldAlpha60, AnycastColor.orangeAlpha80],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    Button {
                        withAnimation(.snappy(duration: 0.3)) { liked.toggle() }
                    } label: {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 64, height: 64)
                    }
                    .glassEffect(
                        .regular
                            .tint(liked ? AnycastColor.orange : AnycastColor.gold)
                            .interactive(),
                        in: Circle()
                    )
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("按下时按钮形变隆起；tint 与下层颜色做物理乘法混合，不是简单覆盖。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("已点 like：\(liked ? "是" : "否")（点心形切换 tint 色）")
                    .font(AnycastFont.mono(11))
                    .foregroundStyle(AnycastColor.sand12)
            }
        }
    }
}

#Preview("1. Glass Single Button") { GlassSingleButtonDemo() }


// MARK: - 示例 2：GlassEffectContainer 多按钮 metaball 融合
struct GlassMetaballRowDemo: View {
    @State private var spacing: Double = 6   // 拉小 → 融合；拉大 → 分离
    @State private var pressed: Int? = nil

    private let icons: [(id: String, sf: String)] = [
        ("backward", "backward.fill"),
        ("play",     "play.fill"),
        ("forward",  "forward.fill"),
        ("airplay",  "airplay.audio")
    ]

    var body: some View {
        PlaygroundFrame("GlassEffectContainer：metaball 融合 / 分离") {
            ZStack {
                LinearGradient(
                    colors: [AnycastColor.sand4, AnycastColor.goldAlpha40],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 22) {
                        HStack(spacing: spacing) {
                            ForEach(icons, id: \.id) { item in
                                Button {
                                    pressed = pressed == icons.firstIndex(where: { $0.id == item.id })
                                        ? nil
                                        : icons.firstIndex(where: { $0.id == item.id })
                                } label: {
                                    Image(systemName: item.sf)
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .frame(width: 48, height: 48)
                                }
                                .glassEffect(.regular.interactive(), in: Circle())
                            }
                        }
                    }
                    .animation(.smooth(duration: 0.4), value: spacing)
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("HStack spacing")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand12)
                    Spacer()
                    Text(String(format: "%.0f pt", spacing))
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                }
                Slider(value: $spacing, in: 0...60)
                    .tint(AnycastColor.gold)
                Text("spacing ≤ container 的 22pt 时 → 玻璃融合；> 22 → 各自分离。注意 metaball 的过渡有自然的液体张力。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
    }
}

#Preview("2. Glass Metaball Row") { GlassMetaballRowDemo() }


// MARK: - 示例 3：buttonStyle(.glass) vs .glassProminent 对比
struct GlassButtonStyleCompareDemo: View {
    @State private var counter = 0

    var body: some View {
        PlaygroundFrame(".buttonStyle(.glass) vs .glassProminent") {
            ZStack {
                LinearGradient(
                    colors: [AnycastColor.sand2, AnycastColor.sand4],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    VStack(spacing: AnycastSpacing.sectionGap) {
                        // 中性按钮 .glass —— 通常作为次要操作
                        Button("Subscribe \(counter)") { counter += 1 }
                            .buttonStyle(.glass)
                            .controlSize(.large)

                        // 强调按钮 .glassProminent —— 主操作 + 品牌色
                        Button("Play Episode") { counter += 1 }
                            .buttonStyle(.glassProminent)
                            .controlSize(.large)
                            .tint(AnycastColor.gold)

                        Text("count = \(counter)")
                            .font(AnycastFont.mono(11))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                }
            }
        } controls: {
            Text(".glass 是中性玻璃，.glassProminent 自带 tint 强调；两者都自动包含 .interactive()、自动响应 dynamic type 与 disabled 淡化。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("3. Glass Button Style") { GlassButtonStyleCompareDemo() }


// MARK: - 示例 4：glassEffectID + GlassEffectContainer 形状 morph
struct GlassMorphDemo: View {
    @Namespace private var glassNS
    @State private var expanded = false

    var body: some View {
        PlaygroundFrame("glassEffectID：capsule ↔ rounded rect morph") {
            ZStack {
                LinearGradient(
                    colors: [AnycastColor.orangeAlpha40, AnycastColor.goldAlpha60],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 12) {
                        Group {
                            if expanded {
                                // 展开态：rounded rect 卡片
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Now Playing")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                    Text("Anycast · Liquid Glass demo")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 12) {
                                        Image(systemName: "backward.fill")
                                        Image(systemName: "pause.fill")
                                        Image(systemName: "forward.fill")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 14)
                                .frame(width: 240)
                                .glassEffect(.regular,
                                             in: RoundedRectangle(cornerRadius: AnycastRadius.card))
                                .glassEffectID("morph", in: glassNS)
                            } else {
                                // 收起态：圆滚 capsule
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.primary)
                                    Text("Play")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .glassEffect(.regular, in: Capsule())
                                .glassEffectID("morph", in: glassNS)
                            }
                        }
                    }
                    .animation(.spring(duration: 0.5, bounce: 0.25), value: expanded)
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                }
            }
        } controls: {
            HStack {
                Text("点按钮触发玻璃形状在 capsule 和 rounded rect 之间流动 morph。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Spacer()
                Button(expanded ? "收起" : "展开") {
                    withAnimation(.spring(duration: 0.5, bounce: 0.25)) {
                        expanded.toggle()
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnycastColor.orange)
            }
        }
    }
}

#Preview("4. Glass Morph") { GlassMorphDemo() }


// MARK: - 示例 5：浮动 Mini Player —— GlassEffectContainer + capsule + 内置按钮
struct GlassMiniPlayerDemo: View {
    @Namespace private var glassNS
    @State private var isPlaying = true

    var body: some View {
        PlaygroundFrame("浮动 Mini Player（GlassEffectContainer）") {
            ZStack(alignment: .bottom) {
                // 模拟"下层"列表内容，让玻璃有东西可以折射
                VStack(spacing: 10) {
                    ForEach(0..<5) { i in
                        HStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(i.isMultiple(of: 2) ? AnycastColor.goldAlpha40 : AnycastColor.orangeAlpha40)
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AnycastColor.sand9.opacity(0.4))
                                    .frame(width: 120, height: 8)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(AnycastColor.sand9.opacity(0.2))
                                    .frame(width: 80, height: 6)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 10) {
                        HStack(spacing: 12) {
                            // 封面
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AnycastColor.gold)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "waveform")
                                        .foregroundStyle(.white)
                                )

                            // 标题/副标题：用 .primary/.secondary 才能拿到 vibrancy
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Liquid Glass 详解")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("Anycast · Ch.10")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)

                            // 内置 play 按钮：glass-on-glass，靠 GlassEffectContainer 让两层玻璃融合
                            Button {
                                withAnimation(.snappy(duration: 0.25)) { isPlaying.toggle() }
                            } label: {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .glassEffect(.regular.interactive(), in: Circle())
                            .glassEffectID("playBtn", in: glassNS)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: Capsule())
                        .glassEffectID("miniBg", in: glassNS)
                    }
                    .padding(.horizontal, AnycastSpacing.pageH)
                    .padding(.bottom, AnycastSpacing.gap)
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                        .padding(.bottom, AnycastSpacing.gap)
                }
            }
        } controls: {
            Text("外层 capsule 玻璃 + 内层圆形玻璃按钮，二者通过同一 GlassEffectContainer 共享一次 GPU pass，按下时按钮隆起带动外壳形变。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("5. Glass Mini Player") { GlassMiniPlayerDemo() }


// MARK: - 示例 6：glassEffectUnion —— 强制把分散元素绑成同一融合组
struct GlassUnionDemo: View {
    @Namespace private var glassNS
    @State private var selected: String = "subscribed"

    private let chips = [
        ("subscribed", "Subscribed"),
        ("played",     "Played"),
        ("saved",      "Saved")
    ]

    var body: some View {
        PlaygroundFrame("glassEffectUnion：远距离 chips 也连成一条玻璃管") {
            ZStack {
                LinearGradient(
                    colors: [AnycastColor.sand4, AnycastColor.goldAlpha60, AnycastColor.orangeAlpha60],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(RoundedRectangle(cornerRadius: AnycastRadius.card))
                .padding(.horizontal, AnycastSpacing.pageH)

                if #available(iOS 26.0, *) {
                    GlassEffectContainer(spacing: 40) {
                        HStack(spacing: 36) {
                            ForEach(chips, id: \.0) { chip in
                                Button {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        selected = chip.0
                                    }
                                } label: {
                                    Text(chip.1)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                }
                                .glassEffect(
                                    .regular
                                        .tint(selected == chip.0 ? AnycastColor.gold : .clear)
                                        .interactive(),
                                    in: Capsule()
                                )
                                .glassEffectUnion(id: "filterBar", namespace: glassNS)
                            }
                        }
                    }
                } else {
                    fallbackHint("需 iOS 26+ Liquid Glass")
                }
            }
        } controls: {
            Text("HStack spacing 36 远大于 container spacing 40 的『自动融合距离』——但 .glassEffectUnion 强制把三个 chip 绑到同一融合 id，看到 chips 之间被一根细玻璃『管道』连起来。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("6. Glass Union Chips") { GlassUnionDemo() }


// MARK: - 共用：iOS 25 及以下的 fallback 提示
@ViewBuilder
private func fallbackHint(_ text: String) -> some View {
    VStack(spacing: 6) {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(AnycastColor.orange)
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AnycastColor.sand12)
        Text("当前 sim 不支持 .glassEffect / GlassEffectContainer。在 iOS 26 sim 上重跑可见真效果。")
            .font(.system(size: 10))
            .foregroundStyle(AnycastColor.sand9)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
    }
    .padding(.horizontal, AnycastSpacing.pageH)
}


// MARK: - Chapter root —— 章节入口列表
struct Chapter10_LiquidGlass: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "Glass Single Button",
                 subtitle: ".glassEffect + .interactive() + .tint 物理混合",
                 view: AnyView(GlassSingleButtonDemo())),
            Demo(number: 2, title: "Glass Metaball Row",
                 subtitle: "GlassEffectContainer + Slider 控制 spacing，看融合 ↔ 分离",
                 view: AnyView(GlassMetaballRowDemo())),
            Demo(number: 3, title: "Glass Button Style",
                 subtitle: "buttonStyle(.glass) 中性 vs .glassProminent 强调",
                 view: AnyView(GlassButtonStyleCompareDemo())),
            Demo(number: 4, title: "Glass Morph",
                 subtitle: "glassEffectID + 动画 → capsule ↔ rounded rect 流动",
                 view: AnyView(GlassMorphDemo())),
            Demo(number: 5, title: "Glass Mini Player",
                 subtitle: "GlassEffectContainer + 浮动 capsule + 内置 play 按钮",
                 view: AnyView(GlassMiniPlayerDemo())),
            Demo(number: 6, title: "Glass Union Chips",
                 subtitle: "glassEffectUnion 把远距离元素绑成同一融合组",
                 view: AnyView(GlassUnionDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 10 章 · iOS 26 Liquid Glass") {
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
                Text("Liquid Glass API 仅 iOS 26+。每个示例内部用 if #available(iOS 26.0, *) 包裹，旧系统看到提示文字而非崩溃。Xcode Preview 渲染玻璃只是 Material 近似，真实折射要在 iOS 26 sim / 真机看。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ch. 10 Liquid Glass")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 10 — Liquid Glass") {
    NavigationStack { Chapter10_LiquidGlass() }
}
