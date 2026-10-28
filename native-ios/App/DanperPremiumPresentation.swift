import SwiftUI
import UIKit
import Combine

/// One keyboard signal shared by navigation and every clinical editor.
final class DanperKeyboardState:ObservableObject {
    @Published private(set) var visible=false
    private var subscriptions=Set<AnyCancellable>()
    init() {
        NotificationCenter.default.publisher(for:UIResponder.keyboardWillChangeFrameNotification)
            .receive(on:RunLoop.main).sink {[weak self] note in
                guard let frame=note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else{return}
                let shown=frame.height>0 && frame.minY<UIScreen.main.bounds.height
                if self?.visible != shown {self?.visible=shown}
            }.store(in:&subscriptions)
        NotificationCenter.default.publisher(for:UIResponder.keyboardWillHideNotification)
            .receive(on:RunLoop.main).sink {[weak self] _ in self?.visible=false}
            .store(in:&subscriptions)
    }
}

/// The capsule floats visually, but owns a real layout region. UIKit-backed
/// TabView/NavigationStack children cannot draw functional controls underneath it.
private struct DanperFloatingNavigation:ViewModifier {
    @Binding var selection:Int
    @StateObject private var keyboard=DanperKeyboardState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content:Content)->some View {
        VStack(spacing:0) {
            content.frame(maxWidth:.infinity,maxHeight:.infinity)
            if !keyboard.visible {
                DanperFloatingTabs(selection:$selection)
                    .transition(.move(edge:.bottom).combined(with:.opacity))
            }
        }
        .background(DanperBackdrop())
        .environment(\.colorScheme,.dark)
        .animation(reduceMotion ? nil : DanperStyle.animation,value:keyboard.visible)
    }
}
extension View {
    func danperFloatingNavigation(selection:Binding<Int>)->some View {
        modifier(DanperFloatingNavigation(selection:selection))
    }
    func danperGlassSurface(cornerRadius:CGFloat=20)->some View {
        modifier(DanperGlassSurface(cornerRadius:cornerRadius))
    }
}

private struct DanperGlassSurface:ViewModifier {
    let cornerRadius:CGFloat
    @Environment(\.accessibilityReduceTransparency) private var opaque
    func body(content:Content)->some View {
        content.background {
            let shape=RoundedRectangle(cornerRadius:cornerRadius)
            if opaque {shape.fill(DanperStyle.surface)}
            else {
                shape.fill(.ultraThinMaterial)
                    .overlay(shape.fill(.black.opacity(0.42)))
                    .overlay(shape.fill(LinearGradient(colors:[.white.opacity(0.055),.clear],startPoint:.topLeading,endPoint:.bottomTrailing)))
            }
        }
        .overlay(RoundedRectangle(cornerRadius:cornerRadius).strokeBorder(.white.opacity(0.10),lineWidth:0.5).allowsHitTesting(false))
        .shadow(color:.black.opacity(0.25),radius:16,y:7)
    }
}

struct DanperAttentionRoute:Identifiable {
    let id=UUID()
    var draftID:String?=nil
}

/// The exact same modal/navigation/keyboard chrome for a new or resumed record.
struct DanperAttentionEditor:View {
    var requestedDraftID:String?=nil
    var initialWorkerDNI:String?=nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.n2WorkspaceVault) private var vault
    var body:some View {
        NavigationStack {
            N2NativeClinicalFormView(requestedDraftID:requestedDraftID,initialWorkerDNI:initialWorkerDNI)
                .safeAreaInset(edge:.top,spacing:0) {
                    if !vault.isClinical {
                        Text("DEMO · Datos ficticios").font(.caption2.weight(.semibold))
                            .foregroundStyle(DanperStyle.red).padding(.vertical,5)
                            .frame(maxWidth:.infinity).background(DanperStyle.surface)
                    }
                }
                .toolbar {
                    ToolbarItem(placement:.cancellationAction) {
                        Button("Cerrar") {dismiss()}
                            .accessibilityIdentifier("premium-close-attention")
                    }
                }
                .danperFormChrome()
        }
        .environment(\.colorScheme,.dark)
        .tint(DanperStyle.red)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.ultraThinMaterial)
        .onChange(of:scenePhase) {_,phase in
            if phase == .background {dismiss()}
        }
    }
}

struct DanperAttentionLauncher:View {
    let title:String
    let symbol:String
    @State private var show=false
    var body:some View {
        Button {show=true} label:{Label(title,systemImage:symbol)}
            .sheet(isPresented:$show) {DanperAttentionEditor()}
    }
}

private struct DanperAuthenticatedSessionKey:EnvironmentKey {static let defaultValue=false}
extension EnvironmentValues {
    var danperAuthenticatedSession:Bool {
        get{self[DanperAuthenticatedSessionKey.self]}
        set{self[DanperAuthenticatedSessionKey.self]=newValue}
    }
}

/// Layered charcoal and restrained reflected light, visible through Material.
/// No animation, so Reduce Motion is respected without a separate branch.
struct DanperBackdrop:View {
    @Environment(\.accessibilityReduceTransparency) private var opaque
    var body:some View {
        ZStack {
            DanperStyle.canvas
            if !opaque {
                RadialGradient(colors:[DanperStyle.red.opacity(0.12),.clear],center:.topTrailing,startRadius:0,endRadius:380)
                LinearGradient(colors:[.white.opacity(0.025),.clear,.black.opacity(0.4)],startPoint:.topLeading,endPoint:.bottomTrailing)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct DanperGlassAction:ButtonStyle {
    var accented=false
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.subheadline.weight(.semibold)).foregroundStyle(.white)
            .padding(.horizontal,18).padding(.vertical,17).frame(maxWidth:.infinity,minHeight:56)
            .danperGlassSurface(cornerRadius:32)
            .background {
                if accented {Capsule().fill(LinearGradient(colors:[DanperStyle.red.opacity(0.65),.clear],startPoint:.leading,endPoint:.trailing))}
            }
            .overlay(Capsule().strokeBorder(accented ? DanperStyle.red.opacity(0.48):.white.opacity(0.16),lineWidth:0.7))
            .opacity(configuration.isPressed ? 0.75:1)
    }
}
