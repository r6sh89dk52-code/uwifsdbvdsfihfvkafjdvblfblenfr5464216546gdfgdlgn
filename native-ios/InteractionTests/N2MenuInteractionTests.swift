import XCTest

final class N2MenuInteractionTests:XCTestCase {
    private func tapVisible(_ element:XCUIElement,in app:XCUIApplication) {
        if !element.isHittable {app.swipeUp()}
        XCTAssertTrue(element.isHittable)
        element.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testAnchoredMenusAndInlineMedicationAutocomplete() {
        let app=XCUIApplication()
        app.launchArguments=["--danper-ui-probe"]
        app.launch()
        let type=app.buttons["choice-Tipo de atención"]
        XCTAssertTrue(type.waitForExistence(timeout:10));tapVisible(type,in:app)
        let disease=app.buttons["Enfermedad"]
        XCTAssertTrue(disease.waitForExistence(timeout:4))
        capture(app,"Menu-tipo-atencion-abierto")
        disease.tap()
        let system=app.buttons["choice-Sistema afectado"]
        tapVisible(system,in:app)
        let osteo=app.buttons["Osteomuscular"]
        XCTAssertTrue(osteo.waitForExistence(timeout:4))
        capture(app,"Menu-sistema-abierto")
        osteo.tap()
        let ending=app.buttons["choice-Situación al finalizar"]
        tapVisible(ending,in:app)
        let permit=app.buttons["Se retira con permiso"]
        XCTAssertTrue(permit.waitForExistence(timeout:4))
        capture(app,"Menu-permiso-abierto")
        permit.tap()
        let query=app.textFields["inline-catalog-query"]
        if !query.isHittable {app.swipeUp()}
        XCTAssertTrue(query.waitForExistence(timeout:4));query.tap();query.typeText("Paracetamol")
        let product=app.buttons["suggestion-16000182"]
        XCTAssertTrue(product.waitForExistence(timeout:4))
        let visible=XCTNSPredicateExpectation(predicate:NSPredicate(format:"hittable == true"),object:product)
        XCTAssertEqual(XCTWaiter.wait(for:[visible],timeout:5),.completed,"La sugerencia debe quedar visible sobre el teclado sin desplazamiento manual")
        capture(app,"Autocompletado-paracetamol-teclado")
        product.tap()
        XCTAssertTrue(app.staticTexts["Seleccionados: 1"].waitForExistence(timeout:4))
        query.tap();query.typeText("Diclofenaco")
        let ampoule=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","suggestion-","AMPOLLA")).firstMatch
        XCTAssertTrue(ampoule.waitForExistence(timeout:4));ampoule.tap()
        XCTAssertTrue(app.staticTexts["Seleccionados: 2"].waitForExistence(timeout:4))
        capture(app,"Seleccion-multiple-inline")
    }
}
