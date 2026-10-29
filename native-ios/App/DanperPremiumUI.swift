import SwiftUI
import UIKit

struct DanperAppVersion:Equatable {
    let version:String
    let build:String
    init(bundle:Bundle = .main) {
        version=bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "—"
        build=bundle.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "—"
    }
    var compact:String {"Versión \(version) · Compilación \(build)"}
}

struct DanperWordmark:View {
    var width:CGFloat=145
    var color:Color = .white
    var body:some View {
        Image(uiImage:DanperBrandHeader.wordmark ?? UIImage()).renderingMode(.template)
            .resizable().scaledToFill().frame(width:width,height:width*0.34)
            .clipped().foregroundStyle(color).accessibilityLabel("Danper")
    }
}

struct DanperHomeCounts:Equatable {
    let today:Int
    let week:Int
    let month:Int
}

struct DanperFloatingTabs:View {
    @Binding var selection:Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("danper.haptics.enabled") private var haptics=true
    @State private var keyboardVisible=false
    private let titles=["Inicio","Historial","Borradores","Ajustes"]
    private let symbols=["house.fill","list.clipboard.fill","doc.text.fill","gearshape.fill"]
    private let identifiers=["home","history","drafts","settings"]
    var body:some View {
        Group {
            if !keyboardVisible {
                HStack(spacing:2) {
                    ForEach(0..<4,id:\.self) { index in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration:0.18)) {selection=index}
                        } label: {
                            VStack(spacing:5) {
                                Image(systemName:symbols[index]).font(.system(size:21,weight:.semibold))
                                    .symbolVariant(selection==index ? .fill : .none)
                                Text(titles[index]).font(.caption2.weight(selection==index ? .semibold : .medium))
                                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                    .lineLimit(1).minimumScaleFactor(0.65)
                            }
                            .foregroundStyle(selection==index ? DanperStyle.red : Color.secondary)
                            .frame(maxWidth:.infinity,minHeight:54)
                            .padding(.vertical,3)
                            .background(selection==index ? DanperStyle.red.opacity(0.11):Color.clear,in:Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(titles[index])
                        .accessibilityShowsLargeContentViewer()
                        .accessibilityAddTraits(selection==index ? .isSelected : [])
                        .accessibilityIdentifier("premium-tab-"+identifiers[index])
                    }
                }
                .padding(6)
                .background {
                    if reduceTransparency {Capsule().fill(DanperStyle.surface)}
                    else {Capsule().fill(.ultraThinMaterial)}
                }
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08),lineWidth:0.5))
                .shadow(color:.black.opacity(0.18),radius:16,y:7)
                .padding(.horizontal,18).padding(.top,9).padding(.bottom,8)
                .accessibilityElement(children:.contain)
                .accessibilityIdentifier("danper-floating-tabs")
            }
        }
        .sensoryFeedback(.selection,trigger:selection) {_,_ in haptics}
        .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillShowNotification)) {_ in keyboardVisible=true}
        .onReceive(NotificationCenter.default.publisher(for:UIResponder.keyboardWillHideNotification)) {_ in keyboardVisible=false}
    }
}

/// Optional local display name, independent of workers and clinical identity.
struct DanperHomeWelcome:View {
    @AppStorage("danper.displayName") private var displayName=""
    var isDemo=false
    var clock=DanperGreetingClock.device
    @Environment(\.scenePhase) private var scenePhase
    @State private var greetingDate=Date()
    @State private var clockRevision=0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body:some View {
        HStack(spacing:16) {
            Image("ClinicalAvatar").resizable().scaledToFit()
                .frame(width:dynamicTypeSize.isAccessibilitySize ? 48:68,height:dynamicTypeSize.isAccessibilitySize ? 48:68)
                .clipShape(Circle()).padding(3)
                .overlay(Circle().strokeBorder(DanperStyle.red.opacity(0.38),lineWidth:1))
                .shadow(color:DanperStyle.red.opacity(0.18),radius:12)
                .accessibilityLabel("Ilustración de enfermero")
                .accessibilityIdentifier("glass-home-avatar")
            VStack(alignment:.leading,spacing:6) {
                Text(DanperGreeting.text(name:displayName,at:greetingDate)).font(.title2.weight(.bold))
                    .accessibilityIdentifier("glass-home-greeting-text")
                    .fixedSize(horizontal:false,vertical:true)
                Text("Departamento de Salud").font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
                if isDemo {
                    Label("DEMO · Datos ficticios",systemImage:"testtube.2")
                        .font(.caption2).foregroundStyle(.secondary)
                        .accessibilityIdentifier("premium-demo-banner")
                } else {
                    Label("Fuente clínica protegida",systemImage:"lock.shield")
                        .font(.caption2).foregroundStyle(.secondary)
                        .accessibilityIdentifier("premium-protected-source")
                }
            }
            Spacer(minLength:0)
        }.padding(16).frame(maxWidth:.infinity,alignment:.leading)
            .danperGlassSurface(cornerRadius:22)
            .accessibilityElement(children:.contain)
            .accessibilityIdentifier("glass-home-greeting")
            .task(id:"\(scenePhase)-\(clockRevision)") {
                guard scenePhase == .active else {return}
                while !Task.isCancelled {
                    greetingDate=clock.now()
                    let delay=DanperGreeting.nextBoundary(after:greetingDate).timeIntervalSince(greetingDate)
                    do {try await Task.sleep(for:.seconds(max(0.01,delay)))}
                    catch {return}
                }
            }
            .onReceive(NotificationCenter.default.publisher(for:UIApplication.significantTimeChangeNotification)) {_ in clockRevision += 1}
            .onReceive(NotificationCenter.default.publisher(for:NSNotification.Name.NSSystemTimeZoneDidChange)) {_ in clockRevision += 1}
    }
}

