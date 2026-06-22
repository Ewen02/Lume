import SwiftUI

/// Conteneur avec glissement vers la gauche pour révéler un bouton de suppression.
/// Alternative à `.swipeActions` (réservé aux List) pour les cartes dans un ScrollView.
struct SwipeToDelete<Content: View>: View {
    var onDelete: () -> Void
    @ViewBuilder var content: () -> Content

    @State private var offset: CGFloat = 0
    @GestureState private var dragging = false
    private let actionWidth: CGFloat = 84
    private let threshold: CGFloat = 60

    var body: some View {
        ZStack(alignment: .trailing) {
            // Bouton de suppression révélé sous la carte.
            Button { reset(); onDelete() } label: {
                VStack(spacing: 4) {
                    Image(appIcon: .minusCircle).lumeIcon(20, weight: .bold)
                    Text("Suppr.").font(.lumeCaption.weight(.semibold))
                }
                .foregroundStyle(LumeColor.surface)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(LumeColor.negative)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            }
            .buttonStyle(.lumePress)
            .opacity(offset < -8 ? 1 : 0)

            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .updating($dragging) { _, state, _ in state = true }
                        .onChanged { value in
                            // Glissement vers la gauche uniquement.
                            if value.translation.width < 0 {
                                offset = max(value.translation.width, -actionWidth)
                            } else if offset < 0 {
                                offset = min(0, -actionWidth + value.translation.width)
                            }
                        }
                        .onEnded { value in
                            withAnimation(LumeMotion.snappy) {
                                offset = value.translation.width < -threshold ? -actionWidth : 0
                            }
                        }
                )
        }
        .animation(LumeMotion.snappy, value: offset)
    }

    private func reset() {
        withAnimation(LumeMotion.snappy) { offset = 0 }
    }
}
