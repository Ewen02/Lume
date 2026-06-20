import AVFoundation
import UserNotifications

/// Demandes de permissions hors HealthKit (qui vit dans HealthManager).
enum Permissions {
    /// Accès caméra (photo des repas / scanner). Renvoie true si autorisé.
    static func requestCamera() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Notifications locales (rappels). Renvoie true si autorisé.
    static func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    /// État courant de l'autorisation caméra (sans la redemander).
    static var cameraGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
}
