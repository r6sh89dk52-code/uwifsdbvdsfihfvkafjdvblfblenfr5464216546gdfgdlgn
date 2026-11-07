import SwiftUI
import DanperCore

/// Notification preferences are device-local presentation choices, not clinical
/// records. Separate namespaces preserve protected/demo isolation.
enum N2NotificationInboxPreferences {
    private static func key(_ mode:N2WorkspaceVault.Mode)->String {
        "danper.n2."+mode.rawValue+".dismissed-alerts.v1"
    }
    static func read(_ mode:N2WorkspaceVault.Mode,defaults:UserDefaults = .standard)->Set<String> {
        Set(defaults.stringArray(forKey:key(mode)) ?? [])
    }
    static func dismiss(_ id:String,mode:N2WorkspaceVault.Mode,defaults:UserDefaults = .standard)->Set<String> {
        var saved=read(mode,defaults:defaults)
        saved.insert(id)
        defaults.set(saved.sorted(),forKey:key(mode))
        return saved
    }
    static func restore(_ mode:N2WorkspaceVault.Mode,defaults:UserDefaults = .standard)->Set<String> {
        defaults.removeObject(forKey:key(mode))
        return []
    }
}

/// The inbox only presents authenticated derived alerts. Dismissing an alert
/// never deletes the draft, clinical source, pharmacy count or a due date.
struct N2NotificationInboxView:View {
    let alerts:[N2ClinicalAlert]
    let now:Date
    let dismissedCount:Int
    let schedulerFailed:Bool
    let onDismiss:(N2ClinicalAlert)->Void
    let onRestore:()->Void
    let onOpenDrafts:()->Void

    private enum Filter:String,CaseIterable {
        case all="Todas",draft="Borradores",expiry="Vencimientos",
             stock="Existencias",followUp="Seguimientos"
        func includes(_ kind:N2ClinicalAlert.Kind)->Bool {
            switch self {
            case .all:return true
            case .draft:return kind == .draft
            case .expiry:return kind == .expiryWarning || kind == .expiryDay
            case .stock:return kind == .outOfStock
            // Follow-up events must come from verified clinical evidence.
            // Do not invent reminders from historical visits.
            case .followUp:return false
            }
        }
    }
    @Environment(\.dismiss) private var close
    @State private var filter=Filter.all
    private var visible:[N2ClinicalAlert] {
        alerts.filter{filter.includes($0.kind)}
            .sorted{($0.dueAt,$0.id)<($1.dueAt,$1.id)}
    }
    var body:some View {
        let rows=visible
        NavigationStack {
            VStack(spacing:0) {
                ScrollView(.horizontal) {
                    HStack(spacing:8) {
                        ForEach(Filter.allCases,id:\.self) { item in
                            Button {
                                filter=item
                            } label: {
                                Text(item.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal,13).padding(.vertical,9)
                                    .foregroundStyle(filter==item ? .white : .secondary)
                                    .background(filter==item ? DanperStyle.red : DanperStyle.surface,
                                                in:Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("notification-filter-"+item.rawValue)
                        }
                    }.padding(.horizontal,16).padding(.vertical,11)
                }.scrollIndicators(.hidden)
                if schedulerFailed {
                    Text("Algunos avisos de iOS no pudieron programarse. Los avisos dentro de DANPER siguen disponibles.")
                        .font(.footnote).foregroundStyle(.orange).padding(.horizontal,16)
                }
                if rows.isEmpty {
                    ContentUnavailableView("No hay avisos",
                        systemImage:"bell.slash",
                        description:Text("No tienes notificaciones en esta categoría."))
                        .frame(maxWidth:.infinity,maxHeight:.infinity)
                } else {
                    List {
                        ForEach(rows) { alert in
                            VStack(alignment:.leading,spacing:9) {
                                Label(alert.detail,systemImage:symbol(alert.kind))
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                HStack {
                                    Text(alert.dueAt<=Int64(now.timeIntervalSince1970*1000)
                                         ? "Pendiente de revisar" : "Próximo aviso")
                                        .font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    if alert.kind == .draft {
                                        Button("Ver borradores",action:onOpenDrafts)
                                            .font(.caption.weight(.semibold))
                                    } else {
                                        NavigationLink("Abrir Kardex") {
                                            N2Build222KardexHub()
                                        }.font(.caption.weight(.semibold))
                                    }
                                }
                                Button(role:.destructive) {
                                    onDismiss(alert)
                                } label: {
                                    Label("Eliminar aviso",systemImage:"trash")
                                        .font(.caption.weight(.medium))
                                }
                                .buttonStyle(.borderless)
                                .accessibilityIdentifier("notification-dismiss-"+alert.id)
                            }
                            .padding(.vertical,5)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(DanperBackdrop())
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.topBarLeading) {
                    Button("Cerrar") {close()}
                        .accessibilityIdentifier("notification-close")
                }
                if dismissedCount>0 {
                    ToolbarItem(placement:.topBarTrailing) {
                        Button("Restaurar descartadas",action:onRestore)
                            .font(.caption)
                    }
                }
            }
            .accessibilityIdentifier("notification-inbox")
        }
        .tint(DanperStyle.red)
        .preferredColorScheme(.dark)
    }
    private func symbol(_ kind:N2ClinicalAlert.Kind)->String {
        switch kind {
        case .draft:return "doc.badge.clock"
        case .expiryWarning,.expiryDay:return "calendar.badge.exclamationmark"
        case .outOfStock:return "shippingbox"
        }
    }
}
