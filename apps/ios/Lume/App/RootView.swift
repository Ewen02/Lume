import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage("lume.hasOnboarded") private var hasOnboarded = false
    /// Modules optionnels choisis à l'onboarding (cf. `ModuleSettings`). Pilotent les onglets visibles.
    @AppStorage(ModuleSettings.financeKey) private var financeEnabled = ModuleSettings.defaultEnabled
    @AppStorage(ModuleSettings.workoutKey) private var workoutEnabled = ModuleSettings.defaultEnabled
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeightSample.date, order: .reverse) private var weightSamples: [WeightSample]
    @State private var tab: LumeTab = .today
    @State private var showCapture = false
    @State private var showSession = false
    @State private var showWeight = false
    @State private var showAddTransaction = false
    @State private var justLoggedID = UUID()
    @State private var financeLoggedID = UUID()

    var body: some View {
        if hasOnboarded {
            mainContent
        } else {
            OnboardingView { withAnimation(LumeMotion.smooth) { hasOnboarded = true } }
                .transition(.opacity)
        }
    }

    /// Onglets affichés, filtrés par les modules activés (Budget/Muscu optionnels).
    private var visibleTabs: [LumeTab] {
        LumeTab.visible(finance: financeEnabled, workout: workoutEnabled)
    }

    /// L'icône du bouton flottant change selon l'onglet (action contextuelle).
    private var fabIcon: AppIcon {
        switch tab {
        case .workout: .workout
        case .progress: .weight
        case .money: .add
        default: .add
        }
    }

    /// Action contextuelle du bouton flottant selon l'onglet courant.
    private func fabAction() {
        switch tab {
        case .workout: showSession = true
        case .progress: showWeight = true
        case .money: showAddTransaction = true
        default: showCapture = true
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            LumeColor.cream.ignoresSafeArea()

            Group {
                switch tab {
                case .today: TodayView(highlightTrigger: justLoggedID)
                case .money: MoneyHomeView(highlightTrigger: financeLoggedID)
                case .workout: WorkoutHomeView()
                case .progress: ProgressDashboardView()
                case .profile: ProfileView()
                }
            }
            .transition(.opacity)
            .animation(LumeMotion.smooth, value: tab)

            // Le FAB est détaché : il flotte centré AU-DESSUS de la barre, séparé d'elle. La barre
            // garde ainsi ses N onglets pleins et réguliers (4 ou 5), sans qu'aucun ne soit recouvert
            // — robuste pour un nombre d'onglets pair comme impair.
            VStack(spacing: Spacing.sm) {
                FloatingActionButton(icon: fabIcon) { fabAction() }
                LumeTabBar(selection: $tab, tabs: visibleTabs)
                    .padding(.horizontal, Spacing.lg)
            }
        }
        .sheet(isPresented: $showCapture) {
            CaptureView {
                // Aliment ajouté : on revient sur le dashboard et on l'anime.
                withAnimation(LumeMotion.smooth) { tab = .today }
                justLoggedID = UUID()
            }
        }
        .sheet(isPresented: $showSession) {
            ActiveSessionView()
        }
        .sheet(isPresented: $showWeight) {
            // Pré-rempli au dernier poids connu (local), sinon l'init retombe sur 70 kg.
            WeightEntryView(current: weightSamples.first?.kg)
        }
        .sheet(isPresented: $showAddTransaction) {
            TransactionEditorView {
                withAnimation(LumeMotion.smooth) { tab = .money }
                financeLoggedID = UUID() // déclenche pulse + haptique sur l'écran Budget
            }
        }
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.success, trigger: justLoggedID)
        // Un module désactivé depuis le Profil ne doit pas laisser un onglet « fantôme » sélectionné.
        .onChange(of: visibleTabs) { _, tabs in
            if !tabs.contains(tab) { withAnimation(LumeMotion.smooth) { tab = .today } }
        }
        // (Re)pose les rappels au lancement et dès que le profil apparaît/change.
        .task(id: profiles.first?.persistentModelID) {
            if let r = profiles.first { await NotificationManager.reschedule(from: r) }
        }
    }
}

struct PlaceholderScreen: View {
    var title: String
    var subtitle: String = ""
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Text(title).font(.lumeDisplay).foregroundStyle(LumeColor.ink)
            if !subtitle.isEmpty { Text(subtitle).font(.lumeSubhead).foregroundStyle(LumeColor.muted) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LumeColor.cream)
    }
}

#Preview { RootView() }
