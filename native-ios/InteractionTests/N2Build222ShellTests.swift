import XCTest

/// Build 222 shell contract, exercised without patient data, Keychain or Face ID.
/// Launches the DEBUG-only SwiftUI dashboard fixture rather than the clinical UI.
final class N2Build222ShellTests:XCTestCase {
    func testFourTabsAndHomeToolsMatchBuild222() {
        let app=XCUIApplication()
        app.launchArguments=["--danper-shell-probe"]
        app.launch()

        let tabBar=app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout:10))

        let names=["Inicio","Registrar","Historial","Ajustes"]
        for name in names {
            XCTAssertTrue(tabBar.buttons[name].exists,"Falta la pestaña \(name)")
        }
        XCTAssertEqual(tabBar.buttons.count,4,
                       "La Build 222 tiene exactamente cuatro pestañas")

        XCTAssertTrue(app.staticTexts["Bienvenido, Felipe"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["Herramientas"].exists)

        let shortcuts=["Historial","Trabajadores","Pendientes","Alergias","Kardex","Exportar"]
        let scroll=app.scrollViews.firstMatch
        for name in shortcuts {
            let action=app.buttons.matching(
                NSPredicate(format:"label BEGINSWITH %@",name+":")
            ).firstMatch
            if !action.exists {scroll.swipeUp()}
            XCTAssertTrue(action.waitForExistence(timeout:3),
                          "No aparece el acceso \(name)")
        }
    }
}
