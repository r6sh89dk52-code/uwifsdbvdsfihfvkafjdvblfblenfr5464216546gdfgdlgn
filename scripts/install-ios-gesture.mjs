/**
 * Patch the generated Capacitor 7 iOS AppDelegate after `npx cap add ios`.
 * Uses UIKit's native UIScreenEdgePanGestureRecognizer, not WKWebView history.
 * Modifies an existing Swift file; Xcode project file does not need changes.
 */
import {readFileSync,writeFileSync} from 'node:fs';

export const MARKER='// DANPER_NATIVE_BACK_SWIPE_V09';
export function installGestureInAppDelegate(original){
  if(original.includes(MARKER))return original;
  const anchor='return true';
  if(!original.includes('class AppDelegate:')||!original.includes('import Capacitor')||!original.includes(anchor)){
    throw new Error('AppDelegate.swift desconocido; no se aplicó el gesto nativo');
  }
  const observerLines=`// Instalar recognizer al aparecer la ventana, incluso con UIScene.
        NotificationCenter.default.addObserver(self, selector: #selector(danperWindowVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)
        `;
  const edited=original.replace(anchor,observerLines+anchor);
  return edited+`

${MARKER}
extension AppDelegate {
    @objc private func danperWindowVisible(_ notification: Notification) {
        guard let window = notification.object as? UIWindow,
              let bridge = window.rootViewController as? CAPBridgeViewController else { return }
        let rootView = bridge.view!
        if rootView.gestureRecognizers?.contains(where: { $0.name == "danper.native.back" }) == true { return }
        let edgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(danperHandleBackSwipe(_:)))
        edgeSwipe.name = "danper.native.back"
        edgeSwipe.edges = .left
        edgeSwipe.cancelsTouchesInView = false
        rootView.addGestureRecognizer(edgeSwipe)
    }

    @objc private func danperHandleBackSwipe(_ pan: UIScreenEdgePanGestureRecognizer) {
        guard pan.state == .ended, let surface = pan.view else { return }
        let movement = pan.translation(in: surface)
        guard movement.x >= 80, abs(movement.y) <= movement.x * 0.60 else { return }
        // UIKit recognizes the physical edge gesture; React controls which page to return to.
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        let bridge = windows.first(where: { $0.isKeyWindow })?.rootViewController as? CAPBridgeViewController
        bridge?.webView?.evaluateJavaScript("window.dispatchEvent(new Event('danper-native-swipe-back'))", completionHandler: nil)
    }
}
`;
}

if(process.argv[1]&&process.argv[1].endsWith('install-ios-gesture.mjs')){
  const path=process.argv[2]||'ios/App/App/AppDelegate.swift';
  const original=readFileSync(path,'utf8');
  const updated=installGestureInAppDelegate(original);
  writeFileSync(path,updated,'utf8');
  console.log(updated===original?'PASS: gesto nativo ya instalado':'PASS: UIScreenEdgePanGestureRecognizer integrado en AppDelegate.swift');
}
