#if DEBUG
import SwiftUI
import DanperCore

/// Simulator interaction harness. No vault access, credentials or authentication
/// policy changes. This type and its route are excluded from Release/IPA builds.
struct N2InteractionProbe:View {
    @State private var category=""
    @State private var system=""
    @State private var permission="NO"
    @State private var selected=[String]()
    private var products:[DanperSearchOption] {
        guard let url=Bundle.main.url(forResource:"n2-ambulatory-products",withExtension:"json",subdirectory:"N1sDemoResources"),
              let data=try? Data(contentsOf:url),let rows=try? JSONSerialization.jsonObject(with:data) as? [[String:Any]] else{return []}
        return rows.compactMap {row in
            guard let code=row["code"] as? String,let name=row["name"] as? String,let unit=row["unit"] as? String else{return nil}
            return DanperSearchOption(id:code,title:name,detail:unit+" · Código "+code)
        }
    }
    var body:some View {
        NavigationStack {
            DanperScrollView {
                VStack(spacing:16) {
                    DanperPanel("Evaluación") {
                        DanperChoiceField(title:"Tipo de atención",selection:$category,options:N2ClinicalFormOptions.categories)
                        DanperChoiceField(title:"Sistema afectado",selection:$system,options:N2ClinicalFormOptions.systems)
                        DanperChoiceField(title:"Situación al finalizar",selection:$permission,options:["NO","SI"],labels:["NO":"Continúa laborando","SI":"Se retira con permiso"])
                    }
                    DanperPanel {
                        DanperInlineSearch(title:"Medicamentos e insumos",placeholder:"Ej. Paracetamol",options:products,onSelect:{selected.append($0)})
                        Text("Seleccionados: \(selected.count)").accessibilityIdentifier("selected-products-count")
                    }
                }.padding(16)
            }.navigationTitle("Prueba de interacción").danperFormChrome()
        }.preferredColorScheme(.dark)
    }
}
#endif
