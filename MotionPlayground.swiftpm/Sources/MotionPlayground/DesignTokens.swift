// DesignTokens.swift — Anycast 颜色 / 间距 / 圆角 / 字体
// 所有 Chapter*.swift 共用，请勿在 Chapter 文件内重复定义。
import SwiftUI

public enum AnycastColor {
    // Sand 调色（中性背景与文字层级）
    public static let sand1   = Color(red: 0.992, green: 0.988, blue: 0.980)
    public static let sand2   = Color(red: 0.957, green: 0.929, blue: 0.878)
    public static let sand3   = Color(red: 0.914, green: 0.875, blue: 0.788)
    public static let sand4   = Color(red: 0.839, green: 0.784, blue: 0.659)
    public static let sand9   = Color(red: 0.420, green: 0.369, blue: 0.267)
    public static let sand12  = Color(red: 0.122, green: 0.102, blue: 0.071)

    // Gold 强调
    public static let gold       = Color(red: 0.710, green: 0.545, blue: 0.227)
    public static let gold9      = gold
    public static let goldAlpha40 = gold.opacity(0.40)
    public static let goldAlpha60 = gold.opacity(0.60)
    public static let goldAlpha9  = gold.opacity(0.90)

    // Orange 高光 / 警告
    public static let orange       = Color(red: 0.878, green: 0.482, blue: 0.231)
    public static let orange9      = orange
    public static let orangeAlpha40 = orange.opacity(0.40)
    public static let orangeAlpha60 = orange.opacity(0.60)
    public static let orangeAlpha80 = orange.opacity(0.80)
    public static let orangeAlpha9  = orange.opacity(0.90)
}

public enum AnycastSpacing {
    public static let gap: CGFloat        = 12
    public static let pageH: CGFloat      = 16
    public static let pageHeader: CGFloat = 24
    public static let sectionGap: CGFloat = 28
}

public enum AnycastRadius {
    public static let sm: CGFloat        = 8
    public static let card: CGFloat      = 24
    public static let cardLarge: CGFloat = 34
}

public enum AnycastFont {
    /// 显示字（大标题 / 数字 badge）
    public static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }
    public static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Helper：参数面板容器
/// 把可调参数区与示例区竖向分开的标准容器，所有 chapter 的 slider playground 用它包一下。
public struct PlaygroundFrame<Demo: View, Controls: View>: View {
    let title: String
    let demo: Demo
    let controls: Controls

    public init(_ title: String,
                @ViewBuilder demo: () -> Demo,
                @ViewBuilder controls: () -> Controls) {
        self.title = title
        self.demo = demo()
        self.controls = controls()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AnycastSpacing.gap) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnycastColor.sand9)
                .textCase(.uppercase)
                .tracking(0.8)

            ZStack {
                RoundedRectangle(cornerRadius: AnycastRadius.card)
                    .fill(AnycastColor.sand2)
                demo
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 240)

            VStack(alignment: .leading, spacing: 10) {
                controls
            }
            .padding(14)
            .background(AnycastColor.sand12.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: AnycastRadius.sm))
        }
        .padding(AnycastSpacing.pageH)
    }
}
