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
    @State private var committedQuery=""
    @State private var page=0
    private let pageSize=25

    @State private var searchIndex:N2SearchIndex<N2FormWorker>?
    @State private var matches=[N2FormWorker]()
    var body:some View {
        // Evaluate the 9k-person predicate once per render, not again
        // for the count, pagination and ForEach. Only 25 views are made.
        let results=matches
        let totalPages=max(1,(results.count+pageSize-1)/pageSize)
        let pageWorkers=Array(results.dropFirst(page*pageSize).prefix(pageSize))
        return ScrollViewReader { proxy in
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
                        if committedQuery.trimmingCharacters(in:.whitespacesAndNewlines).count<2 {
                            ContentUnavailableView("Escribe para buscar",
                                systemImage:"magnifyingglass",
                                description:Text("Introduce al menos dos caracteres del DNI o nombre. No se muestra el padrón completo."))
                        } else if results.isEmpty {
                            ContentUnavailableView("No se encontraron trabajadores",
                                systemImage:"person.crop.circle.badge.questionmark",
                                description:Text("Revisa la búsqueda o registra a la persona manualmente."))
                        } else {
                            Text("\(results.count) encontrados · Página \(page+1) de \(totalPages)")
                                .font(.caption).foregroundStyle(.secondary)
                            LazyVStack(spacing:0) {
                                ForEach(pageWorkers) { worker in
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
                            if totalPages>1 {
                                HStack(spacing:12) {
                                    Button("Anterior") {goTo(max(0,page-1),proxy:proxy)}
                                        .disabled(page==0)
                                    Spacer()
                                    Text("\(page+1) / \(totalPages)")
                                        .font(.caption).monospacedDigit()
                                    Spacer()
                                    Button("Siguiente") {goTo(min(totalPages-1,page+1),proxy:proxy)}
                                        .disabled(page>=totalPages-1)
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
            .task(id:query) {
                // Do not rescan 10k people on every keystroke.
                let requested=query
                if requested.trimmingCharacters(in:.whitespacesAndNewlines).count<2 {
                    committedQuery=requested;matches=[];page=0
                    return
                }
                do {try await Task.sleep(for:.milliseconds(180))}
                catch{return}
                guard !Task.isCancelled else{return}
                let prior=searchIndex,rows=workers
                let prepared=await Task.detached(priority:.userInitiated) {
                    let index=prior ?? N2SearchIndex(rows:rows,fields:{$0.dni+"\u{1f}"+$0.name})
                    return (index,index.matches(requested))
                }.value
                guard !Task.isCancelled else{return}
                searchIndex=prepared.0;matches=prepared.1
                committedQuery=requested;page=0
            }
        }
        .onAppear {searchFocused=true}
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
