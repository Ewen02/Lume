import SwiftData
import SwiftUI

struct RoutineListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \RoutineModel.order) private var routineModels: [RoutineModel]
    @State private var routeRoutine: Routine?
    @State private var showEditor = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if routineModels.isEmpty {
                LumeEmptyState(icon: .routine, title: "Aucune routine",
                               message: "Crée ta première routine avec le bouton ci-dessous.")
            } else {
                List {
                    ForEach(routineModels) { model in
                        // La carte est l'UNIQUE vue de la ligne → la prévisualisation de drag épouse la carte.
                        // Les marges passent par listRowInsets (gérées par la cellule, hors preview de drag).
                        RoutineCard(routine: model.asRoutine) { routeRoutine = model.asRoutine }
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xl, bottom: Spacing.xs, trailing: Spacing.xl))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { ctx.delete(model) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                    }
                    .onMove(perform: moveRoutines)
                    Color.clear.frame(height: 80).listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            PrimaryButton(title: "Nouvelle routine", icon: .add) { showEditor = true }
                .padding(.horizontal, Spacing.xl).padding(.bottom, Spacing.sm)
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            TopBar(title: "Routines", leading: .back, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.sm).background(LumeColor.cream)
        }
        .sheet(item: $routeRoutine) { RoutineDetailView(routine: $0) }
        .sheet(isPresented: $showEditor) { RoutineEditorView() }
    }

    /// Réordonne les routines et réécrit leur `order` pour persister la nouvelle position.
    private func moveRoutines(from offsets: IndexSet, to destination: Int) {
        var ordered = routineModels
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (i, model) in ordered.enumerated() {
            model.order = i
        }
    }
}

#Preview { RoutineListView().modelContainer(LumeStore.preview) }
