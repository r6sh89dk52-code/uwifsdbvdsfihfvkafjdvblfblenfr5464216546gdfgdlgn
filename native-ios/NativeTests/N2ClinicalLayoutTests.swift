import XCTest
import SwiftUI
import UIKit
import DanperCore
@testable import DANPERNative

/// Real UIKit-hosted SwiftUI layouts in iOS Simulator. These attachments prove
/// layout, not Face ID, stock persistence or successful clinical administration.
@MainActor final class N2ClinicalLayoutTests:XCTestCase {
    private func resource(_ name:String)throws->Data {
        if name=="n2-synthetic-clinical" {
            let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:name,withExtension:"json",subdirectory:"SyntheticFixtures"))
            return try Data(contentsOf:url)
        }
        let url=try XCTUnwrap(Bundle.main.url(forResource:name,withExtension:"json",subdirectory:"N1sDemoResources"))
        return try Data(contentsOf:url)
    }
    private func context()throws->N2FormContext {
        let catalog=try N2NativeCatalogLoader.load(products:resource("n2-ambulatory-products"),
            nursing:resource("n2-nursing-catalog"),approvedMappings:resource("n2-approved-mappings"))
        return try N2NativeFormContextReader.read(snapshot:resource("n2-synthetic-clinical"),revision:1,products:catalog)
    }
    private func capture<V:View>(_ view:V,name:String,dark:Bool,large:Bool=false,size:CGSize=CGSize(width:393,height:852)) async throws {
        let host=UIHostingController(rootView:view
            .preferredColorScheme(dark ? .dark : .light)
            .environment(\.colorScheme,dark ? .dark : .light)
            .environment(\.locale,Locale(identifier:"es_PE"))
            .environment(\.scenePhase,.active)
            .environment(\.dynamicTypeSize,large ? .accessibility3 : .large))
        let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
        let window=UIWindow(windowScene:scene)
        window.frame=CGRect(origin:.zero,size:size)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle=dark ? .dark : .light
        host.overrideUserInterfaceStyle=dark ? .dark : .light
        window.rootViewController=host
        window.makeKeyAndVisible()
        defer {window.isHidden=true}
        host.view.frame=window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        try await Task.sleep(for:.milliseconds(600))
        let image=UIGraphicsImageRenderer(bounds:window.bounds).image { _ in
            window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)
        }
        XCTAssertGreaterThan(image.pngData()?.count ?? 0,5000)
        let pixels=try XCTUnwrap(image.cgImage?.dataProvider?.data)
        let sample=Data(bytes:CFDataGetBytePtr(pixels)!,count:CFDataGetLength(pixels))
        XCTAssertGreaterThan(Set(sample).count,32,"Blank capture is not layout evidence")
        let attachment=XCTAttachment(image:image)
        attachment.name=name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testTreatmentCatalogCTAAndMedicationLayouts() async throws {
        let context=try context()
        try await capture(NavigationStack {
            N2PendingDispensingView(visitID:"fundo-unit",medication:N2FormMedication(code:"16000182"),
                date:"2026-10-14",context:context,onSaved:{})
        },name:"Conciliar-salida-pendiente",dark:false)
        var form=N2NativeFormDraft()
        form.dni=context.workers[0].dni
        form.date="2026-10-17";form.time="12:00"
        form.category="ENFERMEDAD";form.system="RESPIRATORIO"
        form.diagnosis="DIAGNÓSTICO FICTICIO"
        let oral=try XCTUnwrap(context.products.clinical.first{
            N2ProcedureRules.infer(name:$0.name).procedure=="TRATAMIENTO ORAL"
        })
        form.items=[N2FormMedication(code:oral.code)]
        form.refreshProcedureSuggestions(catalog:context.products)
        for dark in [false,true] {
            try await capture(NavigationStack {
                N2NativeClinicalFormView(layoutContext:context,draft:form,step:2)
            },name:dark ? "Tratamiento-oscuro" : "Tratamiento-claro",dark:dark)
        }
        try await capture(NavigationStack {
            N2NativeClinicalFormView(layoutContext:context,draft:form,step:2)
        },name:"Tratamiento-DynamicType",dark:false,large:true)
    }
    func testEvaluationReviewSavedAndExportLayouts() async throws {
        let context=try context()
        var form=N2NativeFormDraft()
        form.dni=context.workers[0].dni;form.date="2026-10-17";form.time="13:14"
        form.category="ENFERMEDAD";form.system="OSTEOMUSCULAR";form.segment="Pie"
        form.diagnosis="Faringitis aguda";form.dispensingSite="LA VENTUROSA"
        form.items=[N2FormMedication(code:"16000182")]
        form.refreshProcedureSuggestions(catalog:context.products)
        for dark in [false,true] {
            for step in [1,3] {
                try await capture(NavigationStack {
                    N2NativeClinicalFormView(layoutContext:context,draft:form,step:step)
                },name:"Paso-\(step+1)-\(dark ? "oscuro" : "claro")",dark:dark)
            }
            try await capture(NavigationStack {
                N2NativeClinicalFormView(layoutContext:context,draft:form,step:2,detailOnly:true)
            },name:"Detalle-producto-\(dark ? "oscuro" : "claro")",dark:dark)
            try await capture(NavigationStack {
                N2NativeClinicalFormView(layoutContext:context,draft:form,step:3,saved:true,layoutOutcomes:Dictionary(uniqueKeysWithValues:form.items.map{($0.id,"Descontado")}))
            },name:"Atencion-guardada-\(dark ? "oscuro" : "claro")",dark:dark)
            let model=try N2NativeSnapshotReader.read(resource("n2-synthetic-clinical"))
            try await capture(NavigationStack {
                N2VerifiedIndicatorExportView(layoutVisits:model.visits,selectionOnly:true)
            },name:"Exportacion-\(dark ? "oscuro" : "claro")",dark:dark)
        }
        try await capture(NavigationStack {
            N2NativeClinicalFormView(layoutContext:context,draft:form,step:2,showCatalog:true)
        },name:"Catalogo-oscuro",dark:true)
        try await capture(NavigationStack {
            N2NativeClinicalFormView(layoutContext:context,draft:form,step:3)
        },name:"Resumen-DynamicType",dark:false,large:true)
    }
    func testAccessInventoryAndReconciliationLayouts() async throws {
        let context=try context()
        for dark in [false,true] {
            try await capture(DanperAccessView(unlocking:false,canRetry:false,error:"",onUnlock:{}),
                name:"Acceso-\(dark ? "oscuro" : "claro")",dark:dark)
            try await capture(NavigationStack {N2NativeInventoryView(layoutContext:context)},
                name:"Inventario-inicio-\(dark ? "oscuro" : "claro")",dark:dark)
            try await capture(NavigationStack {N2NativeInventoryView(layoutContext:context,operation:"lot")},
                name:"Inventario-lote-\(dark ? "oscuro" : "claro")",dark:dark)
            try await capture(NavigationStack {N2ReconciliationView(layoutContext:context)},
                name:"Conciliacion-\(dark ? "oscuro" : "claro")",dark:dark)
            try await capture(NavigationStack {N2VerifiedNursingExportView()},
                name:"Kardex-exportar-\(dark ? "oscuro" : "claro")",dark:dark)
        }
    }
    func testHistoryAndKardexLayouts() async throws {
        let model=try N2NativeSnapshotReader.read(resource("n2-synthetic-clinical"))
        for dark in [false,true] {
            try await capture(NavigationStack {N2NativeHistoryView(layoutProjection:model)},
                name:"Historial-\(dark ? "oscuro":"claro")",dark:dark)
            try await capture(NavigationStack {N2Build222KardexHub(layoutLotCount:3)},
                name:"Kardex-\(dark ? "oscuro":"claro")",dark:dark)
        }
    }
    func testHomeLayouts() async throws {
        try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(0,0,0)),name:"Inicio-clinico-protegido-claro",dark:false)
        try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(0,0,0)),name:"Inicio-clinico-protegido-oscuro",dark:true)
        let snapshot=try resource("n2-synthetic-clinical")
        let model=try N2NativeSnapshotReader.read(snapshot)
        let metrics=N2DashboardMetrics.calculate(visits:model.visits,now:Date())
        try await capture(NativeRootView(layoutMetrics:metrics),name:"Inicio-claro",dark:false)
        try await capture(NativeRootView(layoutMetrics:metrics),name:"Inicio-oscuro",dark:true)
    }
    func testWorkerAndAccessLayouts() async throws {
        try await capture(NavigationStack{N2NativeWorkerEditorView()},name:"Nuevo-trabajador",dark:false)
        try await capture(NativeFirstRunOnboarding{},name:"Bienvenida",dark:true)
        let context=try context()
        try await capture(NavigationStack {
            N2NativeClinicalFormView(layoutContext:context,draft:N2NativeFormDraft(),step:0,
                validationMessage:"Selecciona un trabajador. Confirma la revisión de alergias.")
        },name:"Validacion",dark:false)
    }
    func testPremiumStatisticsVersionAndAccessibleHome() async throws {
        let version=DanperAppVersion()
        XCTAssertEqual(version.version,Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String)
        XCTAssertEqual(version.build,Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String)
        for dark in [false,true] {
            try await capture(NavigationStack {DanperStatisticsView()},name:"Premium-estadisticas-\(dark ? "oscuro":"claro")",dark:dark)
            try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(0,0,0),layoutTab:3),name:"Premium-ajustes-\(dark ? "oscuro":"claro")",dark:dark)
        }
        try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(0,0,0)),name:"Premium-Inicio-SE-letra-grande",dark:true,large:true,size:CGSize(width:375,height:667))
    }

}
