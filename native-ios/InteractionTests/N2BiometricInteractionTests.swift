import XCTest
import CoreFoundation

final class N2BiometricInteractionTests:XCTestCase {
    override func tearDownWithError() throws {
        for (name, app) in [("DANPER", XCUIApplication()),
                            ("SpringBoard", XCUIApplication(bundleIdentifier:"com.apple.springboard")),
                            ("LocalAuthentication", XCUIApplication(bundleIdentifier:"com.apple.CoreAuthUI"))] {
            let tree=XCTAttachment(string:app.debugDescription)
            tree.name="diagnostic-"+name+"-hierarchy";tree.lifetime = .keepAlways;add(tree)
        }
        let screen=XCTAttachment(screenshot:XCUIScreen.main.screenshot())
        screen.name="diagnostic-final-screen";screen.lifetime = .keepAlways;add(screen)
        try super.tearDownWithError()
    }

    private func biometric(_ result:String) {
        SimulatorBiometricEvents.send(result)
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
    }
    func testAutomaticBiometryCancellationRetryAndForeground() {
        #if !targetEnvironment(simulator)
        XCTFail("Esta prueba usa exclusivamente biometría simulada; no valida Face ID físico")
        return
        #endif
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-danper.native.onboarding.v1.finished","YES"]
        app.launch()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let checking=app.staticTexts["Verificando identidad…"]
        let permission=springboard.alerts.buttons.matching(NSPredicate(format:"label IN %@",["OK","Allow","Permitir"])).firstMatch
        if permission.waitForExistence(timeout:8) {permission.tap()}
        XCTAssertTrue(checking.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Autenticacion-automatica-sin-tocar-ingresar")
        Thread.sleep(forTimeInterval:2)
        biometric("nomatch")
        let cancelPredicate=NSPredicate(format:"label ==[c] %@ OR label ==[c] %@","Cancel","Cancelar")
        let hosts=[springboard,app,XCUIApplication(bundleIdentifier:"com.apple.CoreAuthUI")]
        var cancel:XCUIElement?
        let shown=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            cancel=hosts.map {$0.buttons.matching(cancelPredicate).firstMatch}
                .first {$0.exists && $0.isHittable}
            return cancel != nil
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[shown],timeout:10),.completed,
            "Debe existir un botón Cancelar real del sistema, sin inyectar éxito")
        XCTAssertNotNil(cancel)
        cancel!.tap()
        let retry=app.buttons["Reintentar Face ID"]
        XCTAssertTrue(retry.waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Autenticacion-cancelada-reintento-opcional")
        let noLoop=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == true"),object:checking)
        noLoop.isInverted=true
        XCTAssertEqual(XCTWaiter.wait(for:[noLoop],timeout:2),.completed)
        retry.tap()
        XCTAssertTrue(checking.waitForExistence(timeout:5))
        Thread.sleep(forTimeInterval:2)
        biometric("match")
        let source=app.buttons["clinical-first-run-import-personal"]
        let usable=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            let home=app.buttons["premium-tab-home"]
            return (source.exists && source.isHittable) || (home.exists && home.isHittable)
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[usable],timeout:15),.completed,
            "La autenticación debe retirar la cobertura y permitir interacción real: "+app.debugDescription)
        capture(app,"Autenticacion-simulada-aceptada-seleccion-fuente")
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for:.runningBackground,timeout:10))
        app.activate()
        XCTAssertTrue(checking.waitForExistence(timeout:10),app.debugDescription)
        Thread.sleep(forTimeInterval:2)
        biometric("match")
        let foregroundUsable=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            let home=app.buttons["premium-tab-home"]
            return (source.exists && source.isHittable) || (home.exists && home.isHittable)
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[foregroundUsable],timeout:15),.completed,
            "La autenticación debe retirar la cobertura y permitir interacción real: "+app.debugDescription)
    }
}
