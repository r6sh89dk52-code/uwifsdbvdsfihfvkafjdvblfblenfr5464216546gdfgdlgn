import XCTest

final class N2MenuInteractionTests:XCTestCase {
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testAnchoredMenusAndInlineMedicationAutocomplete() {
        let app=XCUIApplication()
        app.launchArguments=["--danper-ui-probe"]
        app.launch()
        let type=app.buttons["choice-Tipo de atención"]
        XCTAssertTrue(type.waitForExistence(timeout:10));type.tap()
        let disease=app.buttons["Enfermedad"]
        XCTAssertTrue(disease.waitForExistence(timeout:4))
        capture(app,"Menu-tipo-atencion-abierto")
        disease.tap()
        let system=app.buttons["choice-Sistema afectado"]
        system.tap()
        let osteo=app.buttons["Osteomuscular"]
        XCTAssertTrue(osteo.waitForExistence(timeout:4))
        capture(app,"Menu-sistema-abierto")
        osteo.tap()
        app.buttons["choice-Situación al finalizar"].tap()
        let permit=app.buttons["Se retira con permiso"]
        XCTAssertTrue(permit.waitForExistence(timeout:4))
        capture(app,"Menu-permiso-abierto")
        permit.tap()
        let query=app.textFields["inline-catalog-query"]
        if !query.isHittable {app.swipeUp()}
        XCTAssertTrue(query.waitForExistence(timeout:4));query.tap();query.typeText("Paracetamol")
        let product=app.buttons["suggestion-16000182"]
        XCTAssertTrue(product.waitForExistence(timeout:4))
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
