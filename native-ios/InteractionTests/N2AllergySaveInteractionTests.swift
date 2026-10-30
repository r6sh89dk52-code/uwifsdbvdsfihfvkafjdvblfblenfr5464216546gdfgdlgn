import XCTest

/// Real SwiftUI + DEMO vault, not a mocked save button. No clinical source.
final class N2AllergySaveInteractionTests:XCTestCase {
    private func tap(_ element:XCUIElement,in app:XCUIApplication) {
        let hide=app.buttons["danper-dismiss-keyboard"].firstMatch
        if app.keyboards.firstMatch.exists && hide.exists {hide.tap()}
        XCTAssertTrue(element.waitForExistence(timeout:15),app.debugDescription)
        for _ in 0..<8 {
            if element.isHittable && (element.label=="Siguiente" || (element.frame.minY>120 && element.frame.maxY<app.frame.maxY-90)) {break}
            let up=element.frame.minY>app.frame.midY
            let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.68:0.38))
            let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.02,dy:up ? 0.45:0.60))
            start.press(forDuration:0.1,thenDragTo:end)
        }
        XCTAssertTrue(element.isHittable,app.debugDescription);element.tap()
    }
    func testMeasuredSyntheticFormCPUAndMemory() {
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo"]
        app.launch()
        let new=app.buttons["demo-home-new-attention"]
        XCTAssertTrue(new.waitForExistence(timeout:25))
        let options=XCTMeasureOptions();options.iterationCount=5
        // Automation overhead is included; these are Simulator measurements,
        // not a claim about latency on the user's physical iPhone.
        measure(metrics:[XCTClockMetric(),XCTCPUMetric(application:app),XCTMemoryMetric(application:app)],options:options) {
            new.tap()
            XCTAssertTrue(app.textFields["attention-worker-dni"].waitForExistence(timeout:20))
            app.buttons["premium-close-attention"].tap()
            XCTAssertTrue(new.waitForExistence(timeout:20))
        }
    }
    func testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen() {
        continueAfterFailure=false
        let app=XCUIApplication();app.launchArguments=["--danper-redesign-demo"]
        app.launch()
        let new=app.buttons["demo-home-new-attention"]
        XCTAssertTrue(new.waitForExistence(timeout:25),app.debugDescription);new.tap()
        tap(app.buttons["attention-browse-workers"],in:app)
        let search=app.textFields["roster-global-search"]
        XCTAssertTrue(search.waitForExistence(timeout:15))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","roster-result-")).count,0)
        XCTAssertTrue(app.buttons["roster-create-worker"].exists)
        search.tap();search.typeText("00000031")
        let result=app.buttons["roster-result-00000031"]
        XCTAssertTrue(result.waitForExistence(timeout:10),app.debugDescription)
        XCTAssertLessThanOrEqual(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","roster-result-")).count,25)
        result.tap()
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["choice-Revisión de alergias"],in:app)
        app.buttons["Niega alergias conocidas"].tap()
        let save=app.buttons["Guardar revisión de alergias"]
        tap(save,in:app)
        XCTAssertTrue(app.staticTexts["Alergias revisadas y guardadas"].waitForExistence(timeout:20),app.debugDescription)
        XCTAssertFalse(app.staticTexts["No se guardaron los cambios. Intenta nuevamente."].exists)
        // Let the independently encrypted autosave complete, then reopen the
        // editor. Its allergy status must come from confirmed persistence.
        Thread.sleep(forTimeInterval:2)
        app.buttons["premium-close-attention"].tap()
        app.buttons["demo-home-new-attention"].tap()
        let dni=app.textFields["attention-worker-dni"]
        XCTAssertTrue(dni.waitForExistence(timeout:15));dni.tap();dni.typeText("00000031")
        tap(app.buttons["Siguiente"],in:app)
        XCTAssertTrue(app.staticTexts["Alergias revisadas"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertTrue(app.buttons["choice-Revisión de alergias"].label.contains("Niega alergias conocidas"),app.debugDescription)
    }
}
