import XCTest

final class N2PremiumRedesignTests:XCTestCase {
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        attachment.name="Premium-"+name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func reveal(_ element:XCUIElement,in app:XCUIApplication) {
        for _ in 0..<5 {
            if element.exists && element.isHittable {return}
            app.swipeUp()
        }
        XCTAssertTrue(element.exists);XCTAssertTrue(element.isHittable)
    }
    func testDemoNavigationAttentionAndVersion() {
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["--danper-redesign-demo","-danper.appearance","dark"]
        app.launch()
        let start=app.buttons["start-empty-demo"]
        if start.waitForExistence(timeout:5) {reveal(start,in:app);start.tap()}
        let new=app.buttons["demo-home-new-attention"]
        XCTAssertTrue(new.waitForExistence(timeout:20),app.debugDescription)
        XCTAssertTrue(app.staticTexts["DEMO · Datos ficticios"].exists)
        capture(app,"Inicio-oscuro")
        let tab=new.frame
        XCTAssertTrue(tab.maxY<app.buttons["premium-tab-home"].frame.minY,"La cápsula no debe cubrir Nueva atención")
        new.tap()
        XCTAssertTrue(app.textFields["attention-worker-dni"].waitForExistence(timeout:10),app.debugDescription)
        app.textFields["attention-worker-dni"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5))
        XCTAssertGreaterThan(app.keyboards.firstMatch.frame.height,150,"Validar con teclado en pantalla")
        let hiddenNew=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["Siguiente"])
        XCTAssertEqual(XCTWaiter.wait(for:[hiddenNew],timeout:5),.completed,"El teclado debe ocultar la barra de pasos")
        XCTAssertFalse(app.buttons["premium-tab-home"].exists && app.buttons["premium-tab-home"].isHittable,"La cápsula no debe interferir con el editor")
        capture(app,"Nueva-atencion-teclado")
        app.buttons["premium-close-attention"].tap()
        app.buttons["premium-tab-history"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Historial")
        app.buttons["premium-tab-drafts"].tap()
        XCTAssertTrue(app.navigationBars["Borradores"].waitForExistence(timeout:10))
        capture(app,"Borradores")
        let delete=app.buttons["draft-dashboard-delete-premium-ui-draft"]
        XCTAssertTrue(delete.waitForExistence(timeout:10),app.debugDescription)
        let draft=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","PERSONA FICTICIA REDISENO")).firstMatch
        draft.tap()
        let diagnosis=app.descendants(matching:.any)["clinical-diagnosis-input"]
        XCTAssertTrue(diagnosis.waitForExistence(timeout:10),app.debugDescription)
        XCTAssertEqual(diagnosis.value as? String,"BORRADOR FICTICIO REDISENO")
        XCTAssertTrue(app.buttons["premium-close-attention"].exists,"Borradores y Nueva atención comparten el mismo contenedor")
        diagnosis.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5))
        XCTAssertGreaterThan(app.keyboards.firstMatch.frame.height,150,"Validar con teclado en pantalla")
        let hiddenDraft=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["Siguiente"])
        XCTAssertEqual(XCTWaiter.wait(for:[hiddenDraft],timeout:5),.completed)
        XCTAssertFalse(app.buttons["Anterior"].exists)
        // iOS 18.5 places the caret at the tap location. Select the existing
        // draft explicitly, rather than assuming that tapping moves to end.
        let original=diagnosis.value as? String ?? ""
        XCTAssertEqual(original,"BORRADOR FICTICIO REDISENO")
        diagnosis.press(forDuration:1.2)
        let selectAllPredicate=NSPredicate(format:"label IN %@",["Select All","Seleccionar todo"])
        let menu=app.menuItems.matching(selectAllPredicate).firstMatch
        let button=app.buttons.matching(selectAllPredicate).firstMatch
        if menu.waitForExistence(timeout:2) {menu.tap()}
        else {XCTAssertTrue(button.waitForExistence(timeout:3),app.debugDescription);button.tap()}
        diagnosis.typeText(original+" CORREGIDO")
        XCTAssertEqual(diagnosis.value as? String,original+" CORREGIDO")
        XCTAssertTrue((diagnosis.value as? String)?.hasSuffix(" CORREGIDO") == true)
        capture(app,"Borrador-teclado-sin-barras")
        app.buttons["danper-dismiss-keyboard"].tap()
        XCTAssertTrue(app.buttons["Siguiente"].waitForExistence(timeout:5))
        capture(app,"Borrador-recuperado")
        XCTAssertFalse(app.buttons["premium-tab-drafts"].exists && app.buttons["premium-tab-drafts"].isHittable)
        let next=app.buttons["Siguiente"]
        XCTAssertTrue(next.isHittable)
        XCTAssertLessThanOrEqual(next.frame.maxY,app.frame.maxY)
        XCUIDevice.shared.press(.home)
        app.activate()
        let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["premium-close-attention"])
        XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:5),.completed,"El editor compartido se cierra al pasar a segundo plano")

        XCTAssertTrue(delete.waitForExistence(timeout:10))
        delete.tap()
        app.buttons["Eliminar borrador"].tap()
        let removed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:delete)
        XCTAssertEqual(XCTWaiter.wait(for:[removed],timeout:10),.completed)
        capture(app,"Borrador-eliminado")
        app.buttons["premium-tab-settings"].tap()
        XCTAssertTrue(app.staticTexts["DANPER Salud Móvil"].waitForExistence(timeout:5))
        XCTAssertTrue(app.descendants(matching:.any).matching(NSPredicate(format:"label BEGINSWITH %@","Compilación")).firstMatch.exists,app.debugDescription)
        capture(app,"Ajustes-version")
        app.buttons["premium-tab-home"].tap()
        let stats=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Estadísticas:")).firstMatch
        reveal(stats,in:app);stats.tap()
        XCTAssertTrue(app.staticTexts["Resumen aún no disponible"].firstMatch.waitForExistence(timeout:5))
        XCTAssertFalse(app.staticTexts["1,248"].exists)
        capture(app,"Estadisticas-sin-cifras-ficticias")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.terminate();app.launch()
        XCTAssertTrue(app.buttons["premium-tab-drafts"].waitForExistence(timeout:10))
        app.buttons["premium-tab-drafts"].tap()
        XCTAssertTrue(app.staticTexts["No hay borradores para recuperar."].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertFalse(app.buttons["draft-dashboard-delete-premium-ui-draft"].exists)
        capture(app,"Eliminacion-persistida-tras-relanzar")
    }
    func testAccessLightAndDark() {
        let app=XCUIApplication()
        for appearance in ["dark","light"] {
            app.launchArguments=["--danper-redesign-access","-danper.appearance",appearance]
            app.launch()
            XCTAssertTrue(app.buttons["premium-face-id"].waitForExistence(timeout:5))
            XCTAssertTrue(app.buttons["premium-device-code"].exists)
            XCTAssertTrue(app.staticTexts["premium-access-version"].exists)
            capture(app,"Acceso-"+appearance)
            app.terminate()
        }
    }
}
