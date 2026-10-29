import XCTest

/// Presentation harness only: no clinical vault, credentials or patient data.
final class N2Build222ShellTests:XCTestCase {
    func testFourTabsAndHomeToolsMatchBuild222() {
        let app=XCUIApplication();app.launchArguments=["--danper-shell-probe"]
        app.launch()
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:10))
        XCTAssertFalse(app.tabBars.firstMatch.exists,"La cápsula no debe duplicar una barra nativa")
        for (id,label) in [("home","Inicio"),("history","Historial"),("drafts","Borradores"),("settings","Ajustes")] {
            let button=app.buttons["premium-tab-"+id]
            XCTAssertTrue(button.exists);XCTAssertEqual(button.label,label)
        }
        let hour=Calendar.current.component(.hour,from:Date())
        let greeting=hour>=5 && hour<12 ? "Buenos días ☀️" : hour>=12 && hour<19 ? "Buenas tardes 🌤️":"Buenas noches 🌙"
        XCTAssertTrue(app.staticTexts[greeting].exists)
        XCTAssertFalse(app.staticTexts["Bienvenido"].exists)
        XCTAssertTrue(app.descendants(matching:.any)["premium-metric-month"].exists)
        XCTAssertTrue(app.buttons["demo-home-new-attention"].exists)
        let scroll=app.scrollViews.firstMatch
        for name in ["Trabajadores","Kardex","Estadísticas","Indicadores"] {
            let action=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@",name+":")).firstMatch
            if !action.isHittable {scroll.swipeUp()}
            XCTAssertTrue(action.waitForExistence(timeout:3),"Falta el acceso \(name)")
        }
        app.buttons["premium-tab-settings"].tap()
        XCTAssertTrue(app.otherElements["premium-app-version"].exists || app.staticTexts["DANPER Salud Móvil"].exists)
    }
}
