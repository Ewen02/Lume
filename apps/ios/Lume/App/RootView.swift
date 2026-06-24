import SwiftData
import SwiftUI

struct RootView: View {
    @AppStorage("lume.hasOnboarded") private var hasOnboarded = false
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeightSample.date, order: .reverse) private var weightSamples: [WeightSample]
    @State private var tab: LumeTab = .today
    @State private var showCapture = false
    @State private var showSession = false
    @State private var showWeight = false
    @State private var justLoggedID = UUID()

    var body: some View {
        if hasOnboarded {
            mainContent
        } else {
            OnboardingView { withAnimation(LumeMotion.smooth) { hasOnboarded = true } }
                .transition(.opacity)
        }
    }

    /// L'icône du bouton flottant change selon l'onglet (action contextuelle).
    private var fabIcon: AppIcon {
        switch tab {
        case .workout: .workout
        case .progress: .weight
        default: .add
        }
    }

    /// Action contextuelle du bouton flottant selon l'onglet courant.
    private func fabAction() {
        switch tab {
        case .workout: showSession = true
        case .progress: showWeight = true
        default: showCapture = true
        }
    }

    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            LumeColor.cream.ignoresSafeArea()

            Group {
                switch tab {
                case .today: TodayView(highlightTrigger: justLoggedID)
                case .workout: WorkoutHomeView()
                case .progress: ProgressDashboardView()
                case .profile: ProfileView()
                }
            }
            .transition(.opacity)
            .animation(LumeMotion.smooth, value: tab)

            LumeTabBar(selection: $tab)
                .padding(.horizontal, Spacing.lg)
                .overlay(alignment: .top) {
                    FloatingActionButton(icon: fabIcon) { fabAction() }
                        .offset(y: -30)
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
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.success, trigger: justLoggedID)
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
