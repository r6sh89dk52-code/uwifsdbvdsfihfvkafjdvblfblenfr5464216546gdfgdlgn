import XCTest
import CoreFoundation

/// The per-device prerequisite is N2SimpleInventoryNativeTests, never another
/// UI test. Uses the existing fictional DEMO harness; authentication is tested
/// separately against the genuine device-owner policy, without bypassing it.
final class N3ClinicalJourneyTests:XCTestCase {
    private func capture(_ app:XCUIApplication,_ name:String) {
        let image=XCTAttachment(screenshot:app.screenshot());image.name="KardexV2-"+name;image.lifetime = .keepAlways;add(image)
    }
    private func tap(_ element:XCUIElement,in app:XCUIApplication) {
        let hide=app.buttons["danper-dismiss-keyboard"].firstMatch
        if !element.exists && app.keyboards.firstMatch.exists && hide.exists {hide.tap()}
        XCTAssertTrue(element.waitForExistence(timeout:10),app.debugDescription)
        for _ in 0..<8 {
            let footer=app.buttons["Anterior"]
            let bottom=footer.exists && footer.isHittable ? footer.frame.minY-8:app.frame.maxY-70
            let navigation=app.navigationBars.allElementsBoundByIndex.contains {
                $0.frame.contains(CGPoint(x:element.frame.midX,y:element.frame.midY))
            }
            let fixed=navigation || element.identifier.hasPrefix("premium-tab-") || element.identifier=="premium-close-attention" || element.identifier=="attention-step-actions"
            if element.isHittable && (fixed || (element.frame.minY>130 && element.frame.maxY<bottom)) {break}
            if app.keyboards.firstMatch.exists && hide.exists {hide.tap()}
            else {scrollShort(in:app,up:element.frame.minY>=130)}
        }
        XCTAssertTrue(element.isHittable,app.debugDescription);element.tap()
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
        tap(element,in:app)
        if let old=element.value as? String,old != element.placeholderValue,!old.isEmpty {
            element.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:old.count))
        }
        element.typeText(value)
    }
    private func inventory(_ app:XCUIApplication) {
        tap(app.buttons["premium-tab-home"],in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Kardex:")).firstMatch,in:app)
        XCTAssertTrue(app.textFields["simple-inventory-search"].waitForExistence(timeout:10),"Ejecuta primero la fixture DEMO v2 en este dispositivo: "+app.debugDescription)
    }
    private func stock(_ app:XCUIApplication,_ code:String)->String {
        let field=app.staticTexts["simple-stock-"+code]
        for _ in 0..<5 {if field.exists && field.isHittable {break};app.swipeUp()}
        XCTAssertTrue(field.waitForExistence(timeout:5),app.debugDescription)
        return field.label
    }
    private func saveVisit(_ app:XCUIApplication,r:String,units:Bool) {
        tap(app.buttons["premium-tab-home"],in:app)
        let back=app.navigationBars.buttons["Inicio"]
        if back.exists {tap(back,in:app)}
        tap(app.buttons["demo-home-new-attention"],in:app)
        enter(app.textFields["attention-worker-dni"],"00000031",in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["choice-Revisión de alergias"],in:app)
        tap(app.buttons["Niega alergias conocidas"],in:app)
        tap(app.buttons["Guardar revisión de alergias"],in:app)
        tap(app.buttons["choice-Tipo de atención"],in:app);tap(app.buttons["Enfermedad"],in:app)
        tap(app.buttons["choice-Sistema afectado"],in:app);tap(app.buttons["Respiratorio"],in:app)
        enter(app.descendants(matching:.any)["clinical-diagnosis-input"],"DIAGNOSTICO FICTICIO KARDEX R"+r,in:app)
        tap(app.buttons["Siguiente"],in:app)
        if units {
            addProduct(app,query:"PARACETAMOL",code:"16000182")
            tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-","PARACETAMOL")).firstMatch,in:app)
            enter(app.textFields["clinical-quantity-16000182"],"2",in:app)
        }
        addProduct(app,query:"ALCOHOL MEDICO",code:"16000025")
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-","ALCOHOL")).firstMatch,in:app)
        tap(app.buttons["choice-Procedimiento"].firstMatch,in:app)
        tap(app.buttons["Curacion De Herida"],in:app)
        let choice=app.buttons["simple-r-16000025"].exists ? app.buttons["simple-r-16000025"]:app.buttons["choice-¿Abriste una presentación nueva?"]
        tap(choice,in:app);tap(app.buttons[r=="1" ? "Sí — Kardex R=1":"No — Kardex R=0"],in:app)
        tap(app.buttons["choice-¿Se envió la foto?"],in:app);tap(app.buttons["No se envió"],in:app)
        tap(app.buttons["Siguiente"],in:app);tap(app.buttons["Guardar atención"],in:app)
        XCTAssertTrue(app.staticTexts["Atención registrada"].firstMatch.waitForExistence(timeout:15),app.debugDescription)
        XCTAssertTrue(app.staticTexts["Kardex R: "+r].firstMatch.exists,app.debugDescription)
        capture(app,"Atencion-R"+r)
        tap(app.buttons["premium-close-attention"],in:app)
    }
    private func addProduct(_ app:XCUIApplication,query:String,code:String) {
        if !app.textFields["inline-catalog-query"].exists {tap(app.buttons["add-clinical-product"],in:app)}
        enter(app.textFields["inline-catalog-query"],query,in:app)
        tap(app.buttons["suggestion-"+code],in:app)
    }
    func testConsolidatedClinicalUnitsAndManualRThenRelaunch() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo","-danper.appearance","dark"];app.launch()
        inventory(app)
        let unitsBefore=stock(app,"16000182"),packagesBefore=stock(app,"16000025")
        XCTAssertTrue(unitsBefore.hasPrefix("70 "));XCTAssertTrue(packagesBefore.hasPrefix("12 "))
        capture(app,"Inventario-oscuro")
        saveVisit(app,r:"1",units:true)
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        saveVisit(app,r:"0",units:false)
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        app.terminate();app.launchArguments=["--danper-redesign-demo","-danper.appearance","light"];app.launch()
        inventory(app);XCTAssertTrue(stock(app,"16000182").hasPrefix("68 "));XCTAssertTrue(stock(app,"16000025").hasPrefix("11 "))
        capture(app,"Inventario-claro-persistido")
        tap(app.buttons["premium-tab-history"],in:app)
        XCTAssertTrue(app.staticTexts["DIAGNOSTICO FICTICIO KARDEX R0"].firstMatch.waitForExistence(timeout:10),app.debugDescription)
    }
    func testIndependentRelaunchShowsConsolidatedSourceWithoutReactivation() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo","-danper.appearance","light"];app.launch()
        inventory(app);XCTAssertFalse(app.buttons["simple-migration-activate"].exists)
        XCTAssertTrue(app.buttons["simple-register-product"].exists)
        XCTAssertTrue(app.buttons["simple-product-16000182"].exists)
        app.terminate();app.launch();inventory(app)
        XCTAssertFalse(app.buttons["simple-migration-activate"].exists)
        capture(app,"Relanzamiento-independiente")
    }
    private func authenticateProtectedSource(_ app:XCUIApplication) {
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let permission=springboard.alerts.buttons.matching(NSPredicate(format:"label IN %@",["OK","Allow","Permitir"])).firstMatch
        if permission.waitForExistence(timeout:5) {permission.tap()}
        XCTAssertTrue(app.staticTexts["Verificando identidad…"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.buttons["premium-tab-home"].exists)
        Thread.sleep(forTimeInterval:2)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFNotificationName(rawValue:"com.apple.BiometricKit_Sim.pearl.match" as CFString),nil,nil,true)
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
        app.launch();authenticateProtectedSource(app)
        let manual=app.buttons["clinical-first-run-manual-worker"]
        if manual.waitForExistence(timeout:5) {
            tap(manual,in:app)
            enter(app.textFields["first-manual-worker-dni"],"00000031",in:app)
            enter(app.textFields["first-manual-worker-name"],"PERSONAL AUTORIZADO DE PRUEBA N3",in:app)
            tap(app.buttons["choice-Sede verificada"],in:app);tap(app.buttons["Fundo La Venturosa"],in:app)
            tap(app.buttons["first-manual-worker-activate"],in:app)
            tap(app.buttons["Crear e ingresar primer trabajador"],in:app)
            Thread.sleep(forTimeInterval:2)
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),CFNotificationName(rawValue:"com.apple.BiometricKit_Sim.pearl.match" as CFString),nil,nil,true)
            XCTAssertTrue(app.buttons["Volver para entrar a DANPER"].waitForExistence(timeout:15),app.debugDescription)
            tap(app.buttons["Volver para entrar a DANPER"],in:app)
        }
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.staticTexts["clinical-empty-setup"].exists)
        capture(app,"Fuente-clinica-protegida-ficticia")
        app.terminate();app.launchArguments=["-danper.native.onboarding.v1.finished","NO"]
        app.launch();authenticateProtectedSource(app)
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.buttons["clinical-first-run-manual-worker"].exists)
        capture(app,"Fuente-protegida-tras-relanzar")
    }

}
