// Chapter12_Performance.swift — 第 12 章：性能 + 高级模式
// 来自 research/swiftui-motion/topics/12-performance.md 的可运行示例。
// 重点是"差 / 优"对比：让插错字段、忘加 compositingGroup、用 indices 当 id
// 这些坑用并排同帧触发的方式肉眼可见。
//
// 每个示例独立 struct + #Preview；末尾 Chapter12_Performance 是入口。
import SwiftUI
import Observation

// MARK: - 示例 1：Animatable 字段选错 —— frame 插值 vs scaleEffect 插值
//
// 同一帧 toggle 一个 @State，左侧动 frame.width，右侧动 scaleEffect。
// 两者最终视觉尺寸完全一致，但前者每帧触发整子树 layout invalidation；
// 后者只走 transform pass，layout 不变。
struct PerfFrameVsScaleDemo: View {
    @State private var expanded = false

    var body: some View {
        PlaygroundFrame("Animatable 字段：frame.width vs scaleEffect") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                HStack(spacing: AnycastSpacing.sectionGap) {
                    // 差：动 frame.width / height —— 每帧重 layout
                    VStack(spacing: 10) {
                        BadgeLabel(text: "差 (Bad)", tone: .orange)
                        ZStack {
                            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                                .fill(AnycastColor.orange)
                                .frame(width: expanded ? 130 : 50,
                                       height: expanded ? 130 : 50)
                                .animation(.spring(response: 0.55, dampingFraction: 0.7),
                                           value: expanded)
                        }
                        .frame(width: 140, height: 140, alignment: .center)
                        Text("animate frame.width\n→ 每帧 layout")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 11))
                            .foregroundStyle(AnycastColor.sand9)
                    }

                    // 优：固定 frame，动 scaleEffect —— 走 transform，无 layout
                    VStack(spacing: 10) {
                        BadgeLabel(text: "优 (Good)", tone: .gold)
                        ZStack {
                            RoundedRectangle(cornerRadius: AnycastRadius.sm)
                                .fill(AnycastColor.gold)
                                .frame(width: 50, height: 50)
                                .scaleEffect(expanded ? 2.6 : 1.0)
                                .animation(.spring(response: 0.55, dampingFraction: 0.7),
                                           value: expanded)
                        }
                        .frame(width: 140, height: 140, alignment: .center)
                        Text("scaleEffect\n→ 仅 transform pass")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 11))
                            .foregroundStyle(AnycastColor.sand9)
                    }
                }

                Button {
                    expanded.toggle()
                } label: {
                    Text(expanded ? "收起 (toggle)" : "放大 (toggle)")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AnycastColor.sand12.opacity(0.85), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("两者最终尺寸一样，但左侧每帧触发 layout，右侧只是 GPU 矩阵。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("基准：50 行 ScrollView 内 frame ≈ 18ms/帧 (~55fps)，scaleEffect ≈ 5.4ms/帧 (稳 120fps)。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.85))
            }
        }
    }
}

#Preview("12.1 frame vs scaleEffect") { PerfFrameVsScaleDemo() }


