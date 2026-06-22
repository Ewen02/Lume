import SwiftUI

/// Barre de navigation : bouton gauche optionnel, titre, action droite optionnelle.
struct TopBar: View {
    var title: String
    var leading: AppIcon? = nil
    var trailing: AppIcon? = nil
    var onLeading: () -> Void = {}
    var onTrailing: () -> Void = {}
    var body: some View {
        ZStack {
            Text(title).font(.lumeTitle3).foregroundStyle(LumeColor.ink)
            HStack {
                if let leading { circle(leading, onLeading) } else { Color.clear.frame(width: 40, height: 40) }
                Spacer()
                if let trailing { circle(trailing, onTrailing) } else { Color.clear.frame(width: 40, height: 40) }
            }
        }
        .frame(height: 40)
    }

    private func circle(_ icon: AppIcon, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(appIcon: icon).lumeIcon(18, weight: .semibold).foregroundStyle(LumeColor.ink)
                .frame(width: 40, height: 40).background(LumeColor.surface).clipShape(Circle()).lumeShadow(.soft)
        }.buttonStyle(.lumePress)
    }
}
