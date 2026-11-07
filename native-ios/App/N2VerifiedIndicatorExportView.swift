import Foundation
import SwiftUI
import UIKit
import DanperCore

private struct N2IndicatorShare:Identifiable {
    let id=UUID()
    let file:URL
}
private struct N2IndicatorShareSheet:UIViewControllerRepresentable {
    let file:URL
    func makeUIViewController(context:Context)->UIActivityViewController {
        let controller=UIActivityViewController(activityItems:[file],applicationActivities:nil)
        controller.overrideUserInterfaceStyle=DanperStyle.sharingAppearance
        return controller
    }
    func updateUIViewController(_ controller:UIActivityViewController,context:Context){}
}

/// Joint Indicator export for an editable date interval.
struct N2VerifiedIndicatorExportView:View {
    @Environment(\.n2WorkspaceVault) private var vault
    private var layoutOnly=false
    private var layoutSelectionOnly=false

    @State private var startDate=Date()
    @State private var endDate=Date()
    @State private var visits=[N2VisitIndexRow]()
    @State private var ready=false
    @State private var working=false
    @State private var failed=false
    @State private var status="Cargando atenciones…"
    @State private var share:N2IndicatorShare?
    @State private var folder:URL?

    init() {}
    #if DEBUG
    init(layoutVisits:[N2VisitIndexRow],selectionOnly:Bool=false) {
        layoutSelectionOnly=selectionOnly
        layoutOnly=true
        _visits=State(initialValue:layoutVisits)
        let formatter=DateFormatter()
        formatter.dateFormat="yyyy-MM-dd"
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        _startDate=State(initialValue:formatter.date(from:"2026-10-01")!)
        _endDate=State(initialValue:formatter.date(from:"2026-10-31")!)
    }
    #endif

