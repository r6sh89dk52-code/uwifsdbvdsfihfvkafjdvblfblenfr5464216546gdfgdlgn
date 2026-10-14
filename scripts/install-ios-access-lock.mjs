/**
 * Patch generated Capacitor 7 AppDelegate.swift after native gesture install.
 * Native UIKit overlay + LocalAuthentication protects the WKWebView even
 * when WebKit is loading, on task switcher snapshots, and after app resume.
 * The iOS device passcode is the fallback for Face ID / Touch ID.
 */
import {readFileSync,writeFileSync} from 'node:fs';

export const ACCESS_MARKER='// DANPER_NATIVE_ACCESS_LOCK_V0203';
const notificationAnchor='NotificationCenter.default.addObserver(self, selector: #selector(danperWindowVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)';
export function installAccessInAppDelegate(source){
 if(source.includes(ACCESS_MARKER))return source;
 if(!source.includes('class AppDelegate:')||!source.includes('import Capacitor')||!source.includes(notificationAnchor))
  throw new Error('AppDelegate.swift incompatible: primero instalar el gesto nativo.');
 let output=source.replace('import Capacitor','import Capacitor\nimport LocalAuthentication');
 const lifecycle=`\n        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthWindowVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthWillResign(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)`;
 output=output.replace(notificationAnchor,notificationAnchor+lifecycle);
 return output+`

${ACCESS_MARKER}
private let danperNativeLockTag = 20261014
private var danperAuthAttemptInFlight = false
private var danperAuthUnlocked = false

extension AppDelegate {
    @objc private func danperAuthWindowVisible(_ notification: Notification) {
        guard let window = notification.object as? UIWindow,
              window.rootViewController is CAPBridgeViewController else { return }
        danperAddLockOverlay(to: window)
        if UIApplication.shared.applicationState == .active { danperAttemptAuthentication() }
    }

    @objc private func danperAuthWillResign(_ notification: Notification) {
        danperAuthUnlocked = false
        for window in danperAppWindows() { danperAddLockOverlay(to: window) }
    }

    @objc private func danperAuthDidBecomeActive(_ notification: Notification) {
        if !danperAuthUnlocked { danperAttemptAuthentication() }
    }

    private func danperAppWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .filter { $0.rootViewController is CAPBridgeViewController }
    }

    private func danperAddLockOverlay(to window: UIWindow) {
        guard window.viewWithTag(danperNativeLockTag) == nil else { return }
        let lockView = UIView(frame: window.bounds)
        lockView.tag = danperNativeLockTag
        lockView.backgroundColor = UIColor.systemBackground
        lockView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lockView.isAccessibilityElement = false
        let heading = UILabel()
        heading.text = "DANPER Salud Móvil"
        heading.textAlignment = .center
        heading.font = UIFont.preferredFont(forTextStyle: .title2)
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        let message = UILabel()
        message.tag = danperNativeLockTag + 1
        message.text = "Protección de datos: usa Face ID o el código de tu iPhone para acceder."
        message.textAlignment = .center
        message.textColor = .secondaryLabel
        message.font = UIFont.preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0
        let button = UIButton(type: .system)
        button.setTitle("Desbloquear", for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.addTarget(self, action: #selector(danperUnlockTapped(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        let stack = UIStackView(arrangedSubviews: [heading,message,button])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        lockView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: lockView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: lockView.trailingAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 430),
            stack.centerXAnchor.constraint(equalTo: lockView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: lockView.centerYAnchor)
        ])
        window.addSubview(lockView)
        window.bringSubviewToFront(lockView)
    }

    @objc private func danperUnlockTapped(_ sender: UIButton) {
        danperAttemptAuthentication()
    }

    private func danperSetLockMessage(_ text: String) {
        for window in danperAppWindows() {
            guard let label = window.viewWithTag(danperNativeLockTag + 1) as? UILabel else { continue }
            label.text = text
        }
    }

    private func danperAttemptAuthentication() {
        guard !danperAuthUnlocked && !danperAuthAttemptInFlight else { return }
        let windows = danperAppWindows()
        guard !windows.isEmpty else { return }
        for window in windows { danperAddLockOverlay(to: window) }
        let context = LAContext()
        var failure: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &failure) else {
            danperSetLockMessage("Para abrir DANPER Salud Móvil configura primero un código de desbloqueo en Ajustes del iPhone.")
            return
        }
        danperAuthAttemptInFlight = true
        danperSetLockMessage("Confirma tu identidad en iOS. Si no funciona Face ID, usa el código del dispositivo.")
        context.evaluatePolicy(policy, localizedReason: "Proteger la información ocupacional guardada en DANPER Salud Móvil") { [weak self] success, error in
            DispatchQueue.main.async {
                danperAuthAttemptInFlight = false
                guard let self = self else { return }
                if success && UIApplication.shared.applicationState == .active {
                    danperAuthUnlocked = true
                    for window in self.danperAppWindows() {
                        window.viewWithTag(danperNativeLockTag)?.removeFromSuperview()
                    }
                } else {
                    danperAuthUnlocked = false
                    let errorCode = (error as NSError?)?.code
                    self.danperSetLockMessage(errorCode == LAError.userCancel.rawValue
                        ? "Autenticación cancelada. Pulsa Desbloquear para volver a intentarlo."
                        : "No se pudo autenticar. Inténtalo nuevamente con Face ID o el código del iPhone.")
                }
            }
        }
    }
}
`;
}
if(process.argv[1]?.endsWith('install-ios-access-lock.mjs')){
 const path=process.argv[2]||'ios/App/App/AppDelegate.swift';
 const before=readFileSync(path,'utf8');
 const after=installAccessInAppDelegate(before);
 writeFileSync(path,after,'utf8');
 console.log(after===before?'PASS: bloqueo nativo ya instalado':'PASS: protección nativa Face ID/código integrada en AppDelegate');
}
