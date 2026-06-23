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
                        // Le FOND de la cellule EST la carte (via listRowBackground) → pas de double-fond
                        // au moment du « lift » de drag. Le contenu de la ligne est transparent et tappable.
                        Button { routeRoutine = model.asRoutine } label: { rowContent(model.asRoutine) }
                            .buttonStyle(.lumePress)
                            .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.xl, bottom: Spacing.xs, trailing: Spacing.xl))
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                                    .fill(LumeColor.surface)
                                    .lumeShadow(.soft)
                                    .padding(.horizontal, Spacing.xl).padding(.vertical, Spacing.xs)
                            )
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

    /// Contenu d'une ligne routine (sans fond ni ombre — le fond est porté par listRowBackground).
    private func rowContent(_ routine: Routine) -> some View {
        HStack(spacing: Spacing.md) {
            Image(appIcon: .workout).lumeIcon(20, weight: .semibold).foregroundStyle(LumeColor.ink)
                .frame(width: 46, height: 46).background(LumeColor.cream)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name).font(.lumeHeadline).foregroundStyle(LumeColor.ink)
                Text("\(routine.exercises.count) exercices · \(routine.muscles)")
                    .font(.lumeFootnote).foregroundStyle(LumeColor.muted).lineLimit(1)
            }
            Spacer()
            Image(appIcon: .forward).lumeIcon(14, weight: .semibold).foregroundStyle(LumeColor.muted)
        }
        .padding(Spacing.lg - 2)
        .contentShape(Rectangle())
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
