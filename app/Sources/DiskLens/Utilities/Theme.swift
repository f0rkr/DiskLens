import SwiftUI

extension Color {
    /// Brand accent (matches the website's #5b8cff → #9b6cff).
    static let brand = Color(red: 0.357, green: 0.549, blue: 1.0)
    static let brand2 = Color(red: 0.61, green: 0.42, blue: 1.0)
}

/// A frosted "glass" card surface, matching the brand. Adapts to light/dark.
private struct CardBackground: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07))
            )
    }
}

extension View {
    func card(_ radius: CGFloat = 14) -> some View { modifier(CardBackground(radius: radius)) }
}

/// Icon button with a hover highlight + press feedback. Stable hit area.
struct HoverIconStyle: ButtonStyle {
    var size: CGFloat = 30
    func makeBody(configuration: Configuration) -> some View { Content(c: configuration, size: size) }
    struct Content: View {
        let c: ButtonStyleConfiguration
        let size: CGFloat
        @State private var hover = false
        var body: some View {
            c.label
                .frame(width: size, height: size)
                .foregroundStyle(hover ? Color.primary : Color.secondary)
                .background(hover ? Color.primary.opacity(0.12) : .clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .scaleEffect(c.isPressed ? 0.86 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
                .animation(.easeOut(duration: 0.1), value: c.isPressed)
        }
    }
}

/// Glassy card button — hover border/shadow, press scale. Hit area never moves
/// on hover (no hover-scale), so single clicks always register.
struct CardButtonStyle: ButtonStyle {
    var radius: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View { Content(c: configuration, radius: radius) }
    struct Content: View {
        let c: ButtonStyleConfiguration
        let radius: CGFloat
        @State private var hover = false
        var body: some View {
            c.label
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(hover ? Color.brand : Color.primary.opacity(0.08), lineWidth: hover ? 1.5 : 1))
                .shadow(color: Color.brand.opacity(hover ? 0.22 : 0), radius: 10, y: 4)
                .scaleEffect(c.isPressed ? 0.96 : 1)
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: c.isPressed)
        }
    }
}

/// List-row button with a hover background highlight. Stable hit area.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Content(c: configuration) }
    struct Content: View {
        let c: ButtonStyleConfiguration
        @State private var hover = false
        var body: some View {
            c.label
                .background(hover ? Color.primary.opacity(0.08) : .clear)
                .contentShape(Rectangle())
                .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
                .opacity(c.isPressed ? 0.55 : 1)
        }
    }
}

/// The DiskLens logo mark — the treemap-through-a-lens motif from the app icon.
struct BrandMark: View {
    var size: CGFloat = 56

    var body: some View {
        let r = size * 0.225
        ZStack {
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.14, green: 0.18, blue: 0.28), Color(red: 0.04, green: 0.06, blue: 0.11)],
                    startPoint: .top, endPoint: .bottom))
            GeometryReader { g in
                let w = g.size.width, h = g.size.height
                ZStack(alignment: .topLeading) {
                    tile(FileColor.color(forKind: .folder),   0,        0,        w * 0.55, h * 0.62)
                    tile(FileColor.color(forKind: .code),      w * 0.59, 0,        w * 0.41, h * 0.46)
                    tile(FileColor.color(forKind: .media),     w * 0.59, h * 0.50, w * 0.41, h * 0.50)
                    tile(FileColor.color(forKind: .document),  0,        h * 0.66, w * 0.55, h * 0.34)
                }
            }
            .padding(size * 0.18)
            Image(systemName: "magnifyingglass")
                .font(.system(size: size * 0.34, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .offset(x: size * 0.14, y: size * 0.14)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: size * 0.12, y: size * 0.06)
    }

    private func tile(_ c: Color, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
            .fill(c)
            .frame(width: w, height: h)
            .offset(x: x, y: y)
    }
}
