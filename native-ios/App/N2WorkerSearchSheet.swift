import SwiftUI
import DanperCore

/// Native Build 222 roster search: global DNI/name lookup, 25 rows per page.
/// Read-only until an explicit worker is selected; never edits the roster.
struct N2WorkerSearchSheet:View {
    let workers:[N2FormWorker]
    let onSelect:(N2FormWorker)->Void
    let onNewWorker:()->Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var searchFocused:Bool
    @State private var query=""
    @State private var page=0
    private let pageSize=25

    private var matches:[N2FormWorker] {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else {
            return workers.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
        }
        return workers.filter {
            $0.dni.contains(q) || $0.name.localizedStandardContains(q)
        }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
    }
    private var pageCount:Int {max(1,(matches.count+pageSize-1)/pageSize)}
    private var visible:[N2FormWorker] {
        Array(matches.dropFirst(page*pageSize).prefix(pageSize))
    }

    var body:some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    Color.clear.frame(height:1).id("worker-search-top")
                    VStack(alignment:.leading,spacing:4) {
                        Text("BUSCAR EN PADRÓN")
                            .font(.caption2.weight(.bold))
                            .tracking(1.2).foregroundStyle(DanperStyle.red)
                        Text("Seleccionar trabajador").font(.title2.weight(.bold))
                        Text("Busca por DNI o por cualquier parte del nombre.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    DanperPanel {
                        DanperField(title:"DNI o apellidos y nombres") {
                            HStack {
                                Image(systemName:"magnifyingglass").foregroundStyle(.secondary)
                                TextField("Escribe DNI o nombre",text:$query)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($searchFocused)
                                    .accessibilityIdentifier("roster-global-search")
                            }
                        }
                        if matches.isEmpty {
                            ContentUnavailableView("No se encontraron trabajadores",
                                systemImage:"person.crop.circle.badge.questionmark",
                                description:Text("Revisa la búsqueda o registra a la persona manualmente."))
                        } else {
                            Text("\(matches.count) encontrados · Página \(page+1) de \(pageCount)")
                                .font(.caption).foregroundStyle(.secondary)
                            LazyVStack(spacing:0) {
                                ForEach(visible) { worker in
                                    Button {
                                        onSelect(worker)
                                        dismiss()
                                    } label: {
                                        HStack(spacing:10) {
                                            Image(systemName:"person.crop.circle")
                                                .foregroundStyle(DanperStyle.red)
                                            VStack(alignment:.leading,spacing:4) {
                                                Text(worker.name).font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                Text(worker.dni+" · "+worker.site)
                                                    .font(.caption).foregroundStyle(.secondary)
                                            }.frame(maxWidth:.infinity,alignment:.leading)
                                            Image(systemName:"chevron.right").foregroundStyle(.secondary)
                                        }.padding(.vertical,11).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("roster-result-"+worker.dni)
                                    Divider().opacity(0.35)
                                }
                            }
                            if pageCount>1 {
                                HStack(spacing:12) {
                                    Button("Anterior") {goTo(max(0,page-1),proxy:proxy)}
                                        .disabled(page==0)
                                    Spacer()
                                    Text("\(page+1) / \(pageCount)")
                                        .font(.caption).monospacedDigit()
                                    Spacer()
                                    Button("Siguiente") {goTo(min(pageCount-1,page+1),proxy:proxy)}
                                        .disabled(page>=pageCount-1)
                                }.buttonStyle(DanperSecondaryButton())
                            }
                        }
                        Button {
                            dismiss()
                            onNewWorker()
                        } label: {
                            Label("Registrar nuevo trabajador",systemImage:"person.badge.plus")
                                .frame(maxWidth:.infinity)
                        }
                        .buttonStyle(DanperSecondaryButton())
                        .accessibilityIdentifier("roster-create-worker")
                    }
                }.padding(16)
            }
            .onChange(of:query) {_,_ in
                page=0
                withAnimation(.easeOut(duration:0.18)){
                    proxy.scrollTo("worker-search-top",anchor:.top)
                }
            }
        }
        .navigationTitle("Buscar en padrón")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {ToolbarItem(placement:.topBarTrailing) {
            Button("Cerrar"){dismiss()}
        }}
        .danperFormChrome()
    }
    private func goTo(_ next:Int,proxy:ScrollViewProxy) {
        page=next
        withAnimation(.easeInOut(duration:0.2)){
            proxy.scrollTo("worker-search-top",anchor:.top)
        }
    }
}