private struct DanperAccentWave:Shape {
    func path(in rect:CGRect)->Path {
        var p=Path()
        p.move(to:CGPoint(x:rect.width*0.52,y:rect.height))
        p.addCurve(to:CGPoint(x:rect.width,y:0),control1:CGPoint(x:rect.width*0.70,y:rect.height*0.8),control2:CGPoint(x:rect.width*0.75,y:0))
        p.addLine(to:CGPoint(x:rect.width,y:rect.height));p.closeSubpath();return p
    }
}
struct DanperNewAttentionCard:View {
    let action:()->Void
    var identifier="clinical-home-new-attention"
    var body:some View {
        Button(action:action) {
            HStack(spacing:12) {
                VStack(alignment:.leading,spacing:7) {
                    Text("ACCESO RÁPIDO").font(.caption2.weight(.bold)).tracking(1.6)
                    Text("Nueva atención").font(.system(.title,weight:.bold))
                        .fixedSize(horizontal:false,vertical:true)
                    Text("Registra con menos pasos").font(.caption).opacity(0.85)
                }
                Spacer(minLength:0)
                Image(systemName:"doc.badge.plus").font(.system(size:29,weight:.medium))
                    .frame(width:62,height:68).danperGlassSurface(cornerRadius:19)
            }.foregroundStyle(.white).padding(18)
                .frame(maxWidth:.infinity,minHeight:118,alignment:.leading)
                .background(LinearGradient(colors:[DanperStyle.red.opacity(0.65),DanperStyle.deepRed.opacity(0.15)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:25))
                .danperGlassSurface(cornerRadius:25)
                .overlay(DanperAccentWave().fill(.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius:25)))
                .contentShape(RoundedRectangle(cornerRadius:25))
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
    }
}

struct DanperHomeMetricRow:View {
    let counts:DanperHomeCounts?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body:some View {
        let layout=dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing:9)):AnyLayout(HStackLayout(spacing:9))
        layout {
            metric("Hoy",counts?.today,"calendar",id:"today")
            metric("Esta semana",counts?.week,"chart.bar.fill",id:"week")
            metric("Este mes",counts?.month,"person.3.fill",id:"month")
        }
    }
    private func metric(_ title:String,_ value:Int?,_ symbol:String,id:String)->some View {
        VStack(alignment:.leading,spacing:8) {
            Image(systemName:symbol).font(.system(size:19,weight:.semibold))
                .foregroundStyle(DanperStyle.red).accessibilityHidden(true)
            Text(value.map{String($0)} ?? "—").font(.title2.weight(.bold))
                .monospacedDigit().minimumScaleFactor(0.65).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal:false,vertical:true)
        }.padding(13).frame(maxWidth:.infinity,minHeight:101,alignment:.topLeading)
            .danperGlassSurface(cornerRadius:19)
            .overlay(RoundedRectangle(cornerRadius:19).strokeBorder(Color.primary.opacity(0.05)))
            .accessibilityElement(children:.ignore)
            .accessibilityLabel(title).accessibilityValue(value.map{String($0)} ?? "No disponible")
            .accessibilityIdentifier("premium-metric-"+id)
    }
}

struct DanperToolCard:View {
    let title:String
    let subtitle:String
    let symbol:String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body:some View {
        HStack(alignment:.top,spacing:8) {
            Image(systemName:symbol).font(.system(size:22,weight:.semibold))
                .foregroundStyle(DanperStyle.red).frame(width:32,height:40)
                .background(DanperStyle.red.opacity(0.10),in:RoundedRectangle(cornerRadius:13))
            VStack(alignment:.leading,spacing:6) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil:1).minimumScaleFactor(0.8)
                    .fixedSize(horizontal:false,vertical:true)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
            Spacer(minLength:0)
            if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName:"chevron.right").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
            }
        }.padding(12).frame(maxWidth:.infinity,minHeight:92,alignment:.topLeading)
            .danperGlassSurface(cornerRadius:21)
            .overlay(RoundedRectangle(cornerRadius:21).strokeBorder(Color.primary.opacity(0.05)))
            .contentShape(RoundedRectangle(cornerRadius:21))
    }
}

struct DanperVersionPanel:View {
    private let info=DanperAppVersion()
    var body:some View {
        DanperPanel {
            Text("DANPER Salud Móvil").font(.headline)
            LabeledContent("Versión",value:info.version)
            LabeledContent("Compilación",value:info.build)
        }.accessibilityIdentifier("premium-app-version")
    }
}

