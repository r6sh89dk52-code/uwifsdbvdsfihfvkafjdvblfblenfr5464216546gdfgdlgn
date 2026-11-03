import XCTest
import CoreFoundation

/// The per-device prerequisite is N2SimpleInventoryNativeTests, never another
/// UI test. Uses the existing fictional DEMO harness; authentication is tested
/// separately against the genuine device-owner policy, without bypassing it.
final class N3ClinicalJourneyTests:XCTestCase {
    // Every journey remains portrait. Cache only the window geometry during
    // one launch, never an element, clinical value, stock or authentication.
    // Repeated app.frame queries were visible before every content tap in
    // run41664865130, in addition to the fresh target-frame/hit-test queries.
    private var launchViewport:CGRect?
    private func launch(_ app:XCUIApplication) {
        launchViewport=nil
        app.launch()
    }

    override func tearDownWithError() throws {
        for (name, app) in [("DANPER", XCUIApplication()),
                            ("SpringBoard", XCUIApplication(bundleIdentifier:"com.apple.springboard")),
                            ("LocalAuthentication", XCUIApplication(bundleIdentifier:"com.apple.CoreAuthUI"))] {
            let tree=XCTAttachment(string:app.debugDescription)
            tree.name="diagnostic-"+name+"-hierarchy";tree.lifetime = .keepAlways;add(tree)
        }
        let screen=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        screen.name="diagnostic-final-screen";screen.lifetime = .keepAlways;add(screen)
        try super.tearDownWithError()
    }

