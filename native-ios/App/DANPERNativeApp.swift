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
    @State private var hasClinicalSource=false
    @State private var sourceResolved=false
    @State private var sessionStarted=false
    @State private var automaticUnlockScheduled=false
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

    private var redesignDemoProbe:Bool {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--danper-redesign-demo")
        #else
        return false
        #endif
    }
    private var redesignAccessProbe:Bool {
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("--danper-redesign-access")
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
                } else if redesignDemoProbe {
                    #if DEBUG && targetEnvironment(simulator)
                    DanperDemoInspection()
                    #endif
                } else if redesignAccessProbe {
                    #if DEBUG && targetEnvironment(simulator)
                    DanperAccessView(unlocking:false,canRetry:false,error:"",onUnlock:{})
                    #endif
                } else if !sourceResolved {
                    DanperLoadingState(title:"Preparando DANPER…")
                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                        .background(DanperBackdrop())
                } else if onboardingFinished || hasClinicalSource {
                    if authenticated || sessionStarted {
                        N2ClinicalWorkspaceGateView(authenticatedLaunch:true,sessionUnlocked:authenticated,onLock:lockAccess)
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
            .environment(\.danperAuthenticatedSession,authenticated)
            .preferredColorScheme(.dark)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    authCycle=UUID()
                    automaticUnlockScheduled=false
                    activeContext?.invalidate()
                    activeContext=nil
                    access.lock()
                    manualRetryAvailable = false
                } else if phase == .inactive,automaticUnlockScheduled,!unlocking {
                    authCycle=UUID();automaticUnlockScheduled=false
                } else if phase == .active {
                    attemptAutomaticUnlock()
                }
            }
            .onChange(of:sourceResolved) {_,ready in
                if ready {attemptAutomaticUnlock()}
            }
            .onChange(of: onboardingFinished) { _, finished in
                if finished { attemptAutomaticUnlock() }
            }
            .onChange(of:authenticated) {_,value in if value {sessionStarted=true}}
            .task {
                if !interactionProbe && !shellProbe && !redesignDemoProbe && !redesignAccessProbe {
                    let exists=await N2ProtectedClinicalIOSVault.shared.hasStoredClinicalSource()
                    hasClinicalSource=exists
                    if exists {onboardingFinished=true}
                }
                sourceResolved=true
                attemptAutomaticUnlock()
            }
        }
    }

    private func lockAccess() {
        authCycle=UUID();automaticUnlockScheduled=false;activeContext?.invalidate();activeContext=nil
        access.lock();manualRetryAvailable=true;authError=""
    }

    private func attemptAutomaticUnlock() {
        guard !interactionProbe,!shellProbe,!redesignDemoProbe,!redesignAccessProbe,(onboardingFinished || hasClinicalSource), scenePhase == .active,
              !automaticUnlockScheduled,!manualRetryAvailable,!authenticated,!unlocking,
              !access.automaticAttempted else {return}
        // Reserve only after the window settles. A transient inactive phase must
        // not consume the foreground's single automatic authentication attempt.
        automaticUnlockScheduled=true
        let cycle=authCycle
        Task { @MainActor in
            try? await Task.sleep(for:.milliseconds(350))
            guard cycle==authCycle else{return}
            automaticUnlockScheduled=false
            guard scenePhase == .active,!manualRetryAvailable,access.reserveAutomatic() else{return}
            authenticate()
        }
    }

    private func authenticate() {
        guard (onboardingFinished || hasClinicalSource),scenePhase == .active,access.begin() else { return }
        manualRetryAvailable = false
        authError = ""
        let context = LAContext()
        context.localizedCancelTitle="Cancelar"
        context.localizedFallbackTitle="Usar código del dispositivo"
        activeContext=context
        let cycle=authCycle
        context.evaluatePolicy(.deviceOwnerAuthentication,
            localizedReason: "Acceder de forma segura a tu información de salud ocupacional") { success, error in
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


/// Authentication stays owned by the app lifecycle. Both buttons use iOS
/// device-owner authentication; only the system handles the device passcode.
struct DanperAccessView:View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let unlocking:Bool
    let canRetry:Bool
    let error:String
    let onUnlock:()->Void
    var onUseCode:(()->Void)?=nil
    private let version=DanperAppVersion()
    var body:some View {
        GeometryReader {geo in
            ScrollView {
                VStack(spacing:0) {
                    hero(width:geo.size.width,height:max(315,geo.size.height*0.56))
                    if dynamicTypeSize.isAccessibilitySize {
                        Text("Cuidamos lo más importante, nuestra gente.")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal:false,vertical:true)
                            .frame(maxWidth:.infinity,alignment:.leading)
                            .padding(.horizontal,26).padding(.top,16).padding(.bottom,24)
                    }
                    VStack(spacing:13) {
                        Image(systemName:"faceid").font(.system(size:38,weight:.light))
                            .foregroundStyle(DanperStyle.red).frame(width:70,height:70)
                            .danperGlassSurface(cornerRadius:20)
                            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(DanperStyle.red.opacity(0.6),lineWidth:0.7))
                            .accessibilityHidden(true)
                        if !error.isEmpty {
                            Label(error,systemImage:"exclamationmark.circle")
                                .font(.footnote).foregroundStyle(.orange)
                                .multilineTextAlignment(.center)
                                .accessibilityIdentifier("premium-auth-error")
                        }
                        Button(action:onUnlock) {
                            HStack(spacing:12) {
                                if unlocking {ProgressView().tint(.white)}
                                else {Image(systemName:"faceid").font(.title2)}
                                Text(unlocking ? "Verificando identidad…" : canRetry ? "Reintentar Face ID" : "Ingresar con Face ID")
                                Spacer(minLength:0)
                                if !unlocking {Image(systemName:"chevron.right").font(.caption.weight(.semibold))}
                            }
                        }.buttonStyle(DanperGlassAction(accented:true)).disabled(unlocking)
                            .accessibilityLabel(unlocking ? "Verificando identidad…" : canRetry ? "Reintentar Face ID" : "Ingresar con Face ID")
                            .accessibilityIdentifier("premium-face-id")
                        HStack(spacing:14) {
                            Rectangle().fill(.white.opacity(0.14)).frame(height:0.5)
                            Text("o").font(.caption).foregroundStyle(.secondary)
                            Rectangle().fill(.white.opacity(0.14)).frame(height:0.5)
                        }.padding(.horizontal,25)
                        Button(action:onUseCode ?? onUnlock) {
                            HStack(spacing:12) {
                                Image(systemName:"circle.grid.3x3.fill").font(.title2)
                                Text("Usar código del dispositivo")
                                Spacer(minLength:0)
                                Image(systemName:"chevron.right").font(.caption.weight(.semibold))
                            }
                        }.buttonStyle(DanperGlassAction()).disabled(unlocking)
                            .accessibilityHint("Abre la autenticación segura de iOS, que permite usar el código del iPhone.")
                            .accessibilityIdentifier("premium-device-code")
                        HStack(spacing:12) {
                            Image(systemName:"lock.shield").font(.title).foregroundStyle(DanperStyle.red).accessibilityHidden(true)
                            VStack(alignment:.leading,spacing:5) {
                                Text("Fuente clínica protegida").font(.caption.weight(.semibold))
                                Text("Tus datos están seguros y encriptados.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.top,15)
                        Text(version.compact).font(.caption2).foregroundStyle(.secondary).padding(.top,6)
                            .accessibilityIdentifier("premium-access-version")
                    }.padding(.horizontal,26).padding(.top,dynamicTypeSize.isAccessibilitySize ? 0:-20).padding(.bottom,20)
                        .frame(maxWidth:520).frame(maxWidth:.infinity)
                }.frame(minHeight:geo.size.height,alignment:.top)
            }.background(DanperBackdrop()).scrollIndicators(.hidden)
        }.environment(\.colorScheme,.dark)
    }
    private func hero(width:CGFloat,height:CGFloat)->some View {
        ZStack(alignment:.topLeading) {
            // Exact supplied portrait, unchanged bytes. All lettering, curves
            // and controls are native SwiftUI; no phone/mockup is embedded.
            Image("ClinicalPortrait").resizable().scaledToFill()
                .frame(width:width,height:height,alignment:.top).clipped()
                .accessibilityHidden(true)
            LinearGradient(colors:[.black.opacity(0.12),.clear,DanperStyle.canvas],startPoint:.top,endPoint:.bottom)
            LinearGradient(colors:[.black.opacity(0.40),.clear],startPoint:.leading,endPoint:.trailing)
            VStack(alignment:.leading,spacing:11) {
                DanperWordmark(width:min(165,width*0.44),color:DanperStyle.red)
                Text("SALUD MÓVIL").font(.caption.weight(.semibold)).tracking(3)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength:30)
                    Text("Cuidamos\nlo más importante,\nnuestra gente.")
                        .font(.subheadline.weight(.semibold)).lineSpacing(3)
                        .fixedSize(horizontal:false,vertical:true)
                        .frame(width:width*0.50,alignment:.leading)
                        .shadow(color:.black.opacity(0.7),radius:8)
                    Spacer(minLength:55)
                } else {
                    Spacer(minLength:0)
                }
            }.foregroundStyle(.white).padding(.leading,27).padding(.top,20).padding(.bottom,35)
            DanperAccessRibbon().fill(LinearGradient(colors:[DanperStyle.red.opacity(0.8),DanperStyle.deepRed.opacity(0.15)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .frame(height:80).frame(maxHeight:.infinity,alignment:.bottom)
                .allowsHitTesting(false).accessibilityHidden(true)
            DanperAccessRibbon().stroke(DanperStyle.red.opacity(0.45),lineWidth:0.7)
                .frame(height:80).frame(maxHeight:.infinity,alignment:.bottom)
                .allowsHitTesting(false).accessibilityHidden(true)
        }.frame(width:width,height:height).clipped()
    }
}

private struct DanperAccessRibbon:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path();p.move(to:CGPoint(x:0,y:0))
        p.addCurve(to:CGPoint(x:rect.width,y:rect.height),control1:CGPoint(x:rect.width*0.28,y:rect.height*0.55),control2:CGPoint(x:rect.width*0.75,y:rect.height*0.20))
        p.addLine(to:CGPoint(x:0,y:rect.height));p.closeSubpath();return p
    }
}
