import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Rechercher un aliment"
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(appIcon: .search).lumeIcon(16, weight: .semibold).foregroundStyle(LumeColor.muted)
            TextField(placeholder, text: $text)
                .font(.lumeBody).foregroundStyle(LumeColor.ink)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(appIcon: .close).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg).frame(height: 48)
        .background(LumeColor.surface)
        .clipShape(Capsule())
        .lumeShadow(.soft)
    }
}
