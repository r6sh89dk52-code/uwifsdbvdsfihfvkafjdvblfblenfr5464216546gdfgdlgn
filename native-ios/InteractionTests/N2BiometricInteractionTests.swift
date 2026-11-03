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
    /// Consent to using Face ID is not identity authentication. This public
    /// UI setup handles the real first-use alert on an owned fresh Simulator.
    func testFaceIDPermissionDoesNotAuthenticateOrExposeClinicalData() {
        #if !targetEnvironment(simulator)
        XCTFail("Synthetic permission preparation requires an isolated Simulator")
        return
        #endif
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-danper.native.onboarding.v1.finished","YES"]
        app.launch()
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        // Match the owned system alert directly. Reading a descendant text
        // of alerts.firstMatch repeatedly asked AX for another subtree while
        // the actual TCC alert was still being presented on cold Simulator.
        let ownFaceID=springboard.alerts.matching(NSPredicate(format:
            "label CONTAINS[c] %@ AND label CONTAINS[c] %@ AND label CONTAINS[c] %@",
            "DANPER","Face","ID")).firstMatch
        var acceptedPermission=false
        var permissionDismissalSeconds:TimeInterval?
        func acceptOwnedPermission() {
            let allow=ownFaceID.buttons.matching(NSPredicate(format:"label IN %@",["OK","Allow","Permitir"])).firstMatch
            XCTAssertTrue(allow.waitForExistence(timeout:5))
            XCTAssertTrue(allow.isHittable)
            let permissionStarted=Date()
            allow.tap();acceptedPermission=true
            let dismissed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:ownFaceID)
            // Run 41521115084's recording shows the genuine TCC alert still
            // present 15 seconds after the tap and gone by 23 seconds. This
            // bounds only system consent acknowledgement, never identity or
            // the independent native cancellation case's 12s/18s deadlines.
            XCTAssertEqual(XCTWaiter.wait(for:[dismissed],timeout:30),.completed)
            permissionDismissalSeconds=Date().timeIntervalSince(permissionStarted)
        }
        if ownFaceID.waitForExistence(timeout:15) {acceptOwnedPermission()}
        let checking=app.staticTexts["Verificando identidad…"]
        let retry=app.buttons["Reintentar Face ID"]
        // The prompt can arrive after the first15s: run41684106094's
        // SpringBoard snapshot at35.77s had no alert, but its later capture
        // showed the real, unanswered permission covering the checking state.
        // Observe it during the ORIGINAL15s gate window too. Consent handling
        // keeps its original5s/30s budgets; discovery never gets a fresh15s.
        var latePermission=false
        let gateStarted=Date()
        let gated=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            if ownFaceID.exists {latePermission=true;return true}
            return checking.exists || retry.exists
        },object:nil)
        let gateResult=XCTWaiter.wait(for:[gated],timeout:15)
        XCTAssertEqual(gateResult,.completed,"The app must reach its genuine authentication gate or show its actual permission")
        if latePermission {
            let remaining=max(0,15-Date().timeIntervalSince(gateStarted))
            acceptOwnedPermission()
            let afterConsent=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
                checking.exists || retry.exists
            },object:nil)
            XCTAssertTrue(checking.exists || retry.exists ||
                XCTWaiter.wait(for:[afterConsent],timeout:remaining) == .completed,
                "Accepting permission must return to the genuine authentication gate")
        }
        let source=app.buttons["clinical-first-run-import-personal"]
        let home=app.buttons["premium-tab-home"]
        let noAccess=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            (source.exists && source.isHittable) || (home.exists && home.isHittable)
        },object:nil)
        noAccess.isInverted=true
        XCTAssertEqual(XCTWaiter.wait(for:[noAccess],timeout:2),.completed,
            "Accepting Face ID permission must not authenticate or expose clinical controls")
        let dismissalTiming=permissionDismissalSeconds.map{String($0)} ?? "not required"
        let proof=XCTAttachment(string:"permissionPromptAccepted=\(acceptedPermission); permissionDismissalObservedSeconds=\(dismissalTiming); biometricEventsSent=0; clinicalAccessGranted=false; SimulatorOnly=true")
        proof.name="FaceID-permission-is-not-authentication";proof.lifetime = .keepAlways;add(proof)
        // No match/nomatch event is sent. Termination releases this setup
        // context; the independent native case must still prove appCancel.
        app.terminate()
        XCTAssertTrue(app.wait(for:.notRunning,timeout:10))
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
        // iOS may suspend a backgrounded app before XCTest observes the
        // transient runningBackground state. Both are actual background;
        // foreground, unknown and termination must still fail this gate.
        var observedBackgroundStates=[String]()
        let backgrounded=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            let state=app.state
            observedBackgroundStates.append(String(describing:state))
            return state == .runningBackground || state == .runningBackgroundSuspended
        },object:nil)
        let backgroundResult=XCTWaiter.wait(for:[backgrounded],timeout:10)
        let stateEvidence=XCTAttachment(string:observedBackgroundStates.joined(separator:"\n"))
        stateEvidence.name="Actual-background-state-before-reauthentication"
        stateEvidence.lifetime = .keepAlways;add(stateEvidence)
        XCTAssertEqual(backgroundResult,.completed,
            "La app debe estar realmente en segundo plano o suspendida; estados: "+observedBackgroundStates.joined(separator:", "))
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
