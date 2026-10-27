import XCTest
import CoreFoundation

final class N3ClinicalJourneyTests:XCTestCase {
    private func match() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue:"com.apple.BiometricKit_Sim.pearl.match" as CFString),nil,nil,true)
    }
    private func capture(_ app:XCUIApplication,_ name:String) {
        print("N3 "+name+"\n"+app.debugDescription)
        let attachment=XCTAttachment(screenshot:app.screenshot())
        attachment.name="N3-"+name;attachment.lifetime = .keepAlways;add(attachment)
    }
    private func tap(_ element:XCUIElement,in app:XCUIApplication) {
        if !element.exists && app.keyboards.firstMatch.exists {
            let hide=app.buttons["danper-dismiss-keyboard"].firstMatch
            if app.keyboards.firstMatch.exists && hide.exists {hide.tap()}
        }
        XCTAssertTrue(element.waitForExistence(timeout:10),app.debugDescription)
        if element.elementType == .switch,app.keyboards.firstMatch.exists {
            let dismiss=app.buttons["danper-dismiss-keyboard"].firstMatch
            if dismiss.exists {dismiss.tap()}
        }
        for _ in 0..<10 {
            let content=element.identifier.hasPrefix("choice-") || element.identifier.hasPrefix("medication-row-") ||
                element.identifier=="add-clinical-product" || element.label=="Declarar agotado, cerrado o descartado" || element.elementType == .textField || element.elementType == .textView ||
                (element.elementType == .button && element.frame.width>300 && element.identifier != "inventory-save-lot" && element.identifier != "attention-step-actions")
            let footer=app.buttons["Anterior"]
            let tab=app.buttons["premium-tab-home"]
            let bottom=footer.exists && footer.isHittable ? footer.frame.minY-12 :
                (tab.exists && tab.isHittable ? tab.frame.minY-12:app.frame.maxY-60)
            let visible = !content || (element.frame.minY>140 && element.frame.maxY<bottom)
            if element.isHittable && visible {break}
            let dismiss=app.buttons["danper-dismiss-keyboard"].firstMatch
            if app.keyboards.firstMatch.exists && dismiss.exists {dismiss.tap()}
            else {
                let above=element.frame.minY<140
                app.coordinate(withNormalizedOffset:CGVector(dx:0.03,dy:above ? 0.25:0.55))
                    .press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.03,dy:above ? 0.65:0.25)))
            }
        }
        XCTAssertTrue(element.isHittable,app.debugDescription)
        XCTAssertTrue(element.isEnabled,app.debugDescription)
        if element.label=="Verificar y conciliar sin duplicar atención" {
            XCTAssertEqual(app.switches["Abrí un nuevo envase (declaración explícita)"].value as? String,"1")
        }
        if element.elementType == .switch {
            element.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.5)).tap()
            let enabled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","1"),object:element)
            XCTAssertEqual(XCTWaiter.wait(for:[enabled],timeout:3),.completed,app.debugDescription)
        } else if element.identifier.hasPrefix("choice-") {
            element.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).tap()
        } else {element.tap()}
    }
    private func enter(_ element:XCUIElement,_ text:String,in app:XCUIApplication) {
        tap(element,in:app)
        if let value=element.value as? String,value != element.placeholderValue,!value.isEmpty {
            element.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:value.count))
        }
        element.typeText(text)
    }
    private func authenticate(_ app:XCUIApplication) {
        let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
        let permission=springboard.alerts.buttons.matching(NSPredicate(format:"label IN %@",["OK","Allow","Permitir"])).firstMatch
        if permission.waitForExistence(timeout:5) {permission.tap()}
        XCTAssertTrue(app.staticTexts["Verificando identidad…"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.buttons["premium-tab-home"].exists)
        Thread.sleep(forTimeInterval:2);match()
    }
    private func addMedication(_ app:XCUIApplication,query:String,code:String) {
        if !app.textFields["inline-catalog-query"].exists {tap(app.buttons["add-clinical-product"],in:app)}
        enter(app.textFields["inline-catalog-query"],query,in:app)
        tap(app.buttons["suggestion-"+code],in:app)
    }
    private func woundProcedure(_ app:XCUIApplication,name:String) {
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-",name)).firstMatch,in:app)
        tap(app.buttons["choice-Procedimiento"],in:app)
        tap(app.buttons["Curacion De Herida"],in:app)
    }
    private func linkAlcohol(_ app:XCUIApplication) {
        if app.buttons["pending-mapping-16000019"].waitForExistence(timeout:2) {
        tap(app.buttons["pending-mapping-16000019"],in:app)
        enter(app.textFields["Buscar presentación física"],"ALCOHOL",in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Presentación física")).firstMatch,in:app)
        tap(app.buttons["ALCOHOL 1 LT · FCO"],in:app)
        enter(app.textFields["Unidades físicas por unidad clínica"],"1000",in:app)
        enter(app.textFields["Responsable de la verificación"],"OPERADOR DE PRUEBA N3",in:app)
        enter(app.descendants(matching:.any)["Evidencia: concentración, presentación y conversión"],"Conversión de fixture: un LT contiene 1000 mL; no es equivalencia para uso real",in:app)
        tap(app.switches["Confirmo la equivalencia y conversión verificadas"],in:app)
        tap(app.buttons["Guardar correspondencia operativa"],in:app)
        let closed=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.navigationBars["Vinculación operativa"])
        XCTAssertEqual(XCTWaiter.wait(for:[closed],timeout:10),.completed,app.debugDescription)
        }
        // The saved visit has no opening declaration. Linking a product
        // must not invent one or mark that original pending use as deducted.
        XCTAssertTrue(app.buttons["pending-container-stock-16000019"].waitForExistence(timeout:10),app.debugDescription)
        XCTAssertFalse(app.buttons["pending-physical-16000019"].exists)
        capture(app,"Pendiente-original-con-ruta-directa-al-inventario")
    }
    private func declareContainers(_ app:XCUIApplication,opened:Bool,expectedCount:Int?=nil) {
        var declarations=0
        let choice=opened ? "Sí, abrí uno nuevo · Kardex 1" : "No, usé el abierto · Kardex 0"
        while app.alerts.buttons[choice].waitForExistence(timeout:2) {
            declarations+=1
            XCTAssertLessThanOrEqual(declarations,2,app.debugDescription)
            if declarations>2 {return}
            tap(app.alerts.buttons[choice],in:app)
        }
        if let expectedCount {XCTAssertEqual(declarations,expectedCount,app.debugDescription)}
    }
    private func inventory(_ app:XCUIApplication) {
        if app.buttons["premium-close-attention"].exists {
            tap(app.buttons["premium-close-attention"],in:app)
        }
        tap(app.buttons["premium-tab-settings"],in:app)
        if !app.staticTexts["Medicamentos y existencias"].exists {
            tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Inventario y lotes")).firstMatch,in:app)
        }
    }
    private func registerContainerUse(_ app:XCUIApplication,opened:Bool,expectBlocked:Bool=false) {
        tap(app.buttons["Nueva atención"],in:app)
        enter(app.textFields["attention-worker-dni"],"00000031",in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["choice-Revisión de alergias"],in:app)
        tap(app.buttons["Niega alergias conocidas"],in:app)
        tap(app.buttons["Guardar revisión de alergias"],in:app)
        tap(app.buttons["choice-Tipo de atención"],in:app)
        tap(app.buttons["Enfermedad"],in:app)
        tap(app.buttons["choice-Sistema afectado"],in:app)
        tap(app.buttons["Respiratorio"],in:app)
        enter(app.descendants(matching:.any)["clinical-diagnosis-input"],opened ? "PRUEBA APERTURA ENVASE N3" : "PRUEBA REUTILIZACION ENVASE N3",in:app)
        tap(app.buttons["Siguiente"],in:app)
        addMedication(app,query:"ALCOHOL 96",code:"16000019")
        woundProcedure(app,name:"ALCOHOL 96")
        tap(app.buttons["choice-¿Se envió la foto?"],in:app)
        tap(app.buttons["No se envió"],in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["Guardar atención"],in:app)
        declareContainers(app,opened:opened,expectedCount:1)
        if expectBlocked {
            // The fixture tracks a measured remainder. A second opening must
            // not silently exhaust that first bottle or create another debit.
            XCTAssertTrue(app.buttons["pending-container-stock-16000019"].waitForExistence(timeout:15),app.debugDescription)
            XCTAssertFalse(app.staticTexts["Kardex R: 1"].exists)
            capture(app,"Apertura-adicional-bloqueada-por-volumen-medido")
        } else {
            let result=opened ? "Kardex R: 1" : "Kardex R: 0 · Reutilización declarada; ninguna caja nueva descontada"
            XCTAssertTrue(app.staticTexts[result].firstMatch.waitForExistence(timeout:15),app.debugDescription)
            XCTAssertFalse(app.buttons["pending-container-stock-16000019"].exists)
            capture(app,opened ? "Nueva-apertura-explicita-R1" : "Reutilizacion-explicita-R0")
        }
        XCTAssertFalse(app.buttons["pending-physical-16000019"].exists)
    }
    @discardableResult private func addLot(_ app:XCUIApplication,code:String,query:String,reference:String,quantity:String,expiry:String,capacity:String?=nil)->Bool {
        let existing=app.descendants(matching:.any)["inventory-lot-"+reference].firstMatch
        let group=app.descendants(matching:.any)["inventory-group-"+code].firstMatch
        if !existing.exists && group.exists {tap(group,in:app)}
        if existing.waitForExistence(timeout:2) {return false}
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Registrar medicamento")).firstMatch,in:app)
        enter(app.textFields["inventory-select-product"],query,in:app)
        tap(app.buttons["inventory-result-"+code],in:app)
        XCTAssertTrue(app.descendants(matching:.any)["inventory-verified-unit"].waitForExistence(timeout:5),app.debugDescription)
        enter(app.textFields["Número del lote"],reference,in:app)
        tap(app.buttons["Tiene fecha de vencimiento"],in:app)
        enter(app.textFields["inventory-expiry-text"],expiry,in:app)
        XCTAssertEqual(app.textFields["inventory-expiry-text"].value as? String,
                       "\(expiry.prefix(2))/\(expiry.dropFirst(2).prefix(2))/\(expiry.suffix(2))")
        if let capacity {
            XCTAssertFalse(app.buttons["inventory-save-lot"].isEnabled)
            enter(app.textFields["inventory-container-capacity"],capacity,in:app)
            enter(app.descendants(matching:.any)["inventory-capacity-evidence"],"Etiqueta ficticia verificada: "+capacity+" mL",in:app)
            tap(app.buttons["Confirmo la capacidad real del envase"],in:app)
        }
        enter(app.textFields["inventory-single-quantity"],quantity,in:app)
        tap(app.buttons["inventory-save-lot"],in:app)
        XCTAssertTrue(app.alerts["¿Qué representa esta cantidad?"].waitForExistence(timeout:5),app.debugDescription)
        tap(app.alerts.buttons["Stock físico que tengo hoy"],in:app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@",
            "Stock físico actual registrado. Stock inicial estimado del día 9:")).firstMatch.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Lote-"+reference)
        return true
    }
    func testProtectedClinicalJourneyAndRelaunch() {
        #if !targetEnvironment(simulator)
        XCTFail("N3 solo admite un Simulator aislado sin datos clínicos reales")
        return
        #endif
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-danper.native.onboarding.v1.finished","YES"]
        app.launch();authenticate(app)
        let manual=app.buttons["clinical-first-run-manual-worker"]
        if manual.waitForExistence(timeout:5) {
            tap(manual,in:app)
            enter(app.textFields["first-manual-worker-dni"],"00000031",in:app)
            enter(app.textFields["first-manual-worker-name"],"PERSONAL AUTORIZADO DE PRUEBA N3",in:app)
            tap(app.buttons["choice-Sede verificada"],in:app)
            tap(app.buttons["Fundo La Venturosa"],in:app)
            tap(app.buttons["first-manual-worker-activate"],in:app)
            tap(app.buttons["Crear e ingresar primer trabajador"],in:app)
            Thread.sleep(forTimeInterval:2);match()
            XCTAssertTrue(app.buttons["Volver para entrar a DANPER"].waitForExistence(timeout:15),app.debugDescription)
            capture(app,"Fuente-clinica-creada")
            tap(app.buttons["Volver para entrar a DANPER"],in:app)
        }
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Inicio-clinico-protegido")
        inventory(app)
        addLot(app,code:"E-22",query:"Paracetamol",reference:"N3-PARA-A",quantity:"3",expiry:"201030")
        addLot(app,code:"E-22",query:"Paracetamol",reference:"N3-PARA-B",quantity:"8",expiry:"201031")
        let alcoholNew=addLot(app,code:"E-86",query:"Alcohol",reference:"N3-ALCOHOL",quantity:"2",expiry:"201032",capacity:"1000")
        if alcoholNew {
            let seconds=Calendar.current.component(.second,from:Date())
            Thread.sleep(forTimeInterval:Double(61-seconds))
        }
        tap(app.buttons["premium-tab-home"],in:app)
        tap(app.buttons["clinical-home-new-attention"],in:app)
        enter(app.textFields["attention-worker-dni"],"00000031",in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["choice-Revisión de alergias"],in:app)
        tap(app.buttons["Niega alergias conocidas"],in:app)
        tap(app.buttons["Guardar revisión de alergias"],in:app)
        tap(app.buttons["choice-Tipo de atención"],in:app)
        tap(app.buttons["Enfermedad"],in:app)
        tap(app.buttons["choice-Sistema afectado"],in:app)
        tap(app.buttons["Respiratorio"],in:app)
        capture(app,"Evaluacion-campos-reales")
        enter(app.descendants(matching:.any)["clinical-diagnosis-input"],"PRUEBA CLINICA FICTICIA N3",in:app)
        tap(app.buttons["Siguiente"],in:app)
        capture(app,"Tratamiento-real")
        addMedication(app,query:"Paracetamol",code:"16000182")
        tap(app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@ AND label CONTAINS %@","medication-row-","PARACETAMOL")).firstMatch,in:app)
        enter(app.textFields["clinical-quantity-16000182"],"5",in:app)
        addMedication(app,query:"ALCOHOL 96",code:"16000019")
        woundProcedure(app,name:"ALCOHOL 96")
        addMedication(app,query:"GASA",code:"16000116")
        woundProcedure(app,name:"GASA ESTERILIZADA")
        if app.buttons["choice-¿Se envió la foto?"].exists {
            tap(app.buttons["choice-¿Se envió la foto?"],in:app)
            tap(app.buttons["No se envió"],in:app)
        }
        tap(app.buttons["Siguiente"],in:app)
        capture(app,"Revision-final-real")
        tap(app.buttons["Guardar atención"],in:app)
        declareContainers(app,opened:true)
        XCTAssertTrue(app.staticTexts["Atención registrada"].firstMatch.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Atencion-guardada-con-pendientes")
        XCTAssertTrue(app.buttons["pending-mapping-16000116"].exists ||
                      app.buttons["pending-stock-16000116"].exists,app.debugDescription)
        var alreadyOpened=false
        if app.buttons["pending-mapping-16000019"].waitForExistence(timeout:2) {
            linkAlcohol(app)
        } else {
            XCTAssertTrue(app.staticTexts["Kardex R: 1"].firstMatch.exists,app.debugDescription)
            alreadyOpened=true
        }
        registerContainerUse(app,opened:true,expectBlocked:alreadyOpened)
        registerContainerUse(app,opened:false)
        inventory(app)
        capture(app,"Inventario-despues-de-conciliar")
        tap(app.buttons["premium-tab-history"],in:app)
        XCTAssertTrue(app.staticTexts["PRUEBA CLINICA FICTICIA N3"].firstMatch.waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Historial-persistido")
        app.terminate()
        // Existing data must bypass onboarding even if its old preference is absent.
        app.launchArguments=["-danper.native.onboarding.v1.finished","NO","-danper.appearance","dark"]
        app.launch();authenticate(app)
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.staticTexts["clinical-empty-setup"].exists)
        XCTAssertFalse(app.buttons["clinical-first-run-manual-worker"].exists)
        capture(app,"Persistencia-tras-relanzar")
        verifyPersistentInventoryAndKardex(app)
    }
    /// Uses the synthetic N3 source created by the preceding protected journey.
    func testRelaunchExistingClinicalSourceWithoutSetup() {
        #if !targetEnvironment(simulator)
        XCTFail("Prueba exclusiva de un Simulator aislado con los registros ficticios N3")
        return
        #endif
        continueAfterFailure=false
        let app=XCUIApplication()
        app.launchArguments=["-danper.native.onboarding.v1.finished","NO","-danper.appearance","dark"]
        app.launch();authenticate(app)
        XCTAssertTrue(app.buttons["premium-tab-home"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.staticTexts["clinical-empty-setup"].exists)
        XCTAssertFalse(app.buttons["clinical-first-run-manual-worker"].exists)
        capture(app,"Fuente-existente-con-onboarding-desactivado")
        verifyPersistentInventoryAndKardex(app)
    }
    private func verifyPersistentInventoryAndKardex(_ app:XCUIApplication) {
        inventory(app)
        // DisclosureGroup flattens its children in the accessibility tree.
        // Verify the unique fixture's visible lot and its persisted opening.
        let alcoholLot=app.staticTexts["Lote: N3-ALCOHOL"]
        if !alcoholLot.exists {
            tap(app.buttons["inventory-group-E-86"].firstMatch,in:app)
        }
        XCTAssertTrue(alcoholLot.waitForExistence(timeout:10),app.debugDescription)
        XCTAssertTrue(app.staticTexts["Abiertos: 1"].waitForExistence(timeout:10),app.debugDescription)
        tap(app.buttons["Declarar agotado, cerrado o descartado"].firstMatch,in:app)
        XCTAssertTrue(app.navigationBars["Estado de envases"].waitForExistence(timeout:5))
        capture(app,"Declaracion-manual-estado-envase")
        tap(app.buttons["Cancelar"],in:app)
        capture(app,"Envase-abierto-persistido")
        tap(app.buttons["premium-tab-home"],in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Kardex")).firstMatch,in:app)
        XCTAssertTrue(app.staticTexts["Corte mensual · del día 9 al día 8"].waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Kardex-real-y-corte-mensual")
    }
}
