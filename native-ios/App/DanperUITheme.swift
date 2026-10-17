import SwiftUI
import UIKit

/// Reusable visual language for the entire native preview. Respect Dynamic Type,
/// Dark/Light Mode, Reduce Motion and the iPhone's safe areas.
enum DanperStyle {
    static let red=Color(red:0.89,green:0.094,blue:0.176)
    static let deepRed=Color(red:0.57,green:0.035,blue:0.12)
    static let canvas=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.09,green:0.09,blue:0.105,alpha:1) : UIColor(red:0.965,green:0.965,blue:0.974,alpha:1) })
    static let surface=Color(uiColor:UIColor { $0.userInterfaceStyle == .dark ? UIColor(red:0.145,green:0.145,blue:0.16,alpha:1) : .white })
    static let animation=Animation.easeInOut(duration:0.22)
    static let gradient=LinearGradient(colors:[red,deepRed],
                                      startPoint:.topLeading,endPoint:.bottomTrailing)
}

struct DanperPrimaryButton:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .font(.system(.subheadline,design:.rounded,weight:.bold))
            .foregroundStyle(.white)
            .padding(.horizontal,20).padding(.vertical,14)
            .frame(maxWidth:.infinity,minHeight:50)
            .background(DanperStyle.gradient,in:RoundedRectangle(cornerRadius:15))
            .shadow(color:DanperStyle.red.opacity(configuration.isPressed ? 0.05 : 0.16),
                    radius:configuration.isPressed ? 2 : 9,y:configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.17),
                       value:configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius:15))
    }
}
struct DanperSecondaryButton:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration:Configuration)->some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DanperStyle.red)
            .padding(.horizontal,16).padding(.vertical,13)
            .frame(minHeight:48)
            .background(DanperStyle.red.opacity(configuration.isPressed ? 0.16 : 0.08),
                        in:RoundedRectangle(cornerRadius:14))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration:0.17),
                       value:configuration.isPressed)
    }
}
struct DanperFormChrome:ViewModifier {
    func body(content:Content)->some View {
        content
            .scrollContentBackground(.hidden)
            .background(DanperStyle.canvas)
            .tint(DanperStyle.red)
            .environment(\.locale,Locale(identifier:"es_PE"))
    }
}
extension View {
    func danperFormChrome()->some View {modifier(DanperFormChrome())}
}
struct DanperStepProgress:View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let step:Int
    let titles:[String]
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment:.leading,spacing:8) {
                    Text("PASO \(step+1) DE \(titles.count)").font(.caption.weight(.bold)).foregroundStyle(DanperStyle.red)
                    Text(titles[step]).font(.headline).fixedSize(horizontal:false,vertical:true)
                }.frame(maxWidth:.infinity,alignment:.leading)
            } else {
            HStack(spacing:10) {
                Image(systemName:["person.crop.rectangle","stethoscope",
                                  "cross.vial.fill","checkmark.shield.fill"][
                                  min(max(step,0),3)])
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DanperStyle.red)
                    .frame(width:43,height:43)
                    .background(DanperStyle.red.opacity(0.10),
                                in:RoundedRectangle(cornerRadius:13))
                VStack(alignment:.leading,spacing:3) {
                    Text("PASO \(step+1) DE \(titles.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(DanperStyle.red)
                    Text(titles[step])
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength:2)
                Text("\(Int(Double(step+1)/Double(titles.count)*100)) %")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            }
            GeometryReader { geo in
                ZStack(alignment:.leading) {
                    Capsule().fill(DanperStyle.red.opacity(0.12))
                    Capsule().fill(DanperStyle.gradient)
                        .frame(width: max(CGFloat(5), geo.size.width * CGFloat(step + 1) / CGFloat(titles.count)))
                }
            }
            .frame(height:6)
            .accessibilityLabel("Progreso \(step+1) de \(titles.count)")
        }
        .padding(15)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:18))
    }
}
struct DanperStatusBanner:View {
    let symbol:String
    let title:String
    let detail:String
    var body:some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:symbol).font(.headline)
                .foregroundStyle(DanperStyle.red)
                .frame(width:38,height:38)
                .background(DanperStyle.red.opacity(0.10),
                            in:RoundedRectangle(cornerRadius:12))
            VStack(alignment:.leading,spacing:5) {
                Text(title).font(.subheadline.weight(.bold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal:false,vertical:true)
            }
        }
        .padding(14).frame(maxWidth:.infinity,alignment:.leading)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:17))
    }
}


