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
 let output=source.replace('import Capacitor','import Capacitor\nimport LocalAuthentication\nimport CoreImage');
 const lifecycle=`\n        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthWindowVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthWillResign(_:)), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(danperAuthDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)`;
 output=output.replace(notificationAnchor,notificationAnchor+lifecycle);
 return output+`

${ACCESS_MARKER}
private let danperNativeLockTag = 20261014
private var danperAuthAttemptInFlight = false
private var danperAuthUnlocked = false
private var danperAuthGeneration = 0
private var danperAuthContext: LAContext?

extension AppDelegate {
    @objc private func danperAuthWindowVisible(_ notification: Notification) {
        guard let window = notification.object as? UIWindow,
              window.rootViewController is CAPBridgeViewController else { return }
        // A freshly visible CAP window must not cover an authenticated session.
        if danperAuthUnlocked {
            window.viewWithTag(danperNativeLockTag)?.removeFromSuperview()
            return
        }
        danperAddLockOverlay(to: window)
        // The welcome screen is deliberate: Face ID begins only after tapping Ingresar.
    }

    @objc private func danperAuthWillResign(_ notification: Notification) {
        // Face ID/código may temporarily resign app activity. Cover the content
        // for privacy, but DO NOT cancel/forget an authentication in progress.
        // A real background transition is handled by didEnterBackground.
        for window in danperAppWindows() { danperAddLockOverlay(to: window) }
    }

    @objc private func danperAuthDidEnterBackground(_ notification: Notification) {
        danperAuthGeneration += 1
        danperAuthUnlocked = false
        danperAuthAttemptInFlight = false
        danperAuthContext?.invalidate()
        danperAuthContext = nil
        for window in danperAppWindows() { danperAddLockOverlay(to: window) }
    }

    @objc private func danperAuthDidBecomeActive(_ notification: Notification) {
        // Face ID may succeed while UIKit is still inactive. Reveal on resume.
        if danperAuthUnlocked {
            for window in danperAppWindows() {
                window.viewWithTag(danperNativeLockTag)?.removeFromSuperview()
            }
        } else if !danperAuthAttemptInFlight {
            // Resume remains private, but never launches a second Face ID request.
            for window in danperAppWindows() { danperAddLockOverlay(to: window) }
        }
    }

    private func danperAppWindows() -> [UIWindow] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .filter { $0.rootViewController is CAPBridgeViewController }
    }


    // Official asset is a square PNG with a baked red background.
    // Crop its authentic script glyphs and turn the red into transparent alpha.
    // No third-party logo, replacement font or extra binary dependency.
    private func danperCleanWordmark() -> UIImage? {
        guard let original = UIImage(named: "DanperWordmark"),
              let source = original.cgImage else { return nil }
        let width = CGFloat(source.width)
        let height = CGFloat(source.height)
        let crop = CGRect(x: width * 0.094,
                          y: height * 0.37,
                          width: width * 0.83,
                          height: height * 0.30).integral
        guard let trimmed = source.cropping(to: crop),
              let matrix = CIFilter(name: "CIColorMatrix") else { return nil }
        matrix.setValue(CIImage(cgImage: trimmed), forKey: kCIInputImageKey)
        let none = CIVector(x: 0, y: 0, z: 0, w: 0)
        matrix.setValue(none, forKey: "inputRVector")
        matrix.setValue(none, forKey: "inputGVector")
        matrix.setValue(none, forKey: "inputBVector")
        matrix.setValue(CIVector(x: 0, y: 0.56, z: 0.56, w: 0), forKey: "inputAVector")
        matrix.setValue(CIVector(x: 1, y: 1, z: 1, w: -0.10), forKey: "inputBiasVector")
        guard let clean = matrix.outputImage,
              let rendered = CIContext().createCGImage(clean, from: clean.extent) else { return nil }
        return UIImage(cgImage: rendered, scale: original.scale, orientation: .up)
    }

    private func danperAddLockOverlay(to window: UIWindow) {
        // Fully opaque UIKit cover is installed before displaying any WKWebView.
        // The protected web app never renders visibly until LocalAuthentication succeeds.
        guard window.viewWithTag(danperNativeLockTag) == nil else { return }
        let red = UIColor(red: 227.0 / 255.0, green: 24.0 / 255.0, blue: 45.0 / 255.0, alpha: 1)
        let lockView = UIView(frame: window.bounds)
        lockView.tag = danperNativeLockTag
        lockView.backgroundColor = UIColor.systemBackground
        lockView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        lockView.isAccessibilityElement = false

        let scroll = UIScrollView(frame: lockView.bounds)
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = false
        lockView.addSubview(scroll)
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor)
        ])

        let brand = UIView()
        brand.backgroundColor = .clear
        brand.layer.cornerRadius = 25
        brand.layer.cornerCurve = .continuous
        brand.clipsToBounds = true
        brand.translatesAutoresizingMaskIntoConstraints = false
        brand.heightAnchor.constraint(equalToConstant: 106).isActive = true

        let brandWordmark = UIImageView(image: danperCleanWordmark())
        brandWordmark.contentMode = .scaleAspectFit
        brandWordmark.translatesAutoresizingMaskIntoConstraints = false
        brand.addSubview(brandWordmark)
        let brandFallback = UILabel()
        brandFallback.text = "DANPER"
        brandFallback.textAlignment = .center
        brandFallback.textColor = .white
        brandFallback.font = UIFont.systemFont(ofSize: 34, weight: .heavy)
        brandFallback.isHidden = brandWordmark.image != nil
        brandFallback.translatesAutoresizingMaskIntoConstraints = false
        brand.addSubview(brandFallback)
        let brandSub = UILabel()
        brandSub.text = "SALUD MÓVIL"
        brandSub.textColor = UIColor.white.withAlphaComponent(0.96)
        brandSub.textAlignment = .center
        brandSub.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        brandSub.translatesAutoresizingMaskIntoConstraints = false
        brand.addSubview(brandSub)
        NSLayoutConstraint.activate([
            brandWordmark.centerXAnchor.constraint(equalTo: brand.centerXAnchor),
            brandWordmark.centerYAnchor.constraint(equalTo: brand.centerYAnchor, constant: -12),
            brandWordmark.heightAnchor.constraint(equalToConstant: 70),
            brandWordmark.widthAnchor.constraint(equalTo: brand.widthAnchor, multiplier: 0.77),
            brandWordmark.widthAnchor.constraint(lessThanOrEqualToConstant: 230),
            brandFallback.centerXAnchor.constraint(equalTo: brand.centerXAnchor),
            brandFallback.centerYAnchor.constraint(equalTo: brandWordmark.centerYAnchor),
            brandSub.centerXAnchor.constraint(equalTo: brand.centerXAnchor),
            brandSub.topAnchor.constraint(equalTo: brandWordmark.bottomAnchor, constant: 0)
        ])

        let healthCircle = UIView()
        healthCircle.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        healthCircle.layer.cornerRadius = 43
        healthCircle.translatesAutoresizingMaskIntoConstraints = false
        healthCircle.widthAnchor.constraint(equalToConstant: 86).isActive = true
        healthCircle.heightAnchor.constraint(equalToConstant: 86).isActive = true
        let healthImage = UIImageView(image: UIImage(systemName: "cross.case.fill"))
        healthImage.tintColor = .white
        healthImage.contentMode = .scaleAspectFit
        healthImage.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 42, weight: .medium)
        healthImage.translatesAutoresizingMaskIntoConstraints = false
        healthCircle.addSubview(healthImage)
        NSLayoutConstraint.activate([
            healthImage.centerXAnchor.constraint(equalTo: healthCircle.centerXAnchor),
            healthImage.centerYAnchor.constraint(equalTo: healthCircle.centerYAnchor)
        ])

        let heading = UILabel()
        heading.text = "Bienvenido"
        heading.textAlignment = .center
        heading.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        heading.textColor = .white

        let department = UILabel()
        department.text = "Departamento de Salud"
        department.textAlignment = .center
        department.font = UIFont.preferredFont(forTextStyle: .title3)
        department.adjustsFontForContentSizeCategory = true
        department.numberOfLines = 0
        department.textColor = .white

        let message = UILabel()
        message.tag = danperNativeLockTag + 1
        message.text = "Tu espacio para una atención más rápida, organizada y segura."
        message.textAlignment = .center
        message.textColor = .secondaryLabel
        message.font = UIFont.preferredFont(forTextStyle: .subheadline)
        message.adjustsFontForContentSizeCategory = true
        message.numberOfLines = 0

        let button = UIButton(type: .system)
        button.setTitle("Ingresar con Face ID", for: .normal)
        button.setImage(UIImage(systemName: "faceid"), for: .normal)
        button.tintColor = .white
        button.semanticContentAttribute = .forceRightToLeft
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = red
        button.layer.cornerRadius = 22
        button.layer.cornerCurve = .continuous
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        button.addTarget(self, action: #selector(danperUnlockTapped(_:)), for: .touchUpInside)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 55).isActive = true
        button.accessibilityLabel = "Ingresar con Face ID o código del iPhone"

        let security = UILabel()
        security.text = "Acceso protegido con Face ID o código del iPhone"
        security.textAlignment = .center
        security.textColor = .secondaryLabel
        security.font = UIFont.preferredFont(forTextStyle: .footnote)
        security.adjustsFontForContentSizeCategory = true
        security.numberOfLines = 0

        // Bank-inspired arrangement: DANPER red hero above, quiet access surface below.
        // Both sections scroll safely on smaller iPhones and with Dynamic Type.
        let hero = UIView()
        hero.backgroundColor = red
        let lower = UIView()
        lower.backgroundColor = .systemBackground
        lower.layer.cornerRadius = 34
        lower.layer.cornerCurve = .continuous
        lower.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let heroStack = UIStackView(arrangedSubviews: [brand, healthCircle, heading, department])
        heroStack.axis = .vertical
        heroStack.alignment = .center
        heroStack.spacing = 14
        heroStack.setCustomSpacing(17, after: brand)
        heroStack.setCustomSpacing(21, after: healthCircle)
        heroStack.setCustomSpacing(3, after: heading)
        heroStack.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(heroStack)
        let actionStack = UIStackView(arrangedSubviews: [message, button, security])
        actionStack.axis = .vertical
        actionStack.alignment = .center
        actionStack.spacing = 17
        actionStack.setCustomSpacing(22, after: message)
        actionStack.setCustomSpacing(12, after: button)
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        lower.addSubview(actionStack)
        let sections = UIStackView(arrangedSubviews: [hero, lower])
        sections.axis = .vertical
        sections.spacing = -29
        sections.distribution = .fill
        sections.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sections)
        NSLayoutConstraint.activate([
            sections.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sections.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            sections.topAnchor.constraint(equalTo: content.topAnchor),
            sections.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            hero.heightAnchor.constraint(greaterThanOrEqualToConstant:400),
            hero.heightAnchor.constraint(equalTo: content.heightAnchor, multiplier: 0.57),
            lower.heightAnchor.constraint(greaterThanOrEqualToConstant:310),
            heroStack.leadingAnchor.constraint(greaterThanOrEqualTo: hero.leadingAnchor, constant:25),
            heroStack.trailingAnchor.constraint(lessThanOrEqualTo: hero.trailingAnchor, constant:-25),
            heroStack.centerXAnchor.constraint(equalTo: hero.centerXAnchor),
            heroStack.centerYAnchor.constraint(equalTo: hero.centerYAnchor, constant:20),
            heroStack.topAnchor.constraint(greaterThanOrEqualTo: hero.topAnchor, constant:69),
            heroStack.bottomAnchor.constraint(lessThanOrEqualTo: hero.bottomAnchor, constant:-48),
            heroStack.widthAnchor.constraint(lessThanOrEqualToConstant:410),
            brand.widthAnchor.constraint(equalTo: heroStack.widthAnchor),
            heading.widthAnchor.constraint(equalTo: heroStack.widthAnchor),
            department.widthAnchor.constraint(equalTo: heroStack.widthAnchor),
            actionStack.leadingAnchor.constraint(equalTo: lower.leadingAnchor, constant:26),
            actionStack.trailingAnchor.constraint(equalTo: lower.trailingAnchor, constant:-26),
            actionStack.centerYAnchor.constraint(equalTo: lower.centerYAnchor, constant:8),
            actionStack.topAnchor.constraint(greaterThanOrEqualTo: lower.topAnchor, constant:54),
            actionStack.bottomAnchor.constraint(lessThanOrEqualTo: lower.bottomAnchor, constant:-35),
            button.widthAnchor.constraint(equalTo: actionStack.widthAnchor),
            message.widthAnchor.constraint(equalTo: actionStack.widthAnchor),
            security.widthAnchor.constraint(equalTo: actionStack.widthAnchor)
        ])
        window.addSubview(lockView)
        window.bringSubviewToFront(lockView)
        // Calm breathing CTA, 1.0 -> 1.025 -> 1.0. Accessibility stays respected.
        if !UIAccessibility.isReduceMotionEnabled {
            healthCircle.alpha = 0.6
            UIView.animate(withDuration: 0.42, delay: 0.1, options: [.curveEaseOut, .allowUserInteraction], animations: {
                healthCircle.alpha = 1
            })
            UIView.animate(withDuration: 1.75, delay: 0.65,
                           options: [.curveEaseInOut, .autoreverse, .repeat, .allowUserInteraction],
                           animations: {
                button.transform = CGAffineTransform(scaleX: 1.025, y: 1.025)
            }, completion: nil)
        }
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
        danperAuthContext = context
        let generation = danperAuthGeneration
        danperSetLockMessage("Confirma tu identidad en iOS. Si no funciona Face ID, usa el código del dispositivo.")
        context.evaluatePolicy(policy, localizedReason: "Proteger la información ocupacional guardada en DANPER Salud Móvil") { [weak self] success, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Ignore stale callbacks after a real background transition.
                guard generation == danperAuthGeneration else { return }
                danperAuthAttemptInFlight = false
                danperAuthContext = nil
                if success {
                    // iOS may still be .inactive when LocalAuthentication reports
                    // success. Remember it, then uncover now or on didBecomeActive.
                    danperAuthUnlocked = true
                    if UIApplication.shared.applicationState == .active {
                        for window in self.danperAppWindows() {
                            window.viewWithTag(danperNativeLockTag)?.removeFromSuperview()
                        }
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
