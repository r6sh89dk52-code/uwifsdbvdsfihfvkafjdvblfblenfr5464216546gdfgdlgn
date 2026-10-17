import SwiftUI
import LocalAuthentication

private enum Brand {
    static let red = Color(red: 0.88, green: 0.09, blue: 0.16)
}

@main
struct DANPERNativeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("danper.appearance") private var appearance="system"
    @State private var authCycle=UUID()
    @State private var activeContext:LAContext?
    @State private var authenticated = false
    @State private var hasUnlockedOnce = false
    @State private var unlocking = false
    @State private var authError = ""
    @State private var autoAttemptedThisForeground = false
    @State private var manualRetryAvailable = false
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
                        Text("SALUD MÓVIL")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Modo de prueba — datos ficticios. Acceso protegido con Face ID o código.")
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
                        if unlocking {
                            HStack(spacing: 12) {
                                ProgressView()
                                Text("Verificando identidad…")
                                    .font(.subheadline.weight(.medium))
                            }
                            .padding(14)
                            .accessibilityLabel("Comprobando acceso seguro")
                        } else if manualRetryAvailable {
                            Button(action: authenticate) {
                                Label("Reintentar Face ID o usar código", systemImage: "faceid")
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.red)
                            .padding(.horizontal, 25)
                        }
                        Spacer()
                        Text("DANPER · Salud ocupacional")
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
            .preferredColorScheme(appearance=="dark" ? .dark : appearance=="light" ? .light : nil)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    authCycle=UUID()
                    activeContext?.invalidate()
                    activeContext=nil
                    unlocking=false
                    authenticated = false
                    autoAttemptedThisForeground = false
                    manualRetryAvailable = false
                } else if phase == .active {
                    attemptAutomaticUnlock()
                }
            }
            .onChange(of: onboardingFinished) { _, finished in
                if finished { attemptAutomaticUnlock() }
            }
            .task { attemptAutomaticUnlock() }
        }
    }

    private func attemptAutomaticUnlock() {
        guard onboardingFinished, scenePhase == .active,
              !authenticated, !autoAttemptedThisForeground else { return }
        // One automatic attempt per foreground entry avoids Face ID cancellation loops.
        autoAttemptedThisForeground = true
        authenticate()
    }

    private func authenticate() {
        guard !unlocking else { return }
        unlocking = true
        manualRetryAvailable = false
        authError = ""
        let context = LAContext()
        activeContext=context
        let cycle=authCycle
        context.evaluatePolicy(.deviceOwnerAuthentication,
            localizedReason: "Proteger el acceso a DANPER Salud Móvil Nativa") { success, error in
            DispatchQueue.main.async {
                guard cycle==authCycle else{return}
                activeContext=nil
                unlocking = false
                authenticated = success
                if success { hasUnlockedOnce = true }
                if !success {
                    manualRetryAvailable = true
                    authError = error?.localizedDescription ?? "No se pudo confirmar la autenticación del dispositivo."
                }
            }
        }
    }
}

