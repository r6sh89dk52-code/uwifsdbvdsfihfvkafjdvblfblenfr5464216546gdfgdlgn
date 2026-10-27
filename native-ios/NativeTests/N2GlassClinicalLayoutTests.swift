import XCTest
import SwiftUI
import UIKit
@testable import DANPERNative

/// Real SwiftUI rendering evidence only; these tests never open a clinical vault
/// or simulate successful biometric authentication.
@MainActor final class N2GlassClinicalLayoutTests:XCTestCase {
    private func capture<V:View>(_ view:V,name:String,dark:Bool,
                                 size:CGSize=CGSize(width:393,height:852),
                                 accessible:Bool=false) async throws {
        let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
        let host=UIHostingController(rootView:view
            .environment(\.scenePhase,.active)
            .environment(\.colorScheme,dark ? .dark : .light)
            .environment(\.accessibilityReduceMotion,true)
            .environment(\.dynamicTypeSize,accessible ? .accessibility3 : .large)
            .preferredColorScheme(dark ? .dark : .light))
        let window=UIWindow(windowScene:scene)
        window.frame=CGRect(origin:.zero,size:size)
        window.windowLevel = .alert + 1
        window.overrideUserInterfaceStyle=dark ? .dark : .light
        host.overrideUserInterfaceStyle=window.overrideUserInterfaceStyle
        window.rootViewController=host
        window.makeKeyAndVisible()
        defer {window.isHidden=true}
        host.view.frame=window.bounds
        host.view.layoutIfNeeded()
        try await Task.sleep(for:.milliseconds(500))
        let image=UIGraphicsImageRenderer(bounds:window.bounds).image { _ in
            window.drawHierarchy(in:window.bounds,afterScreenUpdates:true)
        }
        XCTAssertGreaterThan(image.pngData()?.count ?? 0,5000)
        let attachment=XCTAttachment(image:image)
        attachment.name=name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testAccessInitialVerifyingRetryErrorLightDark() async throws {
        for dark in [false,true] {
            for state in ["initial","verifying","error"] {
                try await capture(DanperAccessView(unlocking:state == "verifying",
                    canRetry:state == "error",error:state == "error" ? "Autenticación cancelada" : "",
                    onUnlock:{}),name:"Glass-Access-\(state)-\(dark ? "dark" : "light")",dark:dark)
            }
        }
    }
    func testProtectedHomeLightDark() async throws {
        // Existing layout-only initializer prevents any vault reads.
        for dark in [false,true] {
            try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(0,7,0)),
                name:"Glass-Home-\(dark ? "dark" : "light")",dark:dark)
        }
    }
    func testSmallScreenAndAccessibility() async throws {
        try await capture(DanperAccessView(unlocking:false,canRetry:true,
            error:"No se pudo verificar tu identidad",onUnlock:{}),
            name:"Glass-Access-small-accessible",dark:true,
            size:CGSize(width:375,height:667),accessible:true)
        try await capture(N2ClinicalWorkspaceRootView(layoutCounts:(12,123,4)),
            name:"Glass-Home-accessible",dark:true,accessible:true)
    }
}
