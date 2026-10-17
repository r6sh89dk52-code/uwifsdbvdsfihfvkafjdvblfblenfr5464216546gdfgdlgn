import Foundation
import SwiftUI
import DanperCore

/// Only audited source records; never mutates stock or patient visits.
struct N2ReconciliationView:View {
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
    @State private var status="Verificando libro de conciliación N2…"
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
        Form {
            Section("Conciliación auditable · 432 productos") {
                Label("Fuente N2 cifrada independiente",systemImage:"lock.shield.fill")
                Text("Todo ajuste se añade como evento con fecha y justificación. Para corregir, anula el evento: la historia original nunca se borra.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(status).font(.footnote)
                    .foregroundStyle(failed ? Color.red : Color.secondary)
            }
            Section("Tipo y sede") {
                Picker("Sede",selection:$site) {
                    Text("Fundo La Venturosa").tag("LA VENTUROSA")
                    Text("Planta La Venturosa").tag("PLVENTUROSA")
                }
                Picker("Evento",selection:$kind) {
                    Text("Stock inicial").tag("opening")
                    Text("Ingreso extraordinario").tag("receipt")
                    Text("Conteo final").tag("count")
                    Text("Revisar / cerrar período").tag("review")
                    Text("Anular evento previo").tag("void")
                }
            }
            Section("Datos comprobables") {
                LabeledContent("Fecha del evento",value:DanperDatePresentation.display(localDay(date)))
                DatePicker("Cambiar fecha",selection:$date,displayedComponents:.date)
                if kind=="review" {
                    LabeledContent("Fin del período",value:DanperDatePresentation.display(localDay(periodEnd)))
                    DatePicker("Cambiar fin",selection:$periodEnd,
                               displayedComponents:.date)
                    Text("El cierre confirma revisión de ingresos, pero no inventa cantidades faltantes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }else if kind=="void" {
                    Picker("Registro que se anula",selection:$selectedVoid) {
                        Text("Selecciona un evento").tag("")
                        ForEach(options){r in
                            Text(r.kind+" · "+DanperDatePresentation.display(r.date)+" · "+r.code+" ("+String(r.quantity)+")")
                                .tag(r.id)
                        }
                    }
                }else{
                    Button {
                        pickProduct=true
                    }label:{
                        Label(code.isEmpty ? "Seleccionar material oficial" : code,
                              systemImage:"magnifyingglass")
                    }
                    TextField("Cantidad física (unidad del catálogo)",text:$quantity)
                        .keyboardType(.numberPad)
                    if kind=="receipt" {
                        TextField("Documento o guía",text:$document)
                        Toggle("Tiene vencimiento",isOn:$hasExpires)
                        if hasExpires {
                            LabeledContent("Vencimiento",value:DanperDatePresentation.display(localDay(expires)))
                            DatePicker("Cambiar vencimiento",selection:$expires,
                                       displayedComponents:.date)
                        }
                    }
                }
                TextField("Justificación obligatoria",text:$reason,
                          axis:.vertical).lineLimit(2...5)
            }
            Section("Guardar registro") {
                Button {
                    Task {await save()}
                }label:{
                    Label(busy ? "Verificando…" : "Confirmar evento cifrado",
                          systemImage:"checkmark.shield.fill")
                }.disabled(!enabled)
                Text("El registro queda en una sola generación cifrada. Este formulario no modifica las atenciones ni las salidas del Kardex.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Historial de eventos") {
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
        }
        .navigationTitle("Conciliación de inventario")
        .danperFormChrome()
        .sheet(isPresented:$pickProduct) {
            NavigationStack {
                List {
                    if let context {
                        ForEach(context.products.clinicalMatches(search).prefix(150)) { p in
                            Button {
                                code=p.code
                                pickProduct=false
                                search=""
                            } label: {
                                VStack(alignment:.leading) {
                                    Text(p.name).foregroundStyle(.primary)
                                    Text(p.code+" · "+p.unit)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .searchable(text:$search,prompt:"Código o nombre")
                .navigationTitle("432 materiales")
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("Cerrar"){pickProduct=false}
                    }
                }
            }
        }
        .task {await load()}
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
