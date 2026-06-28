import SwiftUI

struct PrimaryButton: View {
    var title: LocalizedStringKey
    var icon: AppIcon? = nil
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(appIcon: icon).lumeIcon(18, weight: .semibold) }
                Text(title).font(.lumeCallout)
            }
            .foregroundStyle(LumeColor.surface)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LumeColor.ink)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .lumeShadow(.fab)
        }
        .buttonStyle(.lumePress)
    }
}

struct SecondaryButton: View {
    var title: LocalizedStringKey
    var icon: AppIcon? = nil
    var action: () -> Void = {}
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon { Image(appIcon: icon).lumeIcon(18, weight: .semibold) }
                Text(title).font(.lumeCallout)
            }
            .foregroundStyle(LumeColor.ink)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(LumeColor.border, lineWidth: 1))
        }
        .buttonStyle(.lumePress)
    }
}

/// Petit bouton rond (steppers, contrôles).
struct RoundIconButton: View {
    var icon: AppIcon
    var filled: Bool = false
    var action: () -> Void = {}
    @ScaledMetric private var size: CGFloat

    init(icon: AppIcon, filled: Bool = false, size: CGFloat = 28, action: @escaping () -> Void = {}) {
        self.icon = icon
        self.filled = filled
        self.action = action
        _size = ScaledMetric(wrappedValue: size, relativeTo: .body)
    }

    var body: some View {
        Button(action: action) {
            Image(appIcon: icon)
                .font(.system(size: size * 0.55, weight: .semibold))
                .foregroundStyle(filled ? LumeColor.surface : LumeColor.ink)
                .frame(width: size, height: size)
                .background(filled ? LumeColor.ink : LumeColor.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.lumePress)
    }
}
