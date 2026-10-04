import SwiftUI
import UIKit

/// Nocturne: a quiet dark ground, one blurple accent used as a line and a glow, 8pt radii.
/// Dark appearance takes the Nocturne values; light keeps the system colours it had before.
enum Theme {
    private static func dyn(_ dark: UInt32, _ light: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : light })
    }

    static let bg = dyn(0x161826, .systemBackground)
    static let surface = dyn(0x232532, .secondarySystemBackground)
    static let text = dyn(0xE9E9ED, .label)
    static let divider = dyn(0x383A46, .separator)          // text at 16% over the ground

    static let accent = dyn(0x9184D9, .systemIndigo)
    static let accent300 = dyn(0xD2CEFD, .systemIndigo)     // accent-coloured text at body size
    static let accent700 = dyn(0x5D5294, UIColor.systemIndigo.withAlphaComponent(0.5))
    static let accent800 = dyn(0x423A6A, UIColor.systemIndigo.withAlphaComponent(0.18))
    static let accent900 = dyn(0x2B2741, UIColor.systemIndigo.withAlphaComponent(0.06))

    static let neutral400 = dyn(0xB2B6CA, .secondaryLabel)
    static let neutral500 = dyn(0x9397AB, .secondaryLabel)
    static let neutral700 = dyn(0x595D6C, .tertiaryLabel)
    static let neutral800 = dyn(0x3F424D, .separator)

    static let radius: CGFloat = 8
    static let radiusLg: CGFloat = 14

    /// The page ground: flat, with a faint accent bloom in the top-left corner.
    static var ground: some View {
        bg.overlay(alignment: .topLeading) {
            RadialGradient(colors: [accent900, .clear], center: .topLeading, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Interface copy in the chosen language. Meanings still go through `tr`.
func ui(_ en: String, _ zh: String) -> String { Zh.on ? zh : en }

/// Primary actions are an accent outline, never a fill; secondary ones a divider outline.
struct OutlineButtonStyle: ButtonStyle {
    var prominent = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(prominent ? Theme.accent : Theme.text)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: Theme.radius)
                .fill((prominent ? Theme.accent : Theme.text).opacity(configuration.isPressed ? 0.2 : 0)))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(prominent ? Theme.accent : Theme.divider))
            .contentShape(.rect)
    }
}

/// A 48pt outlined square for a single icon.
struct IconButtonStyle: ButtonStyle {
    var tint: Color = Theme.text
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.iconChrome(tint, pressed: configuration.isPressed)
    }
}

extension View {
    /// The icon-square look, for Menu labels that can't take a ButtonStyle.
    func iconChrome(_ tint: Color = Theme.text, pressed: Bool = false) -> some View {
        self.font(.headline)
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.text.opacity(pressed ? 0.14 : 0)))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.divider))
            .contentShape(.rect)
    }

    /// A surface card; `lit` gives it the accent edge (a flipped card, a selected item).
    func cardSurface(lit: Bool = false) -> some View {
        self.background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusLg))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLg).strokeBorder(lit ? Theme.accent700 : Theme.neutral800))
    }

    /// Replaces the inline title with a breadcrumb trail back to the dashboard.
    func crumbs(_ trail: [String], home: (() -> Void)? = nil) -> some View {
        toolbar { ToolbarItem(placement: .principal) { CrumbLine(trail: trail, home: home) } }
    }
}

/// Rules fade out over their ends rather than stopping cleanly.
struct FadingRule: View {
    var body: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: Theme.divider, location: 0.12),
                               .init(color: Theme.divider, location: 0.88), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }
}

/// מִקְרָא › Verses › Jonah — the first crumb goes home when there is a home to go to.
struct CrumbLine: View {
    let trail: [String]
    var home: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let home {
                Button("מִקְרָא", action: home).foregroundStyle(Theme.neutral500)
                if !trail.isEmpty { chevron }
            }
            ForEach(Array(trail.enumerated()), id: \.offset) { i, t in
                if i > 0 { chevron }
                Text(t).foregroundStyle(i == trail.count - 1 ? Theme.text : Theme.neutral500)
            }
        }
        .font(.caption)
        .lineLimit(1)
        .buttonStyle(.plain)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.neutral700)
    }
}

/// A thin track with an accent fill: how far through a deck you are.
struct ProgressLine: View {
    let fraction: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.neutral800).frame(height: 1)
                Capsule().fill(Theme.accent).frame(width: g.size.width * min(max(fraction, 0), 1), height: 2)
            }
        }
        .frame(height: 2)
        .animation(.easeOut(duration: 0.2), value: fraction)
    }
}
