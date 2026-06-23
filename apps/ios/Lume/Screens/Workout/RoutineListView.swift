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
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    if routineModels.isEmpty {
                        LumeEmptyState(icon: .routine, title: "Aucune routine",
                                       message: "Crée ta première routine avec le bouton ci-dessous.")
                            .padding(.top, Spacing.xxl)
                    } else {
                        ForEach(routineModels) { model in
                            RoutineCard(routine: model.asRoutine) { routeRoutine = model.asRoutine }
                                .contextMenu {
                                    Button(role: .destructive) { ctx.delete(model) } label: {
                                        Label("Supprimer", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }.padding(.horizontal, Spacing.xl).padding(.bottom, 100)
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
}

#Preview { RoutineListView().modelContainer(LumeStore.preview) }
