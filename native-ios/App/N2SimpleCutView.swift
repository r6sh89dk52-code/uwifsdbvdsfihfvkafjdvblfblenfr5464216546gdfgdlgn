import SwiftUI
import UniformTypeIdentifiers
import DanperCore

struct N2SimpleCutView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    @Environment(\.scenePhase) private var scenePhase
    @State private var context:N2SimpleInventoryContext?
    @State private var code=""
    @State private var through=Date()
    @State private var preview:N2SimpleCutPreview?
    @State private var archive:URL?
    @State private var choose=false
    @State private var password=""
    @State private var busy=false
    @State private var status=""
    private var day:String {
        let f=DateFormatter();f.timeZone=TimeZone(identifier:"America/Lima");f.dateFormat="yyyy-MM-dd"
        return f.string(from:through)
    }
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                DanperPanel("Corte del día 9 al día 8") {
                    Text("El cálculo es una consulta: nunca modifica el conteo ni crea movimientos históricos.").font(.footnote).foregroundStyle(.secondary)
                    if let context,let state=context.state {
                        DanperChoiceField(title:"Producto",selection:$code,options:state.products.map(\.code),
                            labels:Dictionary(uniqueKeysWithValues:state.products.map{($0.code,$0.name)}))
                    } else if context != nil {
                        Text("Primero confirma el conteo e inicia el inventario nuevo para consultar sus cortes.")
                            .font(.footnote).foregroundStyle(.secondary)
                        NavigationLink("Registrar inventario") {N2SimpleInventoryView()}
                    }
                    DanperDateField(title:"Consultar hasta",selection:$through)
                    Button("Consultar saldo") {Task {await calculate()}}.buttonStyle(DanperPrimaryButton()).disabled(code.isEmpty || busy)
                        .accessibilityIdentifier("simple-cut-calculate")
                }
                if let preview {result(preview)}
                DanperPanel("Evidencia anterior opcional") {
                    Text("Si el conteo comenzó después del día 9, puedes verificar el cálculo con el respaldo cifrado anterior. Sus movimientos no se importan al inventario nuevo.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(archive==nil ? "Elegir respaldo histórico":"Cambiar respaldo histórico") {choose=true}
                    if archive != nil {SecureField("Contraseña del respaldo",text:$password).textContentType(.password)}
                }
                if !status.isEmpty {Text(status).font(.footnote).foregroundStyle(.secondary)}
            }.padding(16)
        }.navigationTitle("Corte mensual").navigationBarTitleDisplayMode(.inline).danperFormChrome()
            .task {
                do {context=try await vault.simpleInventoryContext();code=context?.state?.products.first?.code ?? ""}
                catch {status=n2SimpleMessage(error)}
            }
            .fileImporter(isPresented:$choose,allowedContentTypes:[.data,.item]) {result in
                if case .success(let url)=result {archive=url;preview=nil}
                if case .failure(let error)=result {status=n2SimpleMessage(error)}
            }
            .onDisappear {password=""}
            .onChange(of:scenePhase) {_,phase in if phase == .background {password=""}}
    }
    private func result(_ p:N2SimpleCutPreview)->some View {
        DanperPanel("Saldo y evidencia") {
            LabeledContent("Período",value:DanperDatePresentation.display(p.period.start)+" – "+DanperDatePresentation.display(p.period.end))
            LabeledContent("Conteo confirmado",value:p.counted.formatted())
            Text(n2SimpleDateTime(p.countedAt)).font(.caption).foregroundStyle(.secondary)
            LabeledContent("Existencia al corte consultado",value:p.currentStock.formatted())
            LabeledContent("Salidas verificadas hasta el conteo",value:p.verifiedOutflows.formatted())
            LabeledContent("Ingresos comprobados",value:p.receipts.formatted())
            LabeledContent("Ajustes netos",value:p.netAdjustments.formatted())
            if let opening=p.estimatedOpening {
                LabeledContent(p.confirmedOpening==nil ? "Saldo inicial estimado":"Saldo inicial verificado",value:opening.formatted())
            }
            if p.requiresVerification {
                Text("Saldo inicial estimado: requiere verificación").foregroundStyle(.orange)
                    .accessibilityIdentifier("simple-cut-unverified")
            }
            if p.extraordinaryOpening {
                Text("Apertura extraordinaria basada en el conteo confirmado. Los saldos anteriores no son verificables como saldo real.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    @MainActor private func calculate() async {
        guard !code.isEmpty,!busy else{return};busy=true;defer{busy=false}
        do {
            var data:Data?
            if let archive {
                let scoped=archive.startAccessingSecurityScopedResource();defer{if scoped {archive.stopAccessingSecurityScopedResource()}}
                let attrs=try archive.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey])
                guard attrs.isRegularFile==true,attrs.isSymbolicLink != true,let size=attrs.fileSize,size<=42*1024*1024 else {
                    throw N2InventoryBackupCodec.Failure.envelope
                }
                data=try Data(contentsOf:archive)
            }
            preview=try await vault.simpleInventoryCut(code:code,through:day,archive:data,password:archive==nil ? nil:password)
            status="Consulta calculada sin cambiar existencias."
        }catch {preview=nil;status=n2SimpleMessage(error)}
    }
}