    private func local(_ date:Date,format:String="yyyy-MM-dd")->String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat=format
        return formatter.string(from:date)
    }

    private func visitsInRange(start:String,end:String,at now:Date)->[N2VisitIndexRow] {
        let today=local(now), minute=local(now,format:"HH:mm")
        return visits.filter { visit in
            visit.status=="saved" && visit.date>=start && visit.date<=end &&
            (visit.date != today || visit.time <= minute)
        }
    }
    private func verifiedSite(_ visit:N2VisitIndexRow)->Bool {
        ["LA VENTUROSA","PLVENTUROSA"].contains(visit.workerSite)
    }

    var body:some View {
        let now=Date(), start=local(startDate), end=local(endDate)
        let inRange=visitsInRange(start:start,end:end,at:now)
        let needsSite=inRange.filter { !verifiedSite($0) }
        let validDates=start<=end && end<=local(now)
        ScrollView {
            VStack(alignment:.leading,spacing:16) {
                if !layoutSelectionOnly {
                    DanperPanel("Período del Indicador") {
                        DanperDateField(title:"Desde",selection:$startDate)
                        DanperDateField(title:"Hasta",selection:$endDate)
                        LabeledContent("Ámbito",value:"Fundo y Planta La Venturosa")
                        if !validDates {
                            Text("Elige un intervalo en orden y con fecha final hasta hoy.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                DanperPanel("Atenciones del intervalo") {
                    LabeledContent("Atenciones guardadas",value:String(inRange.count))
                    let pending=inRange.filter{$0.pendingPhysicalLines>0}.count
                    if pending>0 {
                        Text("\(pending) con consumo pendiente. Las cantidades físicas sin acreditar se dejan vacías.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !needsSite.isEmpty {
                        Text("\(needsSite.count) sin sede acreditada. Confirma la sede para incluirlas.")
                            .font(.caption).foregroundStyle(.orange)
                        ForEach(needsSite) { visit in
                            NavigationLink {
                                N2ClinicalCorrectionView(visitID:visit.id)
                                    .onDisappear { Task { await refreshVisits() } }
                            } label: {
                                Label("Confirmar sede · "+visit.workerName,systemImage:"mappin.and.ellipse")
                            }
                            .buttonStyle(DanperSecondaryButton())
                            .accessibilityIdentifier("indicator-confirm-visit-site-"+visit.id)
                        }
                    }
                }
                if !layoutSelectionOnly {
                    DanperPanel("Excel · 10 hojas") {
                        Text("RESU muestra los saldos del intervalo. Si falta evidencia, el saldo queda vacío o se indica que es estimado.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button {
                            Task { await export() }
                        } label: {
                            Label(working ? "Generando…" : "Generar Excel de 10 hojas",
                                  systemImage:"square.and.arrow.up")
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .disabled(!ready || working || !validDates)
                        .accessibilityIdentifier("indicator-export-to-date")
                        Text(status).font(.footnote)
                            .foregroundStyle(failed ? Color.red : Color.secondary)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Indicador ambulatorio")
        .danperFormChrome()
        .sheet(item:$share,onDismiss:cleanup) { N2IndicatorShareSheet(file:$0.file) }
        .task {
            if !layoutOnly {
                var calendar=Calendar(identifier:.gregorian)
                calendar.timeZone=TimeZone(identifier:"America/Lima")!
                let today=Date()
                if let thisMonth=calendar.dateInterval(of:.month,for:today)?.start,
                   let previous=calendar.date(byAdding:.month,value:-1,to:thisMonth),
                   let last=calendar.date(byAdding:.day,value:-1,to:thisMonth) {
                    startDate=previous
                    endDate=last
                }
                await refreshVisits()
            }
        }
        .onDisappear { if share == nil { cleanup() } }
    }

    @MainActor
    private func refreshVisits() async {
        guard !layoutOnly else { return }
        do {
            guard let history=try await vault.readHistory() else {
                throw N2VerifiedIndicatorWorkbook.Failure.invalidSnapshot
            }
            visits=history.visits
            ready=true
            failed=false
            status="Selecciona Desde y Hasta."
        } catch {
            failed=true
            ready=false
            status="No se pudo cargar el historial."
        }
    }

    @MainActor
    private func export() async {
        let now=Date(), start=local(startDate), end=local(endDate)
        guard ready,!working,start<=end,end<=local(now) else { return }
        let ids=Set(visitsInRange(start:start,end:end,at:now).filter(verifiedSite).map(\.id))
        working=true
        failed=false
        status="Verificando atenciones y saldos del intervalo…"
        defer { working=false }
        do {
            let result=try await vault.exportVerifiedIndicatorWorkbook(
                start:start,end:end,subdivision:"AMBAS",ids:ids,allowPending:true)
            cleanup()
            let dir=FileManager.default.temporaryDirectory
                .appendingPathComponent((vault.isClinical ? "danper-n2-clinical-indicator-" :
                                            "danper-n2-demo-indicator-")+UUID().uuidString,isDirectory:true)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true,
                attributes:[.protectionKey:FileProtectionType.complete])
            folder=dir
            let prefix=result.provisional ? "DANPER_PROVISIONAL_" : "DANPER_INDICADOR_"
            let url=dir.appendingPathComponent("\(prefix)AMBAS_\(start)_\(end).xlsx")
            try await N2WorkspaceFileIO.shared.writeProtectedExport(result.xlsx,to:url)
            status="\(result.visits) atenciones exportadas. Sin stock inicial acreditado: \(result.missingOpening). Sin stock final acreditado: \(result.missingClosingCount)."
            share=N2IndicatorShare(file:url)
        } catch {
            failed=true
            cleanup()
            if let failure=error as? N2VerifiedIndicatorWorkbook.Failure, failure == .unverifiedDelivery {
                status="Hay entregas contradictorias o correcciones pendientes. Revisa la atención antes de exportar."
            } else {
                status="No se pudo generar el Excel. Revisa las fechas y los registros del intervalo."
            }
        }
    }

    @MainActor
    private func cleanup() {
        if let folder{try? FileManager.default.removeItem(at:folder)}
        folder=nil
    }
}

