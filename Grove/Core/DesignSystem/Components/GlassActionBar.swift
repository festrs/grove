import SwiftUI

/// Floating translucent capsule background used by bottom action bars
/// (bulk-edit, holding-detail buy/sell, etc.). Pairs with
/// `safeAreaInset(edge: .bottom)` on the host so the bar floats above
/// the system tab bar.
///
/// We deliberately use `.regularMaterial` instead of iOS 26's
/// `glassEffect()`: a `Menu` placed inside a `glassEffect` surface
/// participates in the morph animation and visually replaces the whole
/// surface when opened. `.regularMaterial` keeps the translucent native
/// look without that hijack.
extension View {
    /// Wraps a view in the floating Liquid-Glass capsule used by every bottom
    /// action surface. Pure shape + material — caller controls outer positioning.
    /// Use `glassActionBar()` when you want the standard host-aligned bar
    /// (12pt horizontal + 8pt bottom inset).
    func glassCapsule(cornerRadius: CGFloat = 22) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 3)
    }

    /// Single full-width bar treatment: capsule + host insets so it floats
    /// above the system tab bar when paired with `safeAreaInset(edge: .bottom)`.
    func glassActionBar() -> some View {
        self
            .glassCapsule()
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
    }
}
