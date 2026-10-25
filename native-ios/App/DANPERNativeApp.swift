import SwiftUI
import LocalAuthentication
import DanperCore

private enum Brand {
    static let red = Color(red: 0.88, green: 0.09, blue: 0.16)
}

@main
struct DANPERNativeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("danper.appearance") private var appearance="system"
    @State private var authCycle=UUID()
    @State private var activeContext:LAContext?
    @State private var access=N2AccessSession()
    private var authenticated:Bool {access.authenticated}
    private var unlocking:Bool {access.running}
    @State private var authError = ""
    @State private var manualRetryAvailable = false
    @AppStorage("danper.native.onboarding.v1.finished") private var onboardingFinished = false

    private var interactionProbe:Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--danper-ui-probe")
        #else
        return false
        #endif
    }
    /// Safe DEBUG-only visual inspection without Face ID or clinical vault access.
    private var shellProbe:Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--danper-shell-probe")
        #else
        return false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if interactionProbe {
                    #if DEBUG
                    N2InteractionProbe()
                    #endif
                } else if shellProbe {
                    #if DEBUG
                    NativeRootView(layoutMetrics:N2DashboardMetrics.calculate(visits:[],now:Date()))
                    #endif
                } else if onboardingFinished {
                    if authenticated {
                        NavigationStack {
                            N2ClinicalWorkspaceGateView(authenticatedLaunch:true)
                                .id(authCycle)
                        }
                            .opacity(authenticated && scenePhase == .active ? 1 : 0)
                            .accessibilityHidden(!authenticated || scenePhase != .active)
                            .allowsHitTesting(authenticated && scenePhase == .active)
                    }
                    if !authenticated || scenePhase != .active {
                    DanperAccessView(unlocking:unlocking,canRetry:manualRetryAvailable,error:authError,onUnlock:authenticate)

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
                    access.lock()
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
        guard !interactionProbe,!shellProbe,onboardingFinished, scenePhase == .active,
              access.reserveAutomatic() else { return }
        // One automatic attempt per foreground entry avoids Face ID cancellation loops.
        let cycle=authCycle
        Task { @MainActor in
            try? await Task.sleep(for:.milliseconds(350))
            guard cycle==authCycle,scenePhase == .active,!manualRetryAvailable else{return}
            authenticate()
        }
    }

    private func authenticate() {
        guard onboardingFinished,scenePhase == .active,access.begin() else { return }
        manualRetryAvailable = false
        authError = ""
        let context = LAContext()
        context.localizedCancelTitle="Cancelar"
        context.localizedFallbackTitle="Usar código del dispositivo"
        activeContext=context
        let cycle=authCycle
        context.evaluatePolicy(.deviceOwnerAuthentication,
            localizedReason: "Proteger el acceso a DANPER Salud Móvil Nativa") { success, error in
            DispatchQueue.main.async {
                guard cycle==authCycle else{return}
                activeContext=nil
                access.complete(success:success)
                if !success {
                    manualRetryAvailable = true
                    let code=(error as? LAError)?.code
                    authError = code == .userCancel || code == .appCancel || code == .systemCancel
                        ? "Autenticación cancelada" : "No se pudo verificar tu identidad"
                }
            }
        }
    }
}


/// Build222 branded welcome: red upper field and rounded lower access panel.
/// Authentication is owned by the app lifecycle above; this is presentation only.
struct DanperAccessView:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared=false
    let unlocking:Bool
    let canRetry:Bool
    let error:String
    let onUnlock:()->Void
    var body:some View {
        ScrollView {
            VStack(spacing:28) {
                VStack(spacing:12) {
                    Image("BrandLogo").resizable().scaledToFit()
                        .frame(maxWidth:180,maxHeight:120)
                        .padding(20)
                        .background(.white,in:RoundedRectangle(cornerRadius:24))
                    Text("DANPER").font(.system(.largeTitle,design:.rounded,weight:.heavy))
                    Text("SALUD MÓVIL").font(.caption.weight(.bold)).tracking(2)
                    Text("Bienvenido").font(.largeTitle.bold())
                    Text("Departamento de Salud").font(.title3)
                }.foregroundStyle(.white).frame(maxWidth:.infinity).padding(.top,32)
                VStack(spacing:16) {
                    Label("Acceso protegido",systemImage:"lock.shield.fill")
                        .font(.headline)
                    Text("Tu espacio para una atención más rápida, organizada y segura.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if !error.isEmpty {Text(error).font(.footnote).foregroundStyle(.orange).multilineTextAlignment(.center)}
                    if unlocking {
                        HStack(spacing:12) {ProgressView();Text("Verificando identidad…").font(.subheadline)}
                            .frame(maxWidth:.infinity,minHeight:50)
                    } else {
                        Button(action:onUnlock) {
                            Label(canRetry ? "Reintentar Face ID" : "Ingresar con Face ID",systemImage:"faceid")
                        }.buttonStyle(DanperPrimaryButton())
                    }
                    Text("Acceso protegido con Face ID o código del iPhone").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    #if DEBUG
                    // Only the simulator/developer build exposes the demo notice.
                    Label("Modo de prueba · datos ficticios",systemImage:"lock.shield")
                        .font(.caption2).foregroundStyle(.secondary)
                    #endif
                }.padding(24).frame(maxWidth:.infinity)
                    .background(DanperStyle.surface,in:UnevenRoundedRectangle(topLeadingRadius:32,topTrailingRadius:32))
            }.padding(20).frame(maxWidth:540)
                .frame(maxWidth:.infinity)
                .opacity(appeared ? 1:0)
                .offset(y:appeared ? 0:12)
        }.background(DanperStyle.red.ignoresSafeArea())
            .onAppear {
                withAnimation(reduceMotion ? nil : .easeOut(duration:0.3)){appeared=true}
            }
    }
}
