"""Instrument the diagnostic UI RUNNER only, identical for both app binaries."""
from pathlib import Path

END='''        // Profiling-only runner: retain the actual app until the recorder
        // has finalized. All original clinical assertions above already ran.
        let ack=FileManager.default.temporaryDirectory.appendingPathComponent(
            "danper-profile-"+UUID().uuidString+".json")
        defer {try? FileManager.default.removeItem(at:ack)}
        FileHandle.standardOutput.write(Data(("DANPER_PROFILE_COMPLETED_ACK "+ack.path+"\\n").utf8))
        let finalized=XCTNSPredicateExpectation(predicate:NSPredicate {_,_ in
            guard let data=try? Data(contentsOf:ack) else{return false}
            return (try? JSONSerialization.jsonObject(with:data)) != nil
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[finalized],timeout:240),.completed,
            "El recorder debe finalizar realmente antes de que XCTest cierre la app")
        guard let data=try? Data(contentsOf:ack),
              let response=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any]
        else {XCTFail("Falta el resultado real del recorder");return}
        XCTAssertEqual(response["recorderExit"] as? Int,0,"Una traza fallida no aprueba el perfil")
'''

def instrument(source):
    marker='    func testEmptyRosterSearchAndConfirmedAllergySaveSurviveDraftAndReopen() {'
    assert source.count(marker)==1
    prefix,body=source.split(marker)
    assert body.count('        app.launch()')==1
    body=body.replace('        app.launch()', '''        // The host already launched this same DEMO PID and attached Instruments.
        // Activate it without replacing the sealed app process.
        app.activate()
        XCTAssertEqual(app.state,.runningForeground)
        let identity=app.debugDescription.components(separatedBy:"\\n").first ?? ""
        FileHandle.standardOutput.write(Data(("DANPER_PROFILE_ACTIVATED_APPLICATION "+identity+"\\n").utf8))''')
    trigger='        tap(save,in:app)'
    assert body.count(trigger)==1
    body=body.replace(trigger,'        let profileSaveStart=ProcessInfo.processInfo.systemUptime\n'+trigger)
    confirmed='        XCTAssertTrue(app.staticTexts["Alergias revisadas y guardadas"].waitForExistence(timeout:20),app.debugDescription)'
    assert body.count(confirmed)==1
    body=body.replace(confirmed,confirmed+'\n        FileHandle.standardOutput.write(Data(("DANPER_PROFILE_SAVE_INTERVAL_MS \"+String((ProcessInfo.processInfo.systemUptime-profileSaveStart)*1000)+"\\n").utf8))')
    ending='        XCTAssertTrue(app.buttons["choice-Revisión de alergias"].label.contains("Niega alergias conocidas"),app.debugDescription)\n    }'
    assert body.count(ending)==1
    body=body.replace(ending,ending[:-5]+END+'    }')
    result=prefix+marker+body
    if 'import Foundation' not in result:result=result.replace('import XCTest','import XCTest\nimport Foundation',1)
    return result

if __name__=='__main__':
    p=Path('native-ios/InteractionTests/N2AllergySaveInteractionTests.swift')
    p.write_text(instrument(p.read_text()))