/// Presentation scaffolding only. No invented clinical aggregates or trends.
struct DanperStatisticsView:View {
    @State private var period="Año"
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                HStack(alignment:.top,spacing:12) {
                    VStack(alignment:.leading,spacing:7) {
                        Text("DEPARTAMENTO DE SALUD").font(.caption2.weight(.bold)).tracking(1.5).foregroundStyle(DanperStyle.red)
                        Text("Estadísticas").font(.largeTitle.bold())
                        Text("Indicadores de atención y salud ocupacional")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength:0)
                    Image(systemName:"chart.bar.fill").font(.title).foregroundStyle(DanperStyle.red)
                        .padding(15).background(DanperStyle.red.opacity(0.10),in:RoundedRectangle(cornerRadius:18))
                }
                VStack(alignment:.leading,spacing:15) {
                    HStack {
                        Text(period=="Año" ? "ATENCIONES DEL AÑO" : "ATENCIONES DEL MES")
                            .font(.caption.weight(.bold)).tracking(1)
                        Spacer()
                        Picker("Período",selection:$period) {
                            Text("Mes").tag("Mes");Text("Año").tag("Año")
                        }.pickerStyle(.segmented).frame(maxWidth:150)
                    }
                    Text("—").font(.system(size:42,weight:.bold))
                    Text("El resumen estará disponible próximamente.").font(.subheadline)
                }.foregroundStyle(.white).padding(20).frame(maxWidth:.infinity,alignment:.leading)
                    .danperGlassSurface(cornerRadius:24)
                section("Top 5 sistemas afectados",symbol:"heart.text.clipboard")
                section("Top 5 áreas más atendidas",symbol:"person.3.sequence")
                section("Accidentes de trabajo",symbol:"chart.bar.xaxis")
                Text("Puedes consultar tus atenciones en Historial.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal,4)
            }.padding(16)
        }.background(DanperBackdrop())
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("premium-statistics")
    }
    private func section(_ title:String,symbol:String)->some View {
        DanperPanel(title) {
            DanperEmptyState(title:"Resumen aún no disponible",symbol:symbol)
        }
    }
}

struct DanperExportsView:View {
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:15) {
                Text("Indicadores y exportaciones").font(.largeTitle.bold())
                Text("Elige el reporte que necesitas compartir.").font(.subheadline).foregroundStyle(.secondary)
                DanperPanel {
                    DanperToolLink(title:"Indicador ambulatorio · Excel",symbol:"doc.richtext") {N2VerifiedIndicatorExportView()}
                    DanperToolLink(title:"Kardex de enfermería",symbol:"tablecells") {N2VerifiedNursingExportView()}
                    DanperToolLink(title:"Vigilancia ocupacional · Excel",symbol:"figure.walk.motion") {N2OccupationalVigilanceExportView()}
                }
            }.padding(16)
        }.background(DanperBackdrop()).navigationTitle("Indicadores").navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG && targetEnvironment(simulator)
/// Simulator-only fixture entry. The root fixes its vault to .demo; it cannot
/// authenticate, create or read a protected clinical source.
struct DanperDemoInspection:View {
    var body:some View {NativeRootView()}
}
#endif

struct DanperEmptyState:View {
    let title:String
    let symbol:String
    var detail:String=""
    var body:some View {
        HStack(spacing:14) {
            Image(systemName:symbol).font(.title2).foregroundStyle(DanperStyle.red)
                .frame(width:42,height:50)
            VStack(alignment:.leading,spacing:5) {
                Text(title).font(.subheadline).foregroundStyle(.secondary)
                if !detail.isEmpty {Text(detail).font(.caption).foregroundStyle(.secondary)}
            }
            Spacer(minLength:0)
        }.frame(minHeight:51)
    }
}
struct DanperLoadingState:View {
    let title:String
    var body:some View {
        HStack(spacing:10) {ProgressView();Text(title).font(.footnote).foregroundStyle(.secondary)}
            .frame(maxWidth:.infinity,alignment:.leading)
            .accessibilityElement(children:.combine)
    }
}
struct DanperErrorState:View {
    let message:String
    var retry:(()->Void)?=nil
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Label(message,systemImage:"exclamationmark.circle")
                .font(.footnote).foregroundStyle(.orange)
                .fixedSize(horizontal:false,vertical:true)
            if let retry {Button("Reintentar",action:retry).font(.footnote.weight(.semibold))}
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
            .background(Color.orange.opacity(0.08),in:RoundedRectangle(cornerRadius:14))
    }
}

/// Stored only in local UI preferences; never used as the clinical responsible person.
struct DanperDisplayNamePreference:View {
    @AppStorage("danper.displayName") private var displayName=""
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            TextField("Nombre visible (opcional)",text:$displayName)
                .textContentType(.nickname).textInputAutocapitalization(.words)
                .submitLabel(.done).accessibilityIdentifier("glass-display-name")
            Text("Solo personaliza el saludo en este dispositivo. No cambia al responsable clínico ni los registros de trabajadores. Déjalo vacío para mostrar el saludo según la hora, sin nombre.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
