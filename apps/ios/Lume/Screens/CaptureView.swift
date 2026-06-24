import PhotosUI
import SwiftUI

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.foodAPI) private var api
    @StateObject private var camera = CameraController()
    @State private var mode = 0

    @State private var analyzePayload: AnalyzePayload?
    @State private var product: ScannedProduct?
    @State private var isResolving = false
    @State private var errorMessage: String?
    @State private var photoItem: PhotosPickerItem?
    @State private var showFavorites = false
    @State private var flash = false
    @State private var shutterTrigger = 0

    /// Appelé après un ajout réel au journal → permet à RootView de fermer la capture
    /// et d'animer le dashboard.
    var onLogged: () -> Void = {}

    private struct AnalyzePayload: Identifiable { let id = UUID(); let data: Data }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            TopBar(title: "Ajouter un repas", leading: .close, onLeading: { dismiss() })
                .padding(.horizontal, Spacing.xl).padding(.top, Spacing.sm)

            cameraArea
            SegmentedPicker(options: ["Photo", "Code-barres"], selection: $mode)
            controls
            Button { showFavorites = true } label: {
                HStack(spacing: Spacing.xs) {
                    Image(appIcon: .recents).lumeIcon(16, weight: .semibold)
                    Text("Mes aliments enregistrés").font(.lumeSubhead.weight(.semibold))
                }.foregroundStyle(LumeColor.ink)
            }.buttonStyle(.lumePress)
            Spacer()
        }
        .background(LumeColor.cream.ignoresSafeArea())
        .overlay { if isResolving { loadingOverlay } }
        .overlay { if flash { Color.white.ignoresSafeArea().transition(.opacity) } }
        .sensoryFeedback(.impact(weight: .medium), trigger: shutterTrigger)
        .task { if mode == 0 { await startCameraIfAllowed() } }
        .onDisappear { camera.stop() }
        .onChange(of: mode) { _, newMode in
            // Photo = caméra AVFoundation ; scan = VisionKit. On ne fait pas tourner les deux.
            if newMode == 0 { Task { await startCameraIfAllowed() } } else { camera.stop() }
        }
        .fullScreenCover(item: $analyzePayload) { payload in
            AnalyzeView(imageData: payload.data, onLogged: handleLogged)
        }
        .sheet(item: $product) { p in
            BarcodeResultView(product: p, onLogged: handleLogged)
        }
        .sheet(isPresented: $showFavorites) { FavoritesView() }
        .onChange(of: photoItem) { _, newValue in
            guard let newValue else { return }
            Task {
                let data = try? await newValue.loadTransferable(type: Data.self)
                photoItem = nil
                // On laisse le PhotosPicker se fermer AVANT d'ouvrir Analyse en plein écran,
                // sinon la présentation s'empile et la safe area (TopBar) se calcule mal.
                try? await Task.sleep(nanoseconds: 350_000_000)
                if let data { analyzePayload = AnalyzePayload(data: data) }
            }
        }
        .alert("Oups", isPresented: Binding(get: { errorMessage != nil },
                                            set: { if !$0 { errorMessage = nil } }))
        {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private let cameraShape = RoundedRectangle(cornerRadius: Radius.xxl + 4, style: .continuous)

    private var cameraArea: some View {
        ZStack {
            cameraShape.fill(LumeColor.ink)
            if mode == 0 {
                photoViewfinder
            } else if DataScannerView.isSupported {
                DataScannerView(mode: .barcode) { value in resolveBarcode(value) }
                    .clipShape(cameraShape)
                scanHint("Vise le code-barres")
            } else {
                unavailable
            }
        }
        .frame(height: 440)
        .padding(.horizontal, Spacing.xl)
    }

    /// Mode photo : viseur caméra live intégré. Repli galerie si pas de caméra (simulateur).
    @ViewBuilder private var photoViewfinder: some View {
        if CameraController.isAvailable {
            CameraPreview(session: camera.session)
                .clipShape(cameraShape)
            scanHint("Cadre ton plat, puis touche le bouton")
        } else {
            VStack(spacing: Spacing.md) {
                Image(appIcon: .viewfinder).lumeIcon(80, weight: .thin).foregroundStyle(.white.opacity(0.85))
                Text("Caméra indisponible ici").font(.lumeFootnote).foregroundStyle(.white.opacity(0.9))
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Choisir dans la galerie").font(.lumeSubhead.weight(.semibold))
                        .foregroundStyle(LumeColor.ink)
                        .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg)
                        .background(LumeColor.surface).clipShape(Capsule())
                }
            }
        }
    }

    private func scanHint(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text).font(.lumeFootnote).foregroundStyle(.white)
                .padding(.vertical, Spacing.sm).padding(.horizontal, Spacing.lg)
                .background(.black.opacity(0.5)).clipShape(Capsule()).padding(.bottom, Spacing.lg)
        }
    }

    private var unavailable: some View {
        VStack(spacing: Spacing.sm) {
            Image(appIcon: .warning)
                .lumeIcon(40, weight: .regular).foregroundStyle(.white.opacity(0.8))
            Text("Scanner indisponible sur cet appareil")
                .font(.lumeFootnote).foregroundStyle(.white.opacity(0.9))
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            ProgressView().controlSize(.large).tint(.white)
        }
    }

    private var controls: some View {
        HStack {
            PhotosPicker(selection: $photoItem, matching: .images) { squareIcon(.gallery) }
                .accessibilityLabel("Choisir une photo dans la galerie")
            Spacer()
            Button { takePhoto() } label: {
                ZStack {
                    Circle().stroke(LumeColor.ink, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(mode == 0 ? LumeColor.ink : LumeColor.muted).frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.lumePress)
            .disabled(mode != 0)
            .accessibilityLabel("Prendre une photo du repas")
            Spacer()
            Button { mode = mode == 0 ? 1 : 0 } label: {
                squareIcon(mode == 0 ? .barcode : .camera)
            }
            .buttonStyle(.lumePress)
            .accessibilityLabel(mode == 0 ? "Passer au scan de code-barres" : "Revenir à la photo")
        }
        .padding(.horizontal, 45)
    }

    private func takePhoto() {
        guard mode == 0, CameraController.isAvailable else { return }
        // Effet d'obturateur : flash blanc bref + retour haptique.
        shutterTrigger += 1
        withAnimation(LumeMotion.flashIn) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(LumeMotion.flashOut) { flash = false }
        }
        camera.capturePhoto { result in
            switch result {
            case let .success(data): analyzePayload = AnalyzePayload(data: data)
            case .failure: errorMessage = "La photo n'a pas pu être prise. Réessaie."
            }
        }
    }

    /// Un aliment a été ajouté au journal depuis Analyse/Code-barres : on ferme la capture
    /// et on prévient le parent (RootView) pour animer le dashboard.
    private func handleLogged() {
        dismiss()
        onLogged()
    }

    /// Demande l'autorisation caméra puis démarre le viseur. Sans caméra (simu), no-op.
    private func startCameraIfAllowed() async {
        guard CameraController.isAvailable else { return }
        let granted = Permissions.cameraGranted ? true : await Permissions.requestCamera()
        if granted {
            camera.start()
        } else {
            errorMessage = "Active l'accès à la caméra dans Réglages pour photographier tes repas."
        }
    }

    private func squareIcon(_ icon: AppIcon) -> some View {
        Image(appIcon: icon).lumeIcon(24, weight: .semibold).foregroundStyle(LumeColor.ink)
            .frame(width: 54, height: 54).background(LumeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous)).lumeShadow(.soft)
    }

    private func resolveBarcode(_ code: String) {
        isResolving = true
        Task {
            do {
                if let p = try await api.barcode(code) { product = p }
                else { errorMessage = "Produit introuvable (\(code))." }
            } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "Erreur réseau." }
            isResolving = false
        }
    }
}

#Preview { CaptureView() }
