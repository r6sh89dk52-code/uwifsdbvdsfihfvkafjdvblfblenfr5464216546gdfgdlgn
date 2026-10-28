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
    private func launch(_ app:XCUIApplication) {
        app.launchArguments=["--danper-redesign-demo","-danper.appearance","dark"]
        app.launch()
        XCTAssertTrue(app.buttons["demo-home-new-attention"].waitForExistence(timeout:20),app.debugDescription)
    }
    func testEveryHomeToolAndAllToolsRetainRealDestinations() {
        continueAfterFailure=false
        let app=XCUIApplication()
        for (name,destination) in [("Trabajadores","Personal"),("Kardex","Inventario"),("Estadísticas",""),("Indicadores","Indicadores")] {
            launch(app)
            XCTAssertTrue(app.staticTexts["Hola"].exists)
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