// MARK: - 示例 2：compositingGroup() 对透明叠加的影响
//
// 两个相同的 ZStack（两个 0.5 透明的重叠 circle），左不加 compositingGroup
// → 重叠区颜色叠加（≈0.75 alpha，看起来更深），右加 compositingGroup
// → 先合成成一张图再整体 0.5，重叠区颜色与外圈一致。
struct PerfCompositingGroupDemo: View {
    var body: some View {
        PlaygroundFrame("compositingGroup() —— 透明叠加") {
            HStack(spacing: AnycastSpacing.sectionGap) {
                // 差：没有 compositingGroup
                VStack(spacing: 10) {
                    BadgeLabel(text: "差 (Bad)", tone: .orange)
                    ZStack {
                        Circle()
                            .fill(AnycastColor.orange)
                            .frame(width: 70, height: 70)
                            .offset(x: -16)
                        Circle()
                            .fill(AnycastColor.gold)
                            .frame(width: 70, height: 70)
                            .offset(x: 16)
                    }
                    .opacity(0.5)
                    .frame(width: 140, height: 90)
                    Text("无 compositingGroup\n→ 重叠区 ≈ 0.75 alpha")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }

                // 优：先合成再做 opacity
                VStack(spacing: 10) {
                    BadgeLabel(text: "优 (Good)", tone: .gold)
                    ZStack {
                        Circle()
                            .fill(AnycastColor.orange)
                            .frame(width: 70, height: 70)
                            .offset(x: -16)
                        Circle()
                            .fill(AnycastColor.gold)
                            .frame(width: 70, height: 70)
                            .offset(x: 16)
                    }
                    .compositingGroup()
                    .opacity(0.5)
                    .frame(width: 140, height: 90)
                    Text("compositingGroup\n→ 整体均匀透明")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }
            }
        } controls: {
            Text("compositingGroup 强制把子树先栅格化到中间层，opacity / blendMode / colorMultiply 才作用在合成结果上。代价是一块 IOSurface。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("12.2 compositingGroup") { PerfCompositingGroupDemo() }


// MARK: - 示例 3：@Published vs @Observable 失效粒度对照
//
// 两套 store 持有相同的三个字段，每个 view 只读其中一个。
// 按按钮只动 `volume`，但 ObservedObject 版本下读 currentTime 的
// view 也会重算 body —— 用 _printChanges 打到 console 验证。
//
// 注：在 SwiftPM Playground 里 console 输出在 Xcode debug area；
// 不能跑也可以靠右下角 "body 调用计数" 看出粗细粒度差异。

final class LegacyPlayerStore: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var volume: Double = 0.5
    @Published var isPlaying: Bool = false
}

@Observable
final class ModernPlayerStore {
    var currentTime: Double = 0
    var volume: Double = 0.5
    var isPlaying: Bool = false
}

private struct LegacyTimeRow: View {
    @ObservedObject var store: LegacyPlayerStore
    @State private var bodyCount = 0
    var body: some View {
        let _ = Self._printChanges()
        let _ = (bodyCount += 1)
        return HStack {
            Text("currentTime: \(store.currentTime, specifier: "%.1f")")
                .font(AnycastFont.mono(12))
                .foregroundStyle(AnycastColor.sand12)
            Spacer()
            Text("body x\(bodyCount)")
                .font(AnycastFont.mono(11))
                .foregroundStyle(AnycastColor.orange)
        }
    }
}

private struct ModernTimeRow: View {
    let store: ModernPlayerStore     // 普通 let，无 wrapper
    @State private var bodyCount = 0
    var body: some View {
        let _ = Self._printChanges()
        let _ = (bodyCount += 1)
        return HStack {
            Text("currentTime: \(store.currentTime, specifier: "%.1f")")
                .font(AnycastFont.mono(12))
                .foregroundStyle(AnycastColor.sand12)
            Spacer()
            Text("body x\(bodyCount)")
                .font(AnycastFont.mono(11))
                .foregroundStyle(AnycastColor.gold)
        }
    }
}

struct PerfObservedVsObservableDemo: View {
    @StateObject private var legacyStore = LegacyPlayerStore()
    @State private var modernStore = ModernPlayerStore()

    var body: some View {
        PlaygroundFrame("@Published vs @Observable") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                // 差
                VStack(alignment: .leading, spacing: 10) {
                    BadgeLabel(text: "差 (Bad) — @ObservedObject", tone: .orange)
                    LegacyTimeRow(store: legacyStore)
                    Text("volume: \(legacyStore.volume, specifier: "%.2f")")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Text("点 + 改 volume，但 currentTime 行的 body 也会被重算。")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .padding(12)
                .background(AnycastColor.orangeAlpha40.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: AnycastRadius.sm))

                // 优
                VStack(alignment: .leading, spacing: 10) {
                    BadgeLabel(text: "优 (Good) — @Observable", tone: .gold)
                    ModernTimeRow(store: modernStore)
                    Text("volume: \(modernStore.volume, specifier: "%.2f")")
                        .font(AnycastFont.mono(11))
                        .foregroundStyle(AnycastColor.sand9)
                    Text("同样改 volume，currentTime 行不再被重算（计数不动）。")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }
                .padding(12)
                .background(AnycastColor.goldAlpha40.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: AnycastRadius.sm))

                HStack(spacing: AnycastSpacing.gap) {
                    Button("Legacy +volume") {
                        legacyStore.volume = (legacyStore.volume + 0.1)
                            .truncatingRemainder(dividingBy: 1.0)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AnycastColor.orange)

                    Button("Modern +volume") {
                        modernStore.volume = (modernStore.volume + 0.1)
                            .truncatingRemainder(dividingBy: 1.0)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AnycastColor.gold)
                }
                .controlSize(.small)
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("打开 Xcode console 看 _printChanges：Legacy 行每次按 Modern 按钮也可能被打印（如果改 currentTime），@Observable 只在读到的 keyPath 真的变化时才订阅。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("项目内 PlaybackService 仍是 @Published，60Hz timer 让 NowPlaying 整张每秒重算 60 次。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.85))
            }
        }
    }
}

