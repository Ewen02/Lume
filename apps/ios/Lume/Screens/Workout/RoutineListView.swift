import SwiftData
import SwiftUI

struct RoutineListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \RoutineModel.order) private var routineModels: [RoutineModel]
    @State private var routeRoutine: Routine?
    @State private var showEditor = false

    private var routines: [Routine] {
        routineModels.isEmpty ? Mock.routines : routineModels.map(\.asRoutine)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Spacing.sm) {
                    ForEach(routines) { r in
                        Button { routeRoutine = r } label: { RoutineCard(routine: r) }.buttonStyle(.lumePress)
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
        .onAppear { seedDefaultRoutinesIfNeeded(ctx) }
    }
}

#Preview { RoutineListView().modelContainer(LumeStore.preview) }
