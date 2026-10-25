import XCTest

/// Recorre el módulo N4 sin ninguna carga clínica real y sin pedir Face ID.
final class DMModuleInteractionTests:XCTestCase {
    func testN4SimulatorHomeAndManualReview() {
        let app=XCUIApplication()
        app.launchArguments=["--danper-dm-lab"]
        app.launch()
        XCTAssertTrue(app.staticTexts["DESCANSOS MÉDICOS"].waitForExistence(timeout:15))
        XCTAssertTrue(app.buttons["dm-import-photo"].exists)
        XCTAssertTrue(app.buttons["Registrar sin foto"].exists)
        let camera=app.buttons["Escanear con cámara"]
        XCTAssertTrue(camera.exists)
        // En un iPhone 16 Simulator sin cámara física, continuar por galería.
        app.buttons["Registrar sin foto"].tap()
        XCTAssertTrue(app.navigationBars["Verificar CITT"].waitForExistence(timeout:10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@", "Recepción:")).firstMatch.exists)
        XCTAssertFalse(app.buttons["dm-save-certificate"].isEnabled)
        app.buttons["Cancelar"].tap()
        XCTAssertTrue(app.staticTexts["DESCANSOS MÉDICOS"].waitForExistence(timeout:5))
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name="N4-DM-Home-Simulator";attachment.lifetime = .keepAlways
        add(attachment)
    }
}
