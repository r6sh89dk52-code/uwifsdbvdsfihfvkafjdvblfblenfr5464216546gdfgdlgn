import XCTest

/// Isolated DEMO only. These tests navigate and search; they never change
/// clinical records, stock, encrypted backups or the protected source.
final class N2GlassClinicalTests:XCTestCase {
    private func capture(_ name:String) {
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        a.name="Glass-"+name;a.lifetime = .keepAlways;add(a)
    }
    private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<7 {
            if element.exists && element.isHittable {return}
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.exists,app.debugDescription);XCTAssertTrue(element.isHittable)
    }
    private func launch(_ app:XCUIApplication,localTime:String="09:00:00",appearance:String="dark",large:Bool=false) {
        app.launchArguments=["--danper-redesign-demo","-danper.appearance",appearance]
        if large {app.launchArguments += ["-UIPreferredContentSizeCategoryName","UICTContentSizeCategoryAccessibilityXXXL"]}
        app.launchEnvironment["DANPER_GREETING_TEST_LOCAL"]="2026-10-29T"+localTime
        app.launch()
        XCTAssertTrue(app.buttons["demo-home-new-attention"].waitForExistence(timeout:20),app.debugDescription)
    }
    func testEveryHomeToolAndAllToolsRetainRealDestinations() {
        continueAfterFailure=false
        let app=XCUIApplication()
        for (name,destination) in [("Trabajadores","Personal"),("Kardex","Inventario"),("Estadísticas",""),("Indicadores","Indicadores")] {
            launch(app)
            XCTAssertTrue(app.staticTexts["Buenos días ☀️"].exists)
            XCTAssertFalse(app.staticTexts["Bienvenido"].exists)
            for id in ["today","week","month"] {XCTAssertTrue(app.descendants(matching:.any)["premium-metric-"+id].exists)}
            capture("Inicio-"+name)
            let tool=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@",name+":")).firstMatch
            reveal(tool,in:app);capture("Inicio-herramientas-desplazadas");tool.tap()
            if destination.isEmpty {
                XCTAssertTrue(app.staticTexts["Resumen aún no disponible"].firstMatch.waitForExistence(timeout:10))
            } else {XCTAssertTrue(app.navigationBars[destination].waitForExistence(timeout:10),app.debugDescription)}
            capture("Ruta-"+name);app.terminate()
        }
        launch(app)
        let all=app.buttons["glass-home-all-tools"];reveal(all,in:app);all.tap()
        XCTAssertTrue(app.navigationBars["Herramientas"].waitForExistence(timeout:10))
        capture("Ver-todas-inicio")
        let backup=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Respaldo cifrado")).firstMatch
        reveal(backup,in:app);capture("Ver-todas-reportes-seguridad");backup.tap()
        XCTAssertTrue(app.navigationBars["Respaldo cifrado"].waitForExistence(timeout:10));capture("Respaldo-cifrado")
        app.navigationBars.buttons.firstMatch.tap()
        let restore=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Restaurar historial sin reemplazar inventario")).firstMatch
        reveal(restore,in:app);restore.tap()
        XCTAssertTrue(app.navigationBars["Restaurar historial"].waitForExistence(timeout:10));capture("Restauracion-selectiva")
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<4 {app.scrollViews.firstMatch.swipeUp()}
        capture("Ver-todas-final-desplazado")
    }
    private func assertWelcome(_ app:XCUIApplication,_ expected:String) {
        let greeting=app.staticTexts["glass-home-greeting-text"]
        let match=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@",expected),object:greeting)
        XCTAssertEqual(XCTWaiter.wait(for:[match],timeout:10),.completed,app.debugDescription)
        let avatar=app.images["glass-home-avatar"]
        XCTAssertTrue(avatar.exists);XCTAssertTrue(avatar.isHittable)
        XCTAssertGreaterThanOrEqual(avatar.frame.minX,app.frame.minX)
        XCTAssertLessThanOrEqual(greeting.frame.maxX,app.frame.maxX)
        XCTAssertLessThanOrEqual(avatar.frame.maxX,greeting.frame.minX,"Avatar and greeting must not overlap")
        XCTAssertTrue(app.staticTexts["Departamento de Salud"].exists)
        let next=app.buttons["demo-home-new-attention"]
        XCTAssertLessThanOrEqual(greeting.frame.maxY,next.frame.minY,"Greeting must not cover Nueva atención")
    }
    func testLocalDisplayNamePersistsWithoutChangingClinicalIdentity() {
        continueAfterFailure=false
        let app=XCUIApplication();launch(app)
        assertWelcome(app,"Buenos días ☀️")
        XCTAssertTrue(app.staticTexts["DEMO · Datos ficticios"].exists)
        app.buttons["premium-tab-settings"].tap()
        let name=app.textFields["glass-display-name"]
        reveal(name,in:app);name.tap();name.typeText("Felipe")
        app.buttons["danper-dismiss-keyboard"].tap()
        capture("Preferencia-nombre-local")
        app.buttons["premium-tab-home"].tap()
        assertWelcome(app,"Buenos días Felipe ☀️");capture("Inicio-manana-Felipe-avatar")
        app.terminate();launch(app)
        assertWelcome(app,"Buenos días Felipe ☀️");capture("Inicio-nombre-persistido")
        for (time,text,appearance) in [("12:00:00","Buenas tardes Felipe 🌤️","light"),
                                        ("19:00:00","Buenas noches Felipe 🌙","dark")] {
            app.terminate();launch(app,localTime:time,appearance:appearance)
            assertWelcome(app,text);capture("Inicio-"+time+"-"+appearance)
        }
        // The injected clock advances using uptime. Cross a real scheduled
        // boundary while visible, then another during actual backgrounding.
        app.terminate();launch(app,localTime:"11:59:45")
        assertWelcome(app,"Buenos días Felipe ☀️")
        let afternoon=app.staticTexts["glass-home-greeting-text"]
        let changed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"label == %@","Buenas tardes Felipe 🌤️"),object:afternoon)
        XCTAssertEqual(XCTWaiter.wait(for:[changed],timeout:25),.completed)
        capture("Inicio-cambio-tramo-visible")
        app.terminate();launch(app,localTime:"18:59:45")
        assertWelcome(app,"Buenas tardes Felipe 🌤️")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for:.runningBackground,timeout:10))
        let elapsed=XCTestExpectation(description:"Cross injected clock boundary in background")
        DispatchQueue.main.asyncAfter(deadline:.now()+17) {elapsed.fulfill()}
        wait(for:[elapsed],timeout:20)
        app.activate()
        assertWelcome(app,"Buenas noches Felipe 🌙");capture("Inicio-primer-plano-actualizado")
        app.terminate();launch(app,large:true)
        assertWelcome(app,"Buenos días Felipe ☀️");capture("Inicio-Felipe-texto-accesible")
        app.terminate();launch(app)
        app.buttons["premium-tab-settings"].tap()
        reveal(name,in:app);name.tap();name.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:6))
        app.buttons["danper-dismiss-keyboard"].tap()
        app.buttons["premium-tab-home"].tap()
        assertWelcome(app,"Buenos días ☀️");capture("Inicio-nombre-opcional-vacio")
        app.terminate();launch(app)
        assertWelcome(app,"Buenos días ☀️")
    }
    func testRealKardexFiltersSearchAndDetailWithoutMutations() {
        continueAfterFailure=false
        let app=XCUIApplication();launch(app)
        let tool=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Kardex:")).firstMatch
        reveal(tool,in:app);tool.tap()
        let filters=app.segmentedControls["glass-inventory-filter"]
        XCTAssertTrue(filters.waitForExistence(timeout:15),app.debugDescription)
        let tablet=app.buttons["simple-product-16000182"],bottle=app.buttons["simple-product-16000025"]
        XCTAssertTrue(tablet.exists);XCTAssertTrue(bottle.exists);capture("Kardex-Todos-real")
        filters.buttons["Medicamentos"].tap()
        XCTAssertTrue(tablet.exists);XCTAssertFalse(bottle.exists);capture("Kardex-Medicamentos-real")
        filters.buttons["Insumos"].tap()
        XCTAssertFalse(tablet.exists);XCTAssertTrue(bottle.exists);capture("Kardex-Insumos-real")
        filters.buttons["Todos"].tap()
        let search=app.textFields["simple-inventory-search"]
        search.tap();search.typeText("FCO")
        XCTAssertTrue(bottle.exists);XCTAssertFalse(tablet.exists);capture("Kardex-busqueda-presentacion-teclado")
        app.buttons["danper-dismiss-keyboard"].tap()
        capture("Kardex-busqueda-presentacion")
        app.buttons["glass-inventory-clear-search"].tap()
        XCTAssertTrue(tablet.exists)
        reveal(tablet,in:app);tablet.tap()
        XCTAssertTrue(app.buttons["simple-receipt"].waitForExistence(timeout:10))
        for id in ["simple-outflow","simple-count","simple-expiry"] {XCTAssertTrue(app.buttons[id].exists)}
        capture("Kardex-detalle-movimientos-acciones")
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<3 {app.scrollViews.firstMatch.swipeUp()}
        XCTAssertTrue(filters.isHittable,"Los filtros permanecen visibles al desplazar productos y acciones")
        capture("Kardex-acciones-final-filtros-fijos")
    }
}
