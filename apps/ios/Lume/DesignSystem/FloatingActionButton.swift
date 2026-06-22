import SwiftUI

struct FloatingActionButton: View {
    var icon: AppIcon = .add
    var action: () -> Void = {}
    @State private var appeared = false
    var body: some View {
        Button(action: action) {
            Image(appIcon: icon)
                .lumeIcon(26)
                .foregroundStyle(LumeColor.surface)
                .frame(width: 60, height: 60)
                .background(LumeColor.ink)
                .clipShape(Circle())
                .lumeShadow(.fab)
        }
        .buttonStyle(.lumePress)
        // Apparition au lancement : attire l'œil vers l'action principale.
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(LumeMotion.bouncy.delay(0.15)) { appeared = true } }
    }
}
