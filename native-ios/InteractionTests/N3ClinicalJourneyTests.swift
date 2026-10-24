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
        XCTAssertTrue(element.waitForExistence(timeout:10),app.debugDescription)
        if element.elementType == .switch,app.keyboards.firstMatch.exists {
            let dismiss=app.buttons["danper-dismiss-keyboard"].firstMatch
            if dismiss.exists {dismiss.tap()}
        }
        for _ in 0..<10 {
            let content=element.identifier.hasPrefix("choice-") || element.identifier.hasPrefix("medication-row-") ||
                element.identifier=="add-clinical-product" || element.elementType == .textField || element.elementType == .textView ||
                (element.elementType == .button && element.frame.width>300 && element.identifier != "inventory-save-lot")
            let footer=app.buttons["Anterior"]
            let tab=app.tabBars.firstMatch
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
        XCTAssertTrue(app.staticTexts["Verificando identidad…"].waitForExistence(timeout:15),app.debugDescription)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
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
    private func reconcileAlcohol(_ app:XCUIApplication) {
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
        XCTAssertTrue(app.buttons["pending-physical-16000019"].waitForExistence(timeout:10),app.debugDescription)
        tap(app.buttons["pending-physical-16000019"],in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Lote compatible")).firstMatch,in:app)
        tap(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","N3-ALCOHOL")).firstMatch,in:app)
        enter(app.textFields["Cantidad física realmente utilizada"],"5",in:app)
        tap(app.switches["Abrí un nuevo envase (declaración explícita)"],in:app)
        enter(app.textFields["Responsable"],"OPERADOR DE PRUEBA N3",in:app)
        enter(app.descendants(matching:.any)["Evidencia y motivo"],"Consumo ficticio de 5 mL verificado durante la atención",in:app)
        tap(app.switches["Confirmo la cantidad física y la evidencia"],in:app)
        capture(app,"Conciliacion-evidencia-fisica")
        tap(app.buttons["Verificar y conciliar sin duplicar atención"],in:app)
        let resolved=XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.buttons["pending-physical-16000019"])
        XCTAssertEqual(XCTWaiter.wait(for:[resolved],timeout:10),.completed,app.debugDescription)
        capture(app,"Resultado-conciliado")
    }
    private func inventory(_ app:XCUIApplication) {
        tap(app.tabBars.buttons["Ajustes"],in:app)
        if !app.staticTexts["Medicamentos y existencias"].exists {
            tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Inventario y lotes")).firstMatch,in:app)
        }
    }
    private func registerReuse(_ app:XCUIApplication) {
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
        enter(app.descendants(matching:.any)["clinical-diagnosis-input"],"PRUEBA REUTILIZACION ENVASE N3",in:app)
        tap(app.buttons["Siguiente"],in:app)
        addMedication(app,query:"ALCOHOL 96",code:"16000019")
        woundProcedure(app,name:"ALCOHOL 96")
        tap(app.buttons["choice-¿Se envió la foto?"],in:app)
        tap(app.buttons["No se envió"],in:app)
        tap(app.buttons["Siguiente"],in:app)
        tap(app.buttons["Guardar atención"],in:app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@",
            "Kardex R: 0 · Uso de envase abierto")).firstMatch.waitForExistence(timeout:10),app.debugDescription)
        XCTAssertFalse(app.buttons["pending-physical-16000019"].exists)
        capture(app,"Segunda-atencion-envase-abierto-R0")
    }
    @discardableResult private func addLot(_ app:XCUIApplication,code:String,query:String,reference:String,quantity:String,expiry:String,capacity:String?=nil)->Bool {
        if app.descendants(matching:.any)["inventory-lot-"+reference].waitForExistence(timeout:2) {return false}
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
        XCTAssertTrue(app.staticTexts["Existencias registradas correctamente en el Kardex único."].waitForExistence(timeout:10),app.debugDescription)
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
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Inicio-clinico-protegido")
        inventory(app)
        addLot(app,code:"E-22",query:"Paracetamol",reference:"N3-PARA-A",quantity:"3",expiry:"201030")
        addLot(app,code:"E-22",query:"Paracetamol",reference:"N3-PARA-B",quantity:"8",expiry:"201031")
        let alcoholNew=addLot(app,code:"E-86",query:"Alcohol",reference:"N3-ALCOHOL",quantity:"2",expiry:"201032",capacity:"1000")
        if alcoholNew {
            let seconds=Calendar.current.component(.second,from:Date())
            Thread.sleep(forTimeInterval:Double(61-seconds))
        }
        tap(app.tabBars.buttons["Registrar"],in:app)
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
        XCTAssertTrue(app.staticTexts["Atención registrada"].firstMatch.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Atencion-guardada-con-pendientes")
        if app.buttons["pending-physical-16000019"].waitForExistence(timeout:2) {
            reconcileAlcohol(app)
        } else {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@",
                "Kardex R: 0 · Uso de envase abierto")).firstMatch.exists,app.debugDescription)
        }
        registerReuse(app)
        inventory(app)
        capture(app,"Inventario-despues-de-conciliar")
        tap(app.tabBars.buttons["Historial"],in:app)
        XCTAssertTrue(app.staticTexts["PRUEBA CLINICA FICTICIA N3"].firstMatch.waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Historial-persistido")
        app.terminate()
        app.launchArguments += ["-danper.appearance","dark"]
        app.launch();authenticate(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout:15),app.debugDescription)
        capture(app,"Persistencia-tras-relanzar")
        inventory(app)
        XCTAssertTrue(app.staticTexts["Envases abiertos declarados: 1"].waitForExistence(timeout:10),app.debugDescription)
        tap(app.buttons["Declarar agotado, cerrado o descartado"].firstMatch,in:app)
        XCTAssertTrue(app.navigationBars["Estado de envases"].waitForExistence(timeout:5))
        capture(app,"Declaracion-manual-estado-envase")
        tap(app.buttons["Cancelar"],in:app)
        capture(app,"Envase-abierto-persistido")
        tap(app.tabBars.buttons["Inicio"],in:app)
        tap(app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Kardex")).firstMatch,in:app)
        XCTAssertTrue(app.staticTexts["Corte mensual · del día 9 al día 8"].waitForExistence(timeout:10),app.debugDescription)
        capture(app,"Kardex-real-y-corte-mensual")
    }
}
