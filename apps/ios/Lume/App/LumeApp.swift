import SwiftData
import SwiftUI

@main
struct LumeApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(LumeStore.shared)
            .environment(HealthManager.shared)
    }
}
