// ContentView.swift — Motion Playground 顶层导航
// 12 章每章一个 NavigationLink，点进去看示例列表
import SwiftUI

public struct ContentView: View {
    public init() {}
    public var body: some View {
        NavigationStack {
            List {
                Section("章节") {
                    NavigationLink("1. 动画基础 + Spring 物理")        { Chapter01_AnimationBasics() }
                    NavigationLink("2. 自定义动画 / Animatable")        { Chapter02_CustomAnimations() }
                    NavigationLink("3. Transitions + matchedGeometry")  { Chapter03_Transitions() }
                    NavigationLink("4. Gestures 全集")                  { Chapter04_Gestures() }
                    NavigationLink("5. CoreMotion + Haptics")           { Chapter05_MotionHaptics() }
                    NavigationLink("6. Metal / Shader 集成")             { Chapter06_MetalShaders() }
                    NavigationLink("7. Canvas + TimelineView")          { Chapter07_CanvasTimeline() }
                    NavigationLink("8. ScrollView 动效")                { Chapter08_ScrollEffects() }
                    NavigationLink("9. Symbol & Content Transitions")   { Chapter09_SymbolEffects() }
                    NavigationLink("10. iOS 26 Liquid Glass")           { Chapter10_LiquidGlass() }
                    NavigationLink("11. Layout 动画 / Custom Layout")    { Chapter11_LayoutCustom() }
                    NavigationLink("12. 性能 + 高级模式")                { Chapter12_Performance() }
                }
                Section("说明") {
                    Text("打开任意 Chapter*.swift → ⌥⌘P 打开 Canvas → 见 #Preview 实时刷新；改代码即时反映。带 slider 的示例可直接拖动调参数。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Motion Playground")
            .listStyle(.insetGrouped)
        }
    }
}

#Preview("App Root") {
    ContentView()
}
