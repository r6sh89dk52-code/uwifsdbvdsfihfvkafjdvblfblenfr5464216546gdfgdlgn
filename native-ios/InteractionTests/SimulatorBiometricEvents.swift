import XCTest
import CoreFoundation

/// Test-runner coordination only. The host reports the real active sensor;
/// only the existing test step posts its intended simulator event.
enum SimulatorBiometricEvents {
    private static var lastGeneration=0
    static func send(_ event:String,file:StaticString = #filePath,line:UInt = #line) {
        guard ["match","nomatch"].contains(event) else {XCTFail("Evento no permitido",file:file,line:line);return}
        let base=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
            .appendingPathComponent("DANPER_BIOMETRIC_READY",isDirectory:true)
        let id=UUID().uuidString
        do {
            try FileManager.default.createDirectory(at:base,withIntermediateDirectories:true)
            let request:[String:Any]=["id":id,"event":event,"minimumGeneration":lastGeneration+1]
            try JSONSerialization.data(withJSONObject:request).write(to:base.appendingPathComponent("request.json"),options:.atomic)
            var acknowledgement:[String:Any]?
            let springboard=XCUIApplication(bundleIdentifier:"com.apple.springboard")
            let ready=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
                if let data=try? Data(contentsOf:base.appendingPathComponent("ready.json")),
                   let value=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],
                   value["id"] as? String == id,value["ready"] as? Bool == true,
                   let generation=value["generation"] as? Int,generation>lastGeneration {
                    acknowledgement=value;return true
                }
                // Cold TCC can show Face ID permission after the old 5-second
                // poll. Handle that actual permission while awaiting the sensor.
                let alert=springboard.alerts.firstMatch
                if alert.exists {
                    let face=alert.staticTexts.matching(NSPredicate(format:"label CONTAINS[c] %@ AND label CONTAINS[c] %@","Face","ID")).firstMatch
                    let allow=alert.buttons.matching(NSPredicate(format:"label IN %@",["Allow","Permitir","OK"])).firstMatch
                    if face.exists && allow.exists && allow.isHittable {allow.tap()}
                }
                return false
            },object:nil)
            let result=XCTWaiter.wait(for:[ready],timeout:20)
            XCTAssertEqual(result,.completed,"Esperar al sensor REAL del simulador; ejecuta el harness de scripts/glass-audit",file:file,line:line)
            guard result == .completed,let ack=acknowledgement,let generation=ack["generation"] as? Int else{return}
            lastGeneration=generation
            let evidence=XCTAttachment(string:String(data:try JSONSerialization.data(withJSONObject:ack,options:.sortedKeys),encoding:.utf8) ?? "")
            evidence.name="Biometric-sensor-ready-"+event;evidence.lifetime = .keepAlways
            XCTContext.runActivity(named:"Sensor listo antes de "+event) {$0.add(evidence)}
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(rawValue:("com.apple.BiometricKit_Sim.pearl."+event) as CFString),nil,nil,true)
        } catch {XCTFail("No se pudo coordinar el sensor: "+String(describing:error),file:file,line:line)}
    }
}