#Preview("12.3 @Published vs @Observable") { PerfObservedVsObservableDemo() }


// MARK: - 示例 4：ForEach indices vs stable id
//
// 维护一个 [TodoItem]，左右两列同步显示，但左用 indices 当 id，右用业务 id。
// 删除中间一项后，左列动画错乱（因为 id 是 0/1/2/.../n-1，所有 index 都漂移），
// 右列正确把被删的 view 淡出，其余位置保持 identity。
private struct TodoItem: Identifiable, Equatable {
    let id: UUID
    let label: String
}

struct PerfForEachIdentityDemo: View {
    @State private var items: [TodoItem] = (0..<5).map {
        TodoItem(id: UUID(), label: "Item \($0)")
    }
    @State private var nextLabel = 5

    var body: some View {
        PlaygroundFrame("ForEach: indices vs stable id") {
            VStack(spacing: AnycastSpacing.gap) {
                HStack(alignment: .top, spacing: AnycastSpacing.sectionGap) {
                    // 差：indices
                    VStack(spacing: 6) {
                        BadgeLabel(text: "差 (Bad)\nindices", tone: .orange)
                        VStack(spacing: 6) {
                            ForEach(items.indices, id: \.self) { i in
                                rowChip(items[i].label, tone: AnycastColor.orange)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.75),
                                   value: items.count)
                    }
                    .frame(maxWidth: .infinity)

                    // 优：stable id
                    VStack(spacing: 6) {
                        BadgeLabel(text: "优 (Good)\n\\.id", tone: .gold)
                        VStack(spacing: 6) {
                            ForEach(items, id: \.id) { item in
                                rowChip(item.label, tone: AnycastColor.gold)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.75),
                                   value: items)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)

                HStack(spacing: AnycastSpacing.gap) {
                    Button("+ Add") {
                        items.append(TodoItem(id: UUID(), label: "Item \(nextLabel)"))
                        nextLabel += 1
                    }
                    .tint(AnycastColor.gold)
                    Button("Remove middle") {
                        guard items.count > 1 else { return }
                        items.remove(at: items.count / 2)
                    }
                    .tint(AnycastColor.orange)
                    Button("Shuffle") {
                        items.shuffle()
                    }
                    .tint(AnycastColor.sand12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .foregroundStyle(.white)
            }
        } controls: {
            Text("用 indices 当 id：删中间那项时，所有「index ≥ 删除位」的 view 全部 teardown + recreate，转场动画乱跳。用业务 id：只有被删那一项 fade-out。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }

    @ViewBuilder
    private func rowChip(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(AnycastFont.mono(11))
            .foregroundStyle(AnycastColor.sand12)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(tone.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
    }
}

#Preview("12.4 ForEach identity") { PerfForEachIdentityDemo() }


// MARK: - 示例 5：drawingGroup() 包静态复杂 Path
//
// 同一个由 64 段贝塞尔构成的"伪 waveform"画两份。左侧裸 Canvas，
// 每帧偏移触发 path 重画；右侧 .drawingGroup() 把 Canvas 输出离屏栅格化，
// 后续仅平移一张 Metal texture。本 demo 重点是"什么时候它真的有效"——
// 内容静态 + 整体可平移，否则 drawingGroup 是性能负优化。
struct PerfDrawingGroupDemo: View {
    @State private var animating = false

    var body: some View {
        PlaygroundFrame("drawingGroup() —— 静态复杂矢量") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                VStack(spacing: 10) {
                    BadgeLabel(text: "差 (Bad) — 无 drawingGroup", tone: .orange)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AnycastRadius.sm)
                            .fill(AnycastColor.sand1)
                        WaveformShape()
                            .stroke(AnycastColor.orange.opacity(0.85), lineWidth: 1.5)
                            .frame(height: 60)
                            .offset(x: animating ? 30 : -30)
                            .animation(.linear(duration: 1.6).repeatForever(autoreverses: true),
                                       value: animating)
                    }
                    .frame(height: 70)
                    Text("Path 每帧重画 → CPU 路径化每帧跑")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }

                VStack(spacing: 10) {
                    BadgeLabel(text: "优 (Good) — drawingGroup", tone: .gold)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AnycastRadius.sm)
                            .fill(AnycastColor.sand1)
                        WaveformShape()
                            .stroke(AnycastColor.gold.opacity(0.85), lineWidth: 1.5)
                            .frame(height: 60)
                            .drawingGroup()      // 离屏 Metal 栅格化一次，之后仅 GPU 平移
                            .offset(x: animating ? 30 : -30)
                            .animation(.linear(duration: 1.6).repeatForever(autoreverses: true),
                                       value: animating)
                    }
                    .frame(height: 70)
                    Text("一次栅格化 → 之后只 GPU blit + offset")
                        .font(.system(size: 11))
                        .foregroundStyle(AnycastColor.sand9)
                }

                Button(animating ? "Stop wave" : "Start wave") {
                    animating.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(AnycastColor.sand12)
                .controlSize(.small)
                .foregroundStyle(.white)
            }
        } controls: {
            VStack(alignment: .leading, spacing: 6) {
                Text("drawingGroup 真正适合的场景非常窄：内容静态、子树要做整体 blur / colorMultiply、或大量 Path/Canvas。")
                    .font(.system(size: 12))
                    .foregroundStyle(AnycastColor.sand9)
                Text("反例：动态内容、含 text 的子树用 drawingGroup 反而更慢，且失去字体 metrics。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.85))
                Text("FPS 概念：iPhone 17 Pro ProMotion 8.3ms/帧 = 120fps。波形若每帧 path 化 12ms 即掉到 ~80fps；离屏后 ≈ 1ms blit。")
                    .font(.system(size: 11))
                    .foregroundStyle(AnycastColor.sand9.opacity(0.85))
            }
        }
    }
}

private struct WaveformShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let segments = 64
        let stepX = rect.width / CGFloat(segments)
        let midY = rect.midY
        for i in 0...segments {
            let x = CGFloat(i) * stepX
            // 多频叠加近似的伪 waveform
            let phase = Double(i) * 0.35
            let y = midY + CGFloat(sin(phase) * 18 + sin(phase * 2.7) * 8 + sin(phase * 5.1) * 4)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        return p
    }
}

#Preview("12.5 drawingGroup") { PerfDrawingGroupDemo() }


// MARK: - 示例 6：geometryGroup() 配合 matchedGeometryEffect
//
// 父级容器边长在动，子里又有 matchedGeometryEffect 跨分支匹配。
// 不加 geometryGroup() 时子树的几何快照不与父级原子，过渡会"先跳后拉"；
// 加上之后子树几何先打包再插值，过渡丝滑。
struct PerfGeometryGroupDemo: View {
    @State private var expanded = false
    @Namespace private var nsBad
    @Namespace private var nsGood

    var body: some View {
        PlaygroundFrame("geometryGroup() —— 父级动 + matched 子级") {
            VStack(spacing: AnycastSpacing.sectionGap) {
                HStack(spacing: AnycastSpacing.sectionGap) {
                    // 差：无 geometryGroup
                    VStack(spacing: 10) {
                        BadgeLabel(text: "差 (Bad)", tone: .orange)
                        ZStack {
                            RoundedRectangle(cornerRadius: AnycastRadius.card)
                                .fill(AnycastColor.orangeAlpha40.opacity(0.35))
                                .frame(width: expanded ? 160 : 80,
                                       height: expanded ? 160 : 80)
                            if expanded {
                                Circle()
                                    .fill(AnycastColor.orange)
                                    .matchedGeometryEffect(id: "dot", in: nsBad)
                                    .frame(width: 48, height: 48)
                            } else {
                                Circle()
                                    .fill(AnycastColor.orange)
                                    .matchedGeometryEffect(id: "dot", in: nsBad)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .frame(width: 170, height: 170)
                    }

                    // 优：geometryGroup
                    VStack(spacing: 10) {
                        BadgeLabel(text: "优 (Good)", tone: .gold)
                        ZStack {
                            RoundedRectangle(cornerRadius: AnycastRadius.card)
                                .fill(AnycastColor.goldAlpha40.opacity(0.35))
                                .frame(width: expanded ? 160 : 80,
                                       height: expanded ? 160 : 80)
                            if expanded {
                                Circle()
                                    .fill(AnycastColor.gold)
                                    .matchedGeometryEffect(id: "dot", in: nsGood)
                                    .frame(width: 48, height: 48)
                                    .geometryGroup()
                            } else {
                                Circle()
                                    .fill(AnycastColor.gold)
                                    .matchedGeometryEffect(id: "dot", in: nsGood)
                                    .frame(width: 24, height: 24)
                                    .geometryGroup()
                            }
                        }
                        .frame(width: 170, height: 170)
                    }
                }
                .animation(.spring(response: 0.55, dampingFraction: 0.72), value: expanded)

                Button(expanded ? "Collapse" : "Expand") {
                    expanded.toggle()
                }
                .buttonStyle(.borderedProminent)
                .tint(AnycastColor.sand12)
                .controlSize(.small)
                .foregroundStyle(.white)
            }
        } controls: {
            Text("iOS 17+：geometryGroup() 把子树几何先打包再插值，避免子里的 matchedGeometry 与父级的 frame 在不同 layout pass 上各自动，导致「先跳后拉」。")
                .font(.system(size: 12))
                .foregroundStyle(AnycastColor.sand9)
        }
    }
}

#Preview("12.6 geometryGroup") { PerfGeometryGroupDemo() }


// MARK: - 共享：差/优 标签
private struct BadgeLabel: View {
    enum Tone { case orange, gold }
    let text: String
    let tone: Tone

    var body: some View {
        Text(text)
            .multilineTextAlignment(.center)
            .font(.system(size: 11, weight: .bold))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(tone == .orange ? AnycastColor.orange : AnycastColor.gold,
                        in: Capsule())
    }
}


// MARK: - Chapter root —— 章节入口列表
struct Chapter12_Performance: View {
    private struct Demo: Identifiable {
        let id = UUID()
        let number: Int
        let title: String
        let subtitle: String
        let view: AnyView
    }

    private var demos: [Demo] {
        [
            Demo(number: 1, title: "frame vs scaleEffect",
                 subtitle: "Animatable 字段选错：layout 重算 vs transform pass",
                 view: AnyView(PerfFrameVsScaleDemo())),
            Demo(number: 2, title: "compositingGroup",
                 subtitle: "重叠透明体先合成再 opacity，避免颜色叠加变深",
                 view: AnyView(PerfCompositingGroupDemo())),
            Demo(number: 3, title: "@Published vs @Observable",
                 subtitle: "粗粒度全失效 vs keyPath 粒度订阅",
                 view: AnyView(PerfObservedVsObservableDemo())),
            Demo(number: 4, title: "ForEach identity",
                 subtitle: "indices 漂移 vs 业务 id 稳定",
                 view: AnyView(PerfForEachIdentityDemo())),
            Demo(number: 5, title: "drawingGroup",
                 subtitle: "静态复杂矢量离屏一次，平移走 GPU blit",
                 view: AnyView(PerfDrawingGroupDemo())),
            Demo(number: 6, title: "geometryGroup",
                 subtitle: "iOS 17+ matchedGeometry 配父级 frame 动",
                 view: AnyView(PerfGeometryGroupDemo()))
        ]
    }

    var body: some View {
        List {
            Section("第 12 章 · 性能 + 高级模式") {
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Ch. 12 Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Chapter 12 — Performance") {
    NavigationStack { Chapter12_Performance() }
}
