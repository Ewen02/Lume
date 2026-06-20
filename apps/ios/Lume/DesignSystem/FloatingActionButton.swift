import SwiftUI

struct FloatingActionButton: View {
    var icon: AppIcon = .add
    var action: () -> Void = {}
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
    }
}
