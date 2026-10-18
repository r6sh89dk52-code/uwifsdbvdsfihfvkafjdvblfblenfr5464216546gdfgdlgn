import Foundation

/// Presentation-level admission rules for the native iOS registration flow.
/// Never infer that a failed button tap succeeded or bypass duplicate-DNI checks.
public enum N2WorkerRegistrationGate {
    public static func issues(dni:String,names:String,site:String,
                              isBirthDateKnown:Bool,birthDateValid:Bool,
                              manuallyEnteredAge:String,knownDNI:Set<String>,
                              storeAvailable:Bool)->[String] {
        var result=[String]()
        if !storeAvailable {
            result.append("No se pudo abrir el registro local. Vuelve a Inicio e intenta entrar nuevamente.")
        }
        if dni.isEmpty {
            result.append("Introduce el DNI de ocho dígitos.")
        } else if dni.count != 8 ||
                  !dni.utf8.allSatisfy({(48...57).contains($0)}) {
            result.append("El DNI debe contener exactamente ocho dígitos.")

        } else if knownDNI.contains(dni) {
            result.append("El DNI ya existe en el directorio. Búscalo en Personal para evitar duplicados.")
        }
        if names.trimmingCharacters(in:.whitespacesAndNewlines).count<5 {
            result.append("Escribe los nombres y apellidos del trabajador (mínimo cinco caracteres).")
        }
        if !["LA VENTUROSA","PLVENTUROSA"].contains(site) {
            result.append("Selecciona una sede válida.")
        }
        if isBirthDateKnown {
            if !birthDateValid {
                result.append("Completa una fecha de nacimiento válida (DD/MM/AAAA) que no sea futura.")
            }
        } else if !manuallyEnteredAge.isEmpty &&
                  N2WorkerBirthDateEntry.manualAge(manuallyEnteredAge)==nil {
            result.append("La edad debe estar entre 0 y 120 años, o puedes dejarla vacía.")
        }
        return result
    }

}
