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


/// Visual-only access cover. The app above continues to own every LAContext,
/// automatic attempt, retry, error and background-lock transition.
struct DanperAccessView:View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var appeared=false
    let unlocking:Bool
    let canRetry:Bool
    let error:String
    let onUnlock:()->Void
    private var version:String {
        let info=Bundle.main.infoDictionary ?? [:]
        let version=info["CFBundleShortVersionString"] as? String ?? "—"
        let build=info["CFBundleVersion"] as? String ?? "—"
        return "Versión \(version) · Compilación \(build)"
    }
    var body:some View {
        GeometryReader { geometry in
            let heroHeight=min(max(geometry.size.height * 0.48,280),420)
            ScrollView {
                VStack(spacing:0) {
                    hero(height:heroHeight,topInset:geometry.safeAreaInsets.top)
                    VStack(spacing:14) {
                        Image(systemName:"faceid")
                            .font(.system(size:34,weight:.medium))
                            .foregroundStyle(GlassClinical.red)
                            .frame(width:66,height:66)
                            .background(GlassClinical.red.opacity(0.10),in:RoundedRectangle(cornerRadius:20))
                            .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(GlassClinical.red.opacity(0.35)))
                            .accessibilityHidden(true)
                        VStack(spacing:5) {
                            Text("Bienvenido").font(.largeTitle.bold())
                            Text("Accede de forma segura a tu información de salud ocupacional.")
                                .font(.subheadline).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        if !error.isEmpty {
                            Label(error,systemImage:"exclamationmark.circle")
                                .font(.footnote).foregroundStyle(.primary)
                                .padding(10).frame(maxWidth:.infinity)
                                .background(Color.orange.opacity(0.16),in:RoundedRectangle(cornerRadius:12))
                                .accessibilityIdentifier("access-error")
                        }
                        Button(action:onUnlock) {
                            HStack(spacing:12) {
                                if unlocking {ProgressView().tint(.white)}
                                else {Image(systemName:"faceid").font(.title2)}
                                Text(unlocking ? "Verificando identidad…" : canRetry ? "Reintentar Face ID" : "Ingresar con Face ID")
                                    .font(.headline).fixedSize(horizontal:false,vertical:true)
                                Spacer(minLength:0)
                                if !unlocking {Image(systemName:"chevron.right").font(.footnote.weight(.bold))}
                            }
                            .padding(.horizontal,20).padding(.vertical,15)
                            .frame(maxWidth:.infinity,minHeight:54)
                            .foregroundStyle(.white)
                            .background(GlassClinical.gradient,in:Capsule())
                        }
                        .buttonStyle(.plain).disabled(unlocking)
                        .accessibilityIdentifier("access-face-id")
                        // Both controls invoke the existing deviceOwnerAuthentication
                        // policy. iOS alone offers/validates the device passcode.
                        Button(action:onUnlock) {
                            HStack(spacing:12) {
                                Image(systemName:"circle.grid.3x3.fill").foregroundStyle(.secondary)
                                Text("Usar código del dispositivo").font(.subheadline)
                                    .fixedSize(horizontal:false,vertical:true)
                                Spacer(minLength:0)
                                Image(systemName:"chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal,20).padding(.vertical,15)
                            .frame(maxWidth:.infinity,minHeight:52)
                            .modifier(GlassClinicalSurface(radius:28))
                        }
                        .buttonStyle(.plain).disabled(unlocking)
                        .accessibilityIdentifier("access-device-code")
                        VStack(spacing:9) {
                            HStack(spacing:10) {
                                Image(systemName:"lock.shield").font(.title2).foregroundStyle(GlassClinical.red)
                                VStack(alignment:.leading,spacing:3) {
                                    Text("Fuente clínica protegida").font(.caption.weight(.semibold))
                                    Text("Acceso protegido con Face ID o código del iPhone")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(version).font(.caption2).foregroundStyle(.secondary)
                            #if DEBUG
                            Label("Modo de prueba · datos ficticios",systemImage:"lock.shield")
                                .font(.caption2).foregroundStyle(.secondary)
                            #endif
                        }.padding(.top,5)
                    }
                    .padding(.horizontal,24).padding(.bottom,16)
                    .frame(maxWidth:540)
                    .opacity(appeared ? 1:0)
                }
                .frame(maxWidth:.infinity)
                .frame(minHeight:geometry.size.height,alignment:.top)
            }
            .scrollIndicators(.hidden)
            .background(GlassClinical.canvas.ignoresSafeArea())
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration:0.3)){appeared=true}
        }
    }
    private func hero(height:CGFloat,topInset:CGFloat)->some View {
        ZStack(alignment:.topLeading) {
            GeometryReader { proxy in
                Image("AccessNurseHero").resizable().scaledToFill()
                    .frame(width:proxy.size.width,height:height+topInset,alignment:.top)
                    .clipped().offset(y:-topInset)
                LinearGradient(stops:[.init(color:.black.opacity(0.3),location:0),
                                      .init(color:.clear,location:0.45),
                                      .init(color:GlassClinical.canvas,location:1)],
                               startPoint:.top,endPoint:.bottom)
                    .padding(.top,-topInset)
                GlassClinicalWave().fill(GlassClinical.gradient)
                    .frame(height:130).frame(maxHeight:.infinity,alignment:.bottom)
                    .opacity(0.8)
                    .mask(LinearGradient(colors:[.white,.clear],startPoint:.top,endPoint:.bottom))
            }.accessibilityHidden(true)
            VStack(alignment:.leading,spacing:2) {
                GlassClinicalWordmark().foregroundStyle(GlassClinical.red)
                Text("SALUD MÓVIL").font(.caption2.weight(.bold)).tracking(3).foregroundStyle(.white)
                Spacer()
                Text("Cuidamos lo más importante, nuestra gente")
                    .font(typeSize.isAccessibilitySize ? .headline : .title3.weight(.semibold))
                    .foregroundStyle(.white).shadow(color:.black.opacity(0.8),radius:5)
                    .frame(maxWidth:205,alignment:.leading)
                    .fixedSize(horizontal:false,vertical:true)
                    .padding(.bottom,60)
            }.padding(.horizontal,24).padding(.top,8)
        }.frame(height:height)
    }
}
