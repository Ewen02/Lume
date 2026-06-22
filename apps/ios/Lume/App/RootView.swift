import SwiftUI

struct RootView: View {
    @AppStorage("lume.hasOnboarded") private var hasOnboarded = false
    @State private var tab: LumeTab = .today
    @State private var showCapture = false
    @State private var justLoggedID = UUID()

    var body: some View {
        if hasOnboarded {
            mainContent
        } else {
            OnboardingView { withAnimation(LumeMotion.smooth) { hasOnboarded = true } }
                .transition(.opacity)
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
                    FloatingActionButton { showCapture = true }
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
        .sensoryFeedback(.selection, trigger: tab)
        .sensoryFeedback(.success, trigger: justLoggedID)
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
