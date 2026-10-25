import XCTest
import SwiftUI
@testable import DANPERNative

final class N2WelcomeLayoutTests:XCTestCase {
    @MainActor func testExpiryPasteCorrectionAndCaret() {
        var value=""
        let entry=N2ExpiryTextField(text:Binding(get:{value},set:{value=$0}))
        let coordinator=entry.makeCoordinator()
        let field=UITextField()
        field.text=""
        XCTAssertFalse(coordinator.textField(field,shouldChangeCharactersIn:NSRange(location:0,length:0),replacementString:"201030"))
        XCTAssertEqual(field.text,"20/10/30")
        XCTAssertEqual(value,"20/10/30")
        XCTAssertFalse(coordinator.textField(field,shouldChangeCharactersIn:NSRange(location:3,length:2),replacementString:"12"))
        XCTAssertEqual(value,"20/12/30")
        if let selection=field.selectedTextRange {
            XCTAssertEqual(field.offset(from:field.beginningOfDocument,to:selection.start),5)
        } else {XCTFail("No se conservó el cursor")}
        XCTAssertFalse(coordinator.textField(field,shouldChangeCharactersIn:NSRange(location:8,length:0),replacementString:"9"))
        XCTAssertEqual(value,"20/12/30")
        XCTAssertFalse(coordinator.textField(field,shouldChangeCharactersIn:NSRange(location:0,length:0),replacementString:"x"))
        XCTAssertEqual(value,"20/12/30")
    }
    @MainActor func testWelcomeLightDarkAndAccessibleText() {
        for dark in [false,true] {
            for accessible in [false,true] {
                let view=DanperAccessView(unlocking:true,canRetry:false,error:"",onUnlock:{})
                    .environment(\.dynamicTypeSize,accessible ? .accessibility2:.large)
                    .preferredColorScheme(dark ? .dark:.light)
                let host=UIHostingController(rootView:view)
                let window=UIWindow(frame:CGRect(x:0,y:0,width:393,height:852))
                window.rootViewController=host
                window.makeKeyAndVisible()
                host.view.setNeedsLayout();host.view.layoutIfNeeded()
                RunLoop.main.run(until:Date().addingTimeInterval(0.3))
                XCTAssertEqual(host.view.bounds.width,393,accuracy:1)
                let renderer=UIGraphicsImageRenderer(bounds:host.view.bounds)
                let image=renderer.image {_ in host.view.drawHierarchy(in:host.view.bounds,afterScreenUpdates:true)}
                let attachment=XCTAttachment(image:image)
                attachment.name="bienvenida-\(dark ? "oscuro":"claro")-\(accessible ? "accesible":"normal")"
                attachment.lifetime = .keepAlways
                add(attachment)
                window.isHidden=true
            }
        }
    }
}
