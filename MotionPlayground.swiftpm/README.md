# Motion Playground

Anycast iOS 26 SwiftUI 动效 / 交互可运行示例集。和 `../topics/*.md` 一一对应。

## 打开

```bash
open Package.swift           # 终端
# 或 Xcode 26 → File → Open → 选 Package.swift
```

## 怎么用

- 任意 `Sources/MotionPlayground/Chapter*.swift` 打开
- ⌥⌘P 打开 Canvas → 见每个 `#Preview` 实时渲染
- 改代码 → Canvas 即时刷新
- 带 `Slider`/`Picker` 的示例可直接拖动调参数（spring response/bounce、shader 强度、手势速度等）

## 章节

| # | 主题 | 文件 |
|---|---|---|
| 1 | 动画基础 + Spring 物理 | `Chapter01_AnimationBasics.swift` |
| 2 | 自定义动画 / Animatable | `Chapter02_CustomAnimations.swift` |
| 3 | Transitions + matchedGeometry | `Chapter03_Transitions.swift` |
| 4 | Gestures 全集 | `Chapter04_Gestures.swift` |
| 5 | CoreMotion + Haptics | `Chapter05_MotionHaptics.swift` |
| 6 | Metal / Shader 集成 | `Chapter06_MetalShaders.swift` |
| 7 | Canvas + TimelineView | `Chapter07_CanvasTimeline.swift` |
| 8 | ScrollView 动效 | `Chapter08_ScrollEffects.swift` |
| 9 | Symbol &amp; Content Transitions | `Chapter09_SymbolEffects.swift` |
| 10 | iOS 26 Liquid Glass | `Chapter10_LiquidGlass.swift` |
| 11 | Layout / Custom Layout | `Chapter11_LayoutCustom.swift` |
| 12 | 性能 + 高级模式 | `Chapter12_Performance.swift` |

## 注意

- iOS 17+ deployment target；部分示例需 iOS 26（Liquid Glass）—— 已加 `#available` 分支
- CoreMotion / CoreHaptics 在模拟器无真实数据，相关示例改用 Slider 模拟输入
- 共享 token (`AnycastColor` / `AnycastSpacing` / `AnycastRadius` / `AnycastFont`) 在 `DesignTokens.swift`
