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
        guard !interactionProbe,!shellProbe,!redesignDemoProbe,!redesignAccessProbe,onboardingFinished, scenePhase == .active,
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    let unlocking:Bool
    let canRetry:Bool
    let error:String
    let onUnlock:()->Void
    var onUseCode:(()->Void)?=nil
    private let version=DanperAppVersion()
    private var background:Color {colorScheme == .dark ? Color(red:0.035,green:0.012,blue:0.02):Color(red:0.99,green:0.975,blue:0.98)}
    var body:some View {
        GeometryReader {geo in
            ScrollView {
                VStack(spacing:0) {
                    hero(width:geo.size.width,height:max(225,min(330,geo.size.height*0.40)))
                    VStack(spacing:15) {
                        Image(systemName:"faceid")
                            .font(.system(size:44,weight:.light))
                            .foregroundStyle(DanperStyle.red)
                            .frame(width:88,height:88)
                            .background(DanperStyle.red.opacity(0.12),in:RoundedRectangle(cornerRadius:25))
                            .overlay(RoundedRectangle(cornerRadius:25).strokeBorder(DanperStyle.red.opacity(0.15)))
                            .accessibilityHidden(true)
                        Text("Bienvenido").font(.system(.largeTitle,weight:.bold))
                        Text("Accede de forma segura a tu\ninformación de salud ocupacional.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
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
                            }.padding(.horizontal,9)
                        }.buttonStyle(DanperPrimaryButton()).clipShape(Capsule())
                            .disabled(unlocking)
                            .accessibilityLabel(unlocking ? "Verificando identidad…" : canRetry ? "Reintentar Face ID" : "Ingresar con Face ID")
                            .accessibilityIdentifier("premium-face-id")
                        HStack(spacing:14) {
                            Rectangle().fill(Color.secondary.opacity(0.20)).frame(height:0.5)
                            Text("o").font(.caption).foregroundStyle(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.20)).frame(height:0.5)
                        }.padding(.horizontal,25).padding(.top,2)
                        Button(action:onUseCode ?? onUnlock) {
                            Label("Usar código del dispositivo",systemImage:"circle.grid.3x3.fill")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth:.infinity,minHeight:46)
                                .background(Color.primary.opacity(0.045),in:Capsule())
                                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.12)))
                        }.buttonStyle(.plain).disabled(unlocking)
                            .accessibilityHint("Abre la autenticación segura de iOS, que permite usar el código del iPhone.")
                            .accessibilityIdentifier("premium-device-code")
                        HStack(spacing:10) {
                            Image(systemName:"lock.shield").font(.title2).foregroundStyle(DanperStyle.red)
                            VStack(alignment:.leading,spacing:4) {
                                Text("Fuente clínica protegida").font(.caption.weight(.semibold))
                                Text("Tus datos están seguros y encriptados.").font(.caption2).foregroundStyle(.secondary)
                            }
                        }.padding(.top,10)
                        Text(version.compact).font(.caption2).foregroundStyle(.secondary)
                            .accessibilityIdentifier("premium-access-version")
                    }
                    .padding(.horizontal,26).padding(.top,5).padding(.bottom,22)
                    .frame(maxWidth:520).frame(maxWidth:.infinity)
                }.frame(minHeight:geo.size.height,alignment:.top)
            }.background(background.ignoresSafeArea())
                .overlay(alignment:.top) {
                    DanperStyle.red.frame(height:geo.safeAreaInsets.top)
                        .offset(y:-geo.safeAreaInsets.top)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
                .scrollIndicators(.hidden)
        }
    }
    private func hero(width:CGFloat,height:CGFloat)->some View {
        ZStack(alignment:.topLeading) {
            // The gradient remains a complete fallback if the optional photo
            // cannot load. The photo depicts a generated fictional person.
            LinearGradient(colors:[DanperStyle.red,Color(red:0.16,green:0.025,blue:0.05)],startPoint:.topLeading,endPoint:.bottomTrailing)
            if UIImage(named:"AccessHero") != nil {
                Image("AccessHero").resizable().scaledToFill()
                    .frame(width:width,height:height).clipped()
                    .accessibilityHidden(true)
            }
            LinearGradient(colors:[.black.opacity(0.12),.clear,background],startPoint:.top,endPoint:.bottom)
            VStack(alignment:.leading,spacing:11) {
                DanperWordmark(width:min(190,width*0.49))
                Text("SALUD MÓVIL").font(.caption.weight(.semibold)).tracking(3)
                Spacer(minLength:10)
                Text("Cuidamos\nlo más importante,\nnuestra gente")
                    .font(.subheadline.weight(.medium)).lineSpacing(3)
                    .shadow(color:.black.opacity(0.3),radius:5)
                Spacer(minLength:10)
            }.foregroundStyle(.white).padding(.leading,28).padding(.top,20).padding(.bottom,60)
            DanperAccessRibbon().fill(LinearGradient(colors:[DanperStyle.red,DanperStyle.deepRed.opacity(0.4)],startPoint:.topLeading,endPoint:.bottomTrailing))
                .frame(height:70).frame(maxHeight:.infinity,alignment:.bottom)
                .allowsHitTesting(false).accessibilityHidden(true)
        }.frame(width:width,height:height).clipped()
            .background(DanperStyle.red.ignoresSafeArea(edges:.top))
    }
}

private struct DanperAccessRibbon:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path();p.move(to:CGPoint(x:0,y:0))
        p.addCurve(to:CGPoint(x:rect.width,y:rect.height),control1:CGPoint(x:rect.width*0.28,y:rect.height*0.55),control2:CGPoint(x:rect.width*0.75,y:rect.height*0.20))
        p.addLine(to:CGPoint(x:0,y:rect.height));p.closeSubpath();return p
    }
}
