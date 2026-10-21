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
    @State private var authenticated = false
    @State private var hasUnlockedOnce = false
    @State private var unlocking = false
    @State private var authError = ""
    @State private var autoAttemptedThisForeground = false
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
                    if hasUnlockedOnce {
                        NativeRootView()
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
        guard !interactionProbe,onboardingFinished, scenePhase == .active,
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


/// Build222 branded welcome: red upper field and rounded lower access panel.
/// Authentication is owned by the app lifecycle above; this is presentation only.
struct DanperAccessView:View {
    let unlocking:Bool
    let canRetry:Bool
    let error:String
    let onUnlock:()->Void
    var body:some View {
        GeometryReader {geo in
            VStack(spacing:0) {
                VStack(spacing:18) {
                    Spacer(minLength:20)
                    Text("DANPER").font(.system(.largeTitle,design:.rounded,weight:.heavy))
                    Text("SALUD MÓVIL").font(.caption.weight(.bold)).tracking(2)
                    Image(systemName:"cross.case.fill").font(.system(size:32))
                        .frame(width:82,height:82).background(.white.opacity(0.16),in:Circle()).padding(.vertical,12)
                    Text("Bienvenido").font(.largeTitle)
                    Text("Departamento de Salud").font(.title3)
                    Spacer(minLength:28)
                }.foregroundStyle(.white).frame(maxWidth:.infinity,minHeight:geo.size.height*0.57)
                VStack(spacing:18) {
                    Spacer(minLength:22)
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
                    Label("Modo de prueba · datos ficticios",systemImage:"lock.shield").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength:22)
                }.padding(.horizontal,24).frame(maxWidth:.infinity)
                    .background(DanperStyle.surface,in:UnevenRoundedRectangle(topLeadingRadius:32,topTrailingRadius:32))
            }.frame(minHeight:geo.size.height).background(DanperStyle.red)
        }.background(DanperStyle.red.ignoresSafeArea())
    }
}