/// Build 222 panels: separate content surfaces, outlined fields and neutral text.
/// Action color belongs to the primary CTA and selected marks, not entire rows.
struct DanperPanel<Content:View>:View {
    private let title:String?
    private let content:Content
    init(_ title:String?=nil,@ViewBuilder content:()->Content) {
        self.title=title;self.content=content()
    }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            if let title {Text(title).font(.headline).foregroundStyle(.primary)}
            content
        }
        .frame(maxWidth:.infinity,alignment:.leading)
        .padding(16)
        .background(DanperStyle.surface,in:RoundedRectangle(cornerRadius:20))
        .overlay(RoundedRectangle(cornerRadius:20).strokeBorder(Color.secondary.opacity(0.16)).allowsHitTesting(false))
    }
}
struct DanperField<Content:View>:View {
    let title:String
    @ViewBuilder let content:Content
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            content.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
                .overlay(RoundedRectangle(cornerRadius:13).strokeBorder(Color.secondary.opacity(0.15)).allowsHitTesting(false))
        }
    }
}
/// Anchored system menu, matching build222's native HTML select presentation.
struct DanperChoiceField:View {
    let title:String
    @Binding var selection:String
    let options:[String]
    var labels:[String:String]=[:]
    private func label(_ value:String)->String {labels[value] ?? value.capitalized(with:Locale(identifier:"es_PE"))}
    var body:some View {
        Menu {
            Picker(title,selection:$selection) {
                if !options.contains("") {Text("Seleccionar").tag("")}
                ForEach(options,id:\.self) {value in Text(label(value)).tag(value)}
            }
        } label: {
            DanperField(title:title) {
                HStack(spacing:12) {
                    Text(selection.isEmpty ? (labels[""] ?? "Seleccionar") : label(selection))
                        .foregroundStyle(selection.isEmpty ? .secondary : .primary)
                        .multilineTextAlignment(.leading).fixedSize(horizontal:false,vertical:true)
                    Spacer(minLength:0)
                    Image(systemName:"chevron.up.chevron.down").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }.frame(minHeight:24)
            }
        }.buttonStyle(.plain).accessibilityIdentifier("choice-"+title)
    }
}

private struct DanperRevealKey:EnvironmentKey {static let defaultValue:(String)->Void={_ in}}
extension EnvironmentValues {
    var danperReveal:(String)->Void {
        get{self[DanperRevealKey.self]}
        set{self[DanperRevealKey.self]=newValue}
    }
}
/// Scrolls suggestions above the keyboard, rather than revealing only the input.
struct DanperScrollView<Content:View>:View {
    @ViewBuilder let content:Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body:some View {
        ScrollViewReader {proxy in
            ScrollView {content}
                .environment(\.danperReveal,{id in
                    withAnimation(reduceMotion ? nil : DanperStyle.animation){proxy.scrollTo(id,anchor:.top)}
                })
        }
    }
}

