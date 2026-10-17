import Foundation
import SwiftUI
import DanperCore

/// Only audited source records; never mutates stock or patient visits.
struct N2ReconciliationView:View {
    private var layoutOnly=false
    init() {}
    #if DEBUG
    init(layoutContext:N2FormContext,operation:String?=nil) {
        layoutOnly=true
        _context=State(initialValue:layoutContext)
        _status=State(initialValue:"Registro de conciliación disponible")
    }
    #endif
    @State private var context:N2FormContext?
    @State private var events=[N2ReconciliationEventRow]()
    @State private var site="LA VENTUROSA"
    @State private var kind="opening"
    @State private var date=Date()
    @State private var periodEnd=Date()
    @State private var expires=Date()
    @State private var hasExpires=false
    @State private var quantity="0"
    @State private var code=""
    @State private var document=""
    @State private var reason=""
    @State private var selectedVoid=""
    @State private var search=""
    @State private var pickProduct=false
    @State private var busy=false
    @State private var status="Cargando conciliación…"
    @State private var failed=false

    private func localDay(_ d:Date)->String {
        let f=DateFormatter()
        f.dateFormat="yyyy-MM-dd"
        f.timeZone=TimeZone(identifier:"America/Lima")
        return f.string(from:d)
    }
    private var options:[N2ReconciliationEventRow] {
        events.filter{$0.subdivision==site && !$0.voided && $0.kind != "void"}
    }
    private var enabled:Bool {
        context != nil && !busy && reason.trimmingCharacters(
            in:.whitespacesAndNewlines).count>=8 &&
        (kind=="void" ? !selectedVoid.isEmpty :
         (kind=="review" ? localDay(periodEnd)>=localDay(date) :
          (context?.products.clinical.contains{$0.code==code}==true &&
           Int(quantity) != nil && (kind != "receipt" ||
                document.trimmingCharacters(in:.whitespaces).count>=3))))
    }
    var body:some View {
        DanperScrollView {
          VStack(alignment:.leading,spacing:16) {
            DanperPanel("Conciliación auditable · 432 productos") {
                Label("Registro protegido del inventario",systemImage:"lock.shield.fill")
                Text("Todo ajuste se añade como evento con fecha y justificación. Para corregir, anula el evento: la historia original nunca se borra.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
            DanperPanel("Tipo y sede") {
                DanperChoiceField(title:"Sede",selection:$site,options:["LA VENTUROSA","PLVENTUROSA"],labels:["LA VENTUROSA":"Fundo La Venturosa","PLVENTUROSA":"Planta La Venturosa"])
                DanperChoiceField(title:"Evento",selection:$kind,options:["opening","receipt","count","review","void"],labels:["opening":"Stock inicial","receipt":"Ingreso extraordinario","count":"Conteo final","review":"Revisar / cerrar período","void":"Anular evento previo"])

            }
            DanperPanel("Datos comprobables") {
                DanperDateField(title:"Fecha del evento",selection:$date)
                if kind=="review" {
                    DanperDateField(title:"Fin del período",selection:$periodEnd)
                    Text("El cierre confirma revisión de ingresos, pero no inventa cantidades faltantes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }else if kind=="void" {
                    DanperChoiceField(title:"Registro que se anula",selection:$selectedVoid,options:options.map(\.id),
                        labels:Dictionary(uniqueKeysWithValues:options.map{($0.id,$0.kind+" · "+DanperDatePresentation.display($0.date)+" · "+$0.code+" ("+String($0.quantity)+")")}))
                }else{
                    Button {
                        pickProduct.toggle()
                    }label:{
                        Label(code.isEmpty ? "Seleccionar material oficial" : code,
                              systemImage:"magnifyingglass")
                    }
                    if pickProduct,let context {
                        DanperInlineSearch(title:"Buscar material oficial",placeholder:"Nombre o código",
                            options:context.products.clinical.map{DanperSearchOption(id:$0.code,title:$0.name,detail:$0.code+" · "+$0.unit)},
                            onSelect:{id in code=id;pickProduct=false},onClose:{pickProduct=false})
                    }
                    DanperField(title:"Cantidad física (unidad del catálogo)") {
                    TextField("Cantidad física (unidad del catálogo)",text:$quantity)
                        .keyboardType(.numberPad)
                }
                    if kind=="receipt" {
                        DanperField(title:"Documento o guía") {
                    TextField("Documento o guía",text:$document)
                }
                        DanperCheckRow(selected:$hasExpires) {Text("Tiene vencimiento")}
                        if hasExpires {
                            DanperDateField(title:"Vencimiento",selection:$expires)
                        }
                    }
                }
                DanperField(title:"Justificación obligatoria") {
                    TextField("Justificación obligatoria",text:$reason,
                          axis:.vertical).lineLimit(2...5)
                }
            }
            DanperPanel("Guardar registro") {
                Button {
                    Task {await save()}
                }label:{
                    Label(busy ? "Verificando…" : "Guardar evento",
                          systemImage:"checkmark.shield.fill")
                }.buttonStyle(DanperPrimaryButton()).disabled(!enabled)
                Text("Estos eventos respaldan el reporte Excel. Para registrar existencias físicas o ingresos, usa Inventario y lotes.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            DanperPanel("Historial de eventos") {
                Text("\(events.count) eventos guardados (incluye anulaciones)")
                    .font(.footnote).foregroundStyle(.secondary)
                ForEach(events.prefix(20)) { event in
                    VStack(alignment:.leading,spacing:3) {
                        Text(event.kind+" · "+DanperDatePresentation.display(event.date)+" · "+event.code)
                        Text("Cantidad: \(event.quantity) · " +
                             event.subdivision +
                             (event.voided ? " · ANULADO" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
          }.padding(16)
        }
        .navigationTitle("Conciliación").navigationBarTitleDisplayMode(.inline)
        .danperFormChrome()
        .task {if !layoutOnly {await load()}}
    }
    @MainActor
    private func load() async {
        do{
            context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            events=try await N2SyntheticTrialIOSVault.shared.reconciliationEvents()
            status="Bóveda verificada. Eventos anteriores: \(events.count)."
        }catch{
            context=nil
            failed=true
            status="No hay fuente N2 verificada. La conciliación está bloqueada."
        }
    }
    @MainActor
    private func save() async {
        guard enabled,let context else{return}
        busy=true
        failed=false
        defer{busy=false}
        let count=kind=="review" || kind=="void" ? 0 : (Int(quantity) ?? -1)
        let payload:[String:Any]=[
            "id":UUID().uuidString,"kind":kind,"subdivision":site,
            "code":kind=="review" || kind=="void" ? "" : code,
            "date":localDay(date),
            "at":Int64(Date().timeIntervalSince1970*1000),
            "quantity":count,
            "reason":reason.trimmingCharacters(in:.whitespacesAndNewlines),
            "document":kind=="receipt" ? document : "",
            "expires":kind=="receipt" && hasExpires ? localDay(expires) : "",
            "periodEnd":kind=="review" ? localDay(periodEnd) : "",
            "voidOf":kind=="void" ? selectedVoid : ""
        ]
        do {
            let data=try JSONSerialization.data(withJSONObject:payload)
            let next=try await N2SyntheticTrialIOSVault.shared
                .appendReconciliationEvent(data,expectedRevision:context.revision)
            self.context=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
            events=try await N2SyntheticTrialIOSVault.shared.reconciliationEvents()
            reason="";document="";quantity="0";selectedVoid=""
            status="Evento confirmado en generación cifrada \(next.revision)."
        }catch{
            failed=true
            status="Evento rechazado: revisa fecha, stock, código, duplicados y estado del cierre."
        }
    }
}