    private func capture(_ app:XCUIApplication,_ name:String) {
        let image=XCTAttachment(screenshot:app.screenshot());image.name="KardexV2-"+name;image.lifetime = .keepAlways;add(image)
    }
    private func tap(_ element:XCUIElement,in app:XCUIApplication,field:Bool=false,content:Bool=false,bottomInset:CGFloat=110) {
        XCTAssertTrue(element.exists || element.waitForExistence(timeout:10),app.debugDescription)
        // Only scroll actual form content. Native menu options and the fixed
        // footer have their own hit regions; do not query the entire keyboard
        // hierarchy or drag the form behind an already open native menu.
        if field || content {
            let safeTop:CGFloat=field ? 170:130
            if launchViewport == nil {launchViewport=app.frame}
            let bottom=launchViewport!.maxY-bottomInset
            var visible=false
            for _ in 0..<8 {
                let frame=element.frame
                if frame.minY>safeTop && frame.maxY<bottom && element.isHittable {
                    visible=true;break
                }
                scrollShort(in:app,up:frame.minY>=safeTop)
            }
            XCTAssertTrue(visible,"El control debe estar dentro del contenido visible, fuera del pie fijo: "+app.debugDescription)
            // visible already requires this exact target's current isHittable.
            // tap still performs XCTest's own fresh hit test and interruption
            // checks. Do not issue a second identical AX query in between.
        } else {
            XCTAssertTrue(element.isHittable,app.debugDescription)
        }
        element.tap()
    }
    private func dismissKeyboard(in app:XCUIApplication) {
        let hide=app.buttons["danper-dismiss-keyboard"].firstMatch
        if hide.exists {
            hide.tap()
            // Request a fresh query per poll. In run41552268684 the actual
            // dismissal restored the footer, but the prior AX query consumed
            // almost the whole five-second wait. Use the same bounded settling
            // interval as automatic worker selection; still require absence.
            let hidden=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
                !app.keyboards.firstMatch.exists
            },object:nil)
            XCTAssertEqual(XCTWaiter.wait(for:[hidden],timeout:10),.completed,
                "El teclado debe cerrarse antes de buscar los controles de navegación")
        }
    }
    /// Screen-wide inertial flicks can jump a short inline field past both
    /// viewport edges. Drag the empty outer gutter so date/menu controls never
    /// receive an accidental press; every target must still be hittable.
    private func scrollShort(in app:XCUIApplication,up:Bool) {
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.65:0.40))
        let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.45:0.60))
        start.press(forDuration:0.10,thenDragTo:end,withVelocity:.slow,thenHoldForDuration:0.10)
    }
    private func enter(_ element:XCUIElement,_ value:String,in app:XCUIApplication) {
        // Finish the previous responder before moving to a different field.
        // Otherwise a just-scrolled search near the navigation edge can leave
        // the quantity field focused while XCTest starts typing into search.
        dismissKeyboard(in:app)
        let keyboard=app.keyboards.firstMatch
        tap(element,in:app,field:true)
        XCTAssertTrue(keyboard.exists || keyboard.waitForExistence(timeout:5),app.debugDescription)
        if let old=element.value as? String,old != element.placeholderValue,!old.isEmpty {
            element.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count))
        }
        element.typeText(value)
        let identifier=element.identifier
        if identifier=="inline-catalog-query" {
            XCTAssertEqual(element.value as? String,value,"La consulta debe escribirse en el buscador, nunca en la cantidad clínica")
        }
        if identifier=="attention-worker-dni" {
            // Selecting a known DNI dismisses focus asynchronously. The old
            // exists→tap on its toolbar raced that real dismissal on the
            // second R visit (run41528135555). Wait for selection to settle;
            // never tap a button that the app is already removing.
            let settled=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
                !app.keyboards.firstMatch.exists
            },object:nil)
            XCTAssertEqual(XCTWaiter.wait(for:[settled],timeout:10),.completed,
                "La selección automática del trabajador debe cerrar su teclado antes de continuar")
            return
        }
        dismissKeyboard(in:app)
    }
    private func inventory(_ app:XCUIApplication) {
        tap(app.buttons["premium-tab-home"],in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Kardex:")).firstMatch,in:app,content:true)
        XCTAssertTrue(app.textFields["simple-inventory-search"].exists || app.textFields["simple-inventory-search"].waitForExistence(timeout:10),"Ejecuta primero la fixture DEMO v2 en este dispositivo: "+app.debugDescription)
    }
    private func stock(_ app:XCUIApplication,_ code:String)->String {
        let field=app.staticTexts["simple-stock-"+code]
        for _ in 0..<5 {if field.exists && field.isHittable {break};app.swipeUp()}
        XCTAssertTrue(field.exists || field.waitForExistence(timeout:5),app.debugDescription)
        return field.label
    }
    private func saveVisit(_ app:XCUIApplication,r:String,units:Bool) {
        tap(app.buttons["premium-tab-home"],in:app)
        let back=app.navigationBars.buttons["Inicio"]
        if back.exists {tap(back,in:app)}
        tap(app.buttons["demo-home-new-attention"],in:app,content:true)
        enter(app.textFields["attention-worker-dni"],"00000031",in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["choice-Revisión de alergias"],in:app,content:true)
        tap(app.buttons["Niega alergias conocidas"],in:app)
        tap(app.buttons["Guardar revisión de alergias"],in:app,content:true)
        tap(app.buttons["choice-Tipo de atención"],in:app,content:true);tap(app.buttons["Enfermedad"],in:app)
        tap(app.buttons["choice-Sistema afectado"],in:app,content:true);tap(app.buttons["Respiratorio"],in:app)
        enter(app.descendants(matching:.any)["clinical-diagnosis-input"],"DIAGNOSTICO FICTICIO KARDEX R"+r,in:app)
        tap(app.buttons["Siguiente"],in:app)
        if units {
            addProduct(app,query:"PARACETAMOL",code:"16000182")
            tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-","PARACETAMOL")).firstMatch,in:app,content:true)
            enter(app.textFields["clinical-quantity-16000182"],"2",in:app)
        }
        addProduct(app,query:"ALCOHOL MEDICO",code:"16000025")
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-","ALCOHOL")).firstMatch,in:app,content:true)
        tap(app.buttons["choice-Procedimiento"].firstMatch,in:app,content:true)
        tap(app.buttons["Curacion De Herida"],in:app)
        let choice=app.buttons["simple-r-16000025"].exists ? app.buttons["simple-r-16000025"]:app.buttons["choice-¿Abriste una presentación nueva?"]
        tap(choice,in:app,content:true);tap(app.buttons[r=="1" ? "Sí — Kardex R=1":"No — Kardex R=0"],in:app)
        tap(app.buttons["choice-¿Se envió la foto?"],in:app,content:true);tap(app.buttons["No se envió"],in:app)
        tap(app.buttons["Siguiente"],in:app);tap(app.buttons["Guardar atención"],in:app)
        XCTAssertTrue(app.staticTexts["Atención registrada"].firstMatch.waitForExistence(timeout:15),app.debugDescription)
        XCTAssertTrue(app.staticTexts["Kardex R: "+r].firstMatch.exists,app.debugDescription)
        capture(app,"Atencion-R"+r)
        tap(app.buttons["premium-close-attention"],in:app)
    }
    private func addProduct(_ app:XCUIApplication,query:String,code:String) {
        if !app.textFields["inline-catalog-query"].exists {tap(app.buttons["add-clinical-product"],in:app,content:true)}
        enter(app.textFields["inline-catalog-query"],query,in:app)
        tap(app.buttons["suggestion-"+code],in:app,content:true)
    }
    func testConsolidatedClinicalUnitsAndManualRThenRelaunch() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo","-danper.appearance","dark"];launch(app)
        tap(app.buttons["premium-tab-history"],in:app)
        XCTAssertTrue(app.staticTexts["Atenciones registradas"].waitForExistence(timeout:10))
        inventory(app)
        let unitsBefore=stock(app,"16000182"),packagesBefore=stock(app,"16000025")
        XCTAssertTrue(unitsBefore.hasPrefix("70 "));XCTAssertTrue(packagesBefore.hasPrefix("12 "))
        capture(app,"Inventario-oscuro")
        saveVisit(app,r:"1",units:true)
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        saveVisit(app,r:"0",units:false)
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        app.terminate();app.launchArguments=["--danper-redesign-demo","-danper.appearance","light"];launch(app)
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        capture(app,"Inventario-claro-persistido")
        tap(app.buttons["premium-tab-history"],in:app)
        XCTAssertTrue(app.staticTexts["DIAGNOSTICO FICTICIO KARDEX R0"].firstMatch.waitForExistence(timeout:10),app.debugDescription)
    }
    func testIndependentRelaunchShowsConsolidatedSourceWithoutReactivation() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo","-danper.appearance","light"];launch(app)
        inventory(app);XCTAssertFalse(app.buttons["simple-migration-activate"].exists)
        XCTAssertTrue(app.buttons["simple-register-product"].exists)
        XCTAssertTrue(app.buttons["simple-product-16000182"].exists)
        app.terminate();launch(app);inventory(app)
        XCTAssertFalse(app.buttons["simple-migration-activate"].exists)
        capture(app,"Relanzamiento-independiente")
    }
    private func authenticateProtectedSource(_ app:XCUIApplication) {
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let permission=springboard.alerts.buttons.matching(NSPredicate(format:"label IN %@",["OK","Allow","Permitir"])).firstMatch
        if permission.waitForExistence(timeout:5) {permission.tap()}
        let retry=app.buttons["Reintentar Face ID"]
        let gate=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            app.staticTexts["Verificando identidad…"].exists || retry.exists
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[gate],timeout:15),.completed,app.debugDescription)
        XCTAssertFalse(app.buttons["premium-tab-home"].exists)
        Thread.sleep(forTimeInterval:2)
        var retried=false
        SimulatorBiometricEvents.send("match",onWaiting:{
            // CoreAuthUI may fail to activate on a cold Simulator. Exercise
            // the real user's one retry, within the existing 20-second
            // sensor wait; dedicated biometric tests still require auto entry.
            if !retried && retry.exists && retry.isHittable {
                retried=true
                XCTContext.runActivity(named:"Un reintento real tras fallo de activación Face ID") {_ in
                    retry.tap()
                }
            }
        })
        let usable=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            let manual=app.buttons["clinical-first-run-manual-worker"]
            let home=app.buttons["premium-tab-home"]
            return (manual.exists && manual.isHittable) || (home.exists && home.isHittable)
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[usable],timeout:15),.completed,
            "Face ID debe cerrar su UI antes de tocar la fuente protegida: "+app.debugDescription)
    }
    /// Preserve the former protected-source assertions independently of the
    /// replaced FEFO journey. This uses actual LocalAuthentication, not DEMO.
    func testProtectedClinicalSourceCreationAndRelaunch() {
        #if !targetEnvironment(simulator)
        XCTFail("Requires isolated Simulator without real clinical data")
        return
        #endif
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["-danper.native.onboarding.v1.finished","YES"]
        launch(app);authenticateProtectedSource(app)
        let manual=app.buttons["clinical-first-run-manual-worker"]
        if manual.waitForExistence(timeout:5) {
            tap(manual,in:app)
            enter(app.textFields["first-manual-worker-dni"],"00000031",in:app)
            enter(app.textFields["first-manual-worker-name"],"PERSONAL AUTORIZADO DE PRUEBA N3",in:app)
            tap(app.buttons["choice-Sede verificada"],in:app,content:true);tap(app.buttons["Fundo La Venturosa"],in:app)
            tap(app.buttons["first-manual-worker-activate"],in:app,content:true,bottomInset:50)
            tap(app.buttons["Crear e ingresar primer trabajador"],in:app)
            Thread.sleep(forTimeInterval:2)
            SimulatorBiometricEvents.send("match")
            XCTAssertTrue(app.buttons["Volver para entrar a DANPER"].waitForExistence(timeout:15),app.debugDescription)
            tap(app.buttons["Volver para entrar a DANPER"],in:app)
        }
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.staticTexts["clinical-empty-setup"].exists)
        capture(app,"Fuente-clinica-protegida-ficticia")
        app.terminate();app.launchArguments=["-danper.native.onboarding.v1.finished","NO"]
        launch(app);authenticateProtectedSource(app)
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.buttons["clinical-first-run-manual-worker"].exists)
        capture(app,"Fuente-protegida-tras-relanzar")
    }

}