/// Inline autocomplete used by clinical, inventory and reconciliation catalogs.
struct DanperSearchOption:Identifiable {
    let id:String
    let title:String
    let detail:String
}
struct DanperInlineSearch:View {
    let title:String
    let placeholder:String
    let options:[DanperSearchOption]
    let onSelect:(String)->Void
    var onClose:(()->Void)?=nil
    @State private var query=""
    @FocusState private var focused:Bool
    @State private var revealTask:Task<Void,Never>?
    @State private var searchAnchor="inline-"+UUID().uuidString
    @Environment(\.danperReveal) private var reveal
    private func revealResults() {
        revealTask?.cancel()
        revealTask=Task { @MainActor in
            do {try await Task.sleep(for:.milliseconds(220))} catch{return}
            if focused {reveal(searchAnchor)}
        }
    }
    private var matches:[DanperSearchOption] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        return options.filter {q.isEmpty || $0.title.localizedStandardContains(q) || $0.id.localizedStandardContains(q)}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Text(title).font(.subheadline.weight(.bold))
                Spacer()
                if let onClose {Button(action:onClose){Image(systemName:"xmark").padding(10)}.buttonStyle(.plain).accessibilityLabel("Cerrar búsqueda")}
            }
            DanperField(title:"Buscar por nombre o código") {
                TextField(placeholder,text:$query).focused($focused)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .accessibilityIdentifier("inline-catalog-query")
            }
            if query.trimmingCharacters(in:.whitespaces).isEmpty {
                Text("Escribe para ver sugerencias de los \(options.count) productos.").font(.caption).foregroundStyle(.secondary)
            } else {
                if matches.isEmpty {Text("No se encontraron productos.").font(.caption).foregroundStyle(.secondary)}
                ScrollView {
                    LazyVStack(spacing:8) {
                        ForEach(matches) { option in
                            Button {
                                onSelect(option.id);query="";focused=false
                            } label: {
                                VStack(alignment:.leading,spacing:5) {
                                    Text(option.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(option.detail).font(.caption).foregroundStyle(.secondary)
                                }.padding(12).frame(maxWidth:.infinity,alignment:.leading)
                                    .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:12))
                                    .contentShape(RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).accessibilityIdentifier("suggestion-"+option.id)
                        }
                    }
                }.frame(maxHeight:240)
            }
        }
        .id(searchAnchor)
        .onChange(of:query){_,_ in revealResults()}
        .onChange(of:focused){_,isFocused in if isFocused {revealResults()}}
        .onDisappear{revealTask?.cancel()}
    }
}
struct DanperCheckRow<Content:View>:View {
    @Binding var selected:Bool
    @ViewBuilder let content:Content
    var body:some View {
        Button {selected.toggle()} label: {
            HStack(alignment:.center,spacing:12) {
                Image(systemName:selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(selected ? DanperStyle.red : Color.secondary)
                content.frame(maxWidth:.infinity,alignment:.leading).foregroundStyle(.primary)
            }.padding(12).frame(minHeight:52)
                .background(selected ? DanperStyle.red.opacity(0.075) : DanperStyle.canvas,in:RoundedRectangle(cornerRadius:13))
                .overlay(RoundedRectangle(cornerRadius:13).strokeBorder(selected ? DanperStyle.red.opacity(0.35) : Color.secondary.opacity(0.15)))
                .contentShape(RoundedRectangle(cornerRadius:13))
        }.buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
struct DanperDateField:View {
    let title:String
    @Binding var selection:Date
    @State private var open=false
    private var label:String {
        let f=DateFormatter();f.timeZone=TimeZone(identifier:"America/Lima");f.dateFormat="dd/MM/yyyy"
        return f.string(from:selection)
    }
    var body:some View {
        Button {open=true} label: {
            DanperField(title:title) {
                HStack {Text(label).foregroundStyle(.primary);Spacer();Image(systemName:"calendar").foregroundStyle(.secondary)}
            }
        }.buttonStyle(.plain)
        .sheet(isPresented:$open) {
            NavigationStack {
                DatePicker(title,selection:$selection,displayedComponents:.date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {ToolbarItem(placement:.topBarTrailing){Button("Listo"){open=false}}}
                    .environment(\.locale,Locale(identifier:"es_PE"))
                    .environment(\.timeZone,TimeZone(identifier:"America/Lima")!)
            }.presentationDetents([.medium,.large])
        }
    }
}

struct DanperToolLink<Destination:View>:View {
    let title:String
    let symbol:String
    @ViewBuilder let destination:Destination
    var body:some View {
        NavigationLink {destination} label: {
            HStack(spacing:12) {
                Image(systemName:symbol).font(.title3).foregroundStyle(DanperStyle.red)
                    .frame(width:42,height:42).background(DanperStyle.red.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .frame(maxWidth:.infinity,alignment:.leading).fixedSize(horizontal:false,vertical:true)
                Image(systemName:"chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }.padding(10).frame(maxWidth:.infinity,minHeight:64)
                .background(DanperStyle.canvas,in:RoundedRectangle(cornerRadius:14))
        }.buttonStyle(.plain)
    }
}
