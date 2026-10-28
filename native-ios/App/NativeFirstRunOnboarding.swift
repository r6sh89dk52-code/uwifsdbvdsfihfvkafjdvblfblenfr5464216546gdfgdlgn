import SwiftUI
import UserNotifications
import LocalAuthentication

/// Real native first-run experience. Requests permissions ONLY after the
/// person explicitly taps a matching explanation button. Skips always work.
struct NativeFirstRunOnboarding: View {
    let onFinished: () -> Void
    @State private var step = 0
    @State private var notificationState = "Puedes decidir más adelante."
    @State private var biometricState = "El código del iPhone seguirá disponible."
    @State private var requesting = false
    @State private var biometryAvailable = false

    private let accent = Color(red: 0.88, green: 0.09, blue: 0.16)
    private let steps = 4

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("DANPER SALUD").font(.caption.bold())
                    .foregroundStyle(accent)
                Spacer()
                Text("\(step + 1) / \(steps)").font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            ProgressView(value: Double(step+1), total: Double(steps))
                .tint(accent)
                .padding(.horizontal,24)
                .padding(.top, 10)

            Spacer(minLength: 22)

            VStack(spacing: 22) {
                illustration
                Text(title)
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                if step == 1 {
                    Label(notificationState, systemImage: "bell.badge")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                if step == 2 {
                    Label(biometricState, systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .id(step)
            .transition(.asymmetric(insertion:.move(edge:.trailing).combined(with:.opacity),
                                    removal:.move(edge:.leading).combined(with:.opacity)))
            .frame(maxWidth:.infinity)
            .padding(.horizontal,25)

            Spacer(minLength: 22)

            VStack(spacing: 12) {
                if step == 1 {
                    Button(action: requestNotifications) {
                        Label("Permitir notificaciones",systemImage:"bell.badge.fill")
                            .frame(maxWidth:.infinity)
                    }
                    .buttonStyle(DanperPrimaryButton())
                    .disabled(requesting)
                    Button("Ahora no") { advance() }
                        .disabled(requesting)
                } else if step == 2 {
                    if biometryAvailable {
                        Button(action: tryFaceID) {
                            Label("Configurar Face ID o Touch ID",systemImage:"faceid")
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(DanperPrimaryButton())
                        .disabled(requesting)
                    }
                    Button(biometryAvailable ? "Continuar con código" : "Continuar") { advance() }
                        .disabled(requesting)
                } else {
                    Button {
                        if step == steps-1 { onFinished() }
                        else { advance() }
                    } label: {
                        Label(step == steps-1 ? "Ir a DANPER Salud" : "Continuar",
                              systemImage: step == steps-1 ? "checkmark.seal.fill" : "arrow.right")
                            .frame(maxWidth:.infinity)
                    }
                    .buttonStyle(DanperPrimaryButton())
                }
                Text(step == 1 ? "Si rechazas, podrás recibir avisos solo si lo permites después en Ajustes del iPhone." :
                     step == 2 ? "La biometría es opcional. No obtenemos ni almacenamos tu rostro." :
                     "Diseñado para iPhone · Accesos solo cuando sean necesarios")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal,8)
            }
            .padding(.horizontal,28)
            .padding(.bottom,38)
        }
        .background(DanperBackdrop())
        .environment(\.locale,Locale(identifier:"es_PE"))
        .sensoryFeedback(.selection,trigger:step)
        .task {
            let context = LAContext()
            biometryAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,error:nil)
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                notificationState = "Notificaciones ya autorizadas."
            case .denied:
                notificationState = "Las notificaciones están desactivadas en Ajustes."
            case .notDetermined:
                notificationState = "Te avisaremos de recordatorios sin mostrar datos personales."
            @unknown default:
                notificationState = "Estado no disponible."
            }
        }
    }

    private var title: String {
        ["Bienvenido a DANPER Salud",
         "Recordatorios importantes",
         "Acceso protegido",
         "Todo preparado"][step]
    }
    private var subtitle: String {
        [
          "Una experiencia nativa, clara y privada para gestionar la salud ocupacional. La versión actual es de evaluación y mantiene intacta tu aplicación anterior.",
          "Podemos solicitar permiso para mostrar recordatorios de borradores. Los avisos no incluirán nombres, DNI ni diagnósticos.",
          "Protege la apertura mediante Face ID o Touch ID cuando estén disponibles. Siempre puedes usar el código de tu dispositivo.",
          "Los archivos se seleccionan con el explorador del iPhone cuando los necesitas. No pedimos acceso permanente a fotos, cámara, micrófono ni ubicación."
        ][step]
    }

    @ViewBuilder
    private var illustration: some View {
        if step == 0 {
            Image("BrandLogo")
                .resizable().scaledToFit()
                .frame(width:132,height:132)
                .clipShape(RoundedRectangle(cornerRadius:30))
                .shadow(color:accent.opacity(0.15),radius:22,y:9)
                .accessibilityLabel("Logotipo DANPER")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius:42)
                    .fill(accent.opacity(0.08))
                    .frame(width:168,height:168)
                Image(systemName: ["","bell.badge.fill","faceid","checkmark.shield.fill"][step])
                    .font(.system(size:76,weight:.ultraLight))
                    .foregroundStyle(accent)
                    .symbolEffect(.pulse,options:.repeating)
                    .accessibilityHidden(true)
            }
            .frame(height:168)
        }
    }

    private func advance() {
        withAnimation(.smooth(duration:0.4)) {
            step = min(steps-1,step+1)
        }
    }
    private func requestNotifications() {
        guard !requesting else { return }
        requesting = true
        Task { @MainActor in
            do {
                let accepted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options:[.alert,.sound,.badge])
                notificationState = accepted
                    ? "Notificaciones autorizadas. Se respetarán los ajustes del iPhone."
                    : "Permiso no concedido. Puedes cambiarlo desde Ajustes."
            } catch {
                notificationState = "No se pudo solicitar el permiso. Puedes continuar."
            }
            requesting = false
            advance()
        }
    }
    private func tryFaceID() {
        guard !requesting else { return }
        requesting = true
        let context=LAContext()
        Task { @MainActor in
            do {
                let passed = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason:"Confirmar acceso protegido a DANPER Salud Móvil")
                biometricState = passed ? "Biometría verificada para este dispositivo." :
                    "No se completó la verificación. Puedes usar el código."
            } catch {
                biometricState = "No se completó Face ID o Touch ID. El código seguirá disponible."
            }
            requesting = false
            advance()
        }
    }
}
