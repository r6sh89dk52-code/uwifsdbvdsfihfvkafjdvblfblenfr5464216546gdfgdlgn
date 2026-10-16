import SwiftUI
import LocalAuthentication

private enum Brand {
    static let red = Color(red: 0.88, green: 0.09, blue: 0.16)
}

@main
struct DANPERNativeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authenticated = false
    @State private var hasUnlockedOnce = false
    @State private var unlocking = false
    @State private var authError = ""
    @AppStorage("danper.native.onboarding.v1.finished") private var onboardingFinished = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if onboardingFinished {
                    if hasUnlockedOnce {
                        NativeRootView()
                            .opacity(authenticated && scenePhase == .active ? 1 : 0)
                            .accessibilityHidden(!authenticated || scenePhase != .active)
                            .allowsHitTesting(authenticated && scenePhase == .active)
                    }
                    if !authenticated || scenePhase != .active {
                    VStack(spacing: 24) {
                        Spacer()
                        Image("BrandLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 108, height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                        Text("DANPER")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                        Text("SALUD MÓVIL · SWIFTUI")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Versión nativa de evaluación. No reemplaza tu aplicación actual ni modifica su inventario.")
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 26)
                        if !authError.isEmpty {
                            Text(authError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        Button(action: authenticate) {
                            Label(unlocking ? "Verificando…" : "Ingresar con Face ID o código",
                                  systemImage: "faceid")
                                .frame(maxWidth: .infinity)
                                .padding(14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.red)
                        .disabled(unlocking)
                        .padding(.horizontal, 25)
                        Spacer()
                        Text("Todavía es una versión nativa de evaluación; los respaldos reales se inspeccionan solo con tu autorización.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground))
                    }
                } else {
                    NativeFirstRunOnboarding {
                        onboardingFinished = true
                        authError = ""
                    }
                    .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    // Obscure at inactive; require new authentication upon background.
                    authenticated = false
                }
            }
        }
    }

    private func authenticate() {
        guard !unlocking else { return }
        unlocking = true
        authError = ""
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication,
            localizedReason: "Proteger el acceso a DANPER Salud Móvil Nativa") { success, error in
            DispatchQueue.main.async {
                unlocking = false
                authenticated = success
                if success { hasUnlockedOnce = true }
                if !success {
                    authError = error?.localizedDescription ?? "No se pudo confirmar la autenticación del dispositivo."
                }
            }
        }
    }
}
