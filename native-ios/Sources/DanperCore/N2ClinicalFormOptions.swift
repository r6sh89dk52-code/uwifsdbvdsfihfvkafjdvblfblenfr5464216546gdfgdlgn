import Foundation

public enum N2ClinicalFormOptions {
    public static let categories=["ACCIDENTE COMUN","ACCIDENTE DE TRABAJO","ENFERMEDAD","TOMA DE PRESIÓN ARTERIAL","MATERNIDAD","OTROS"]
    public static let systems=["CEFALEA","CIRCULATORIO","DIGESTIVO","ENDOCRINOLOGO","ENFERMEDADES CRONICAS","GENITAL Y REPRODUCTIVO","NEUROLOGICO","OSTEOMUSCULAR","PIEL Y ANEXOS","RESPIRATORIO","SENSORIAL","URINARIO/RENAL","OTROS"]
    // Existing build222 autocomplete labels. Free text is always retained.
    public static let diagnoses=["Cefalea","Síndrome gripal","Rinofaringitis aguda","Dolor de garganta","Faringitis aguda","Tos","Congestión nasal","Dolor abdominal","Gastralgia","Náuseas","Gastroenteritis aguda","Dispepsia","Diarrea aguda","Lumbalgia","Cervicalgia","Dorsalgia","Dolor muscular","Mialgia","Artralgia","Esguince de tobillo","Contusión de mano","Contusión de rodilla","Contusión de pierna","Contusión de brazo","Traumatismo superficial","Herida cortante","Herida contusa","Herida superficial","Picadura de insecto","Dermatitis de contacto","Irritación cutánea","Prurito","Conjuntivitis","Irritación ocular","Cuerpo extraño ocular","Ojo rojo","Dolor ocular","Mareo","Malestar general","Fatiga","Odontalgia","Otalgia","Dolor de hombro","Dolor de muñeca","Dolor de rodilla","Quemadura superficial","Calambre muscular","Rinitis alérgica","Febrícula","Tensión arterial elevada en evaluación","Dolor torácico en evaluación"]
    public static let messages:[String:String]=[
        "worker-dni":"Selecciona un trabajador con DNI válido.",
        "worker-name":"Selecciona un trabajador con nombres completos.",
        "clinical-date":"Selecciona una fecha válida.",
        "clinical-time":"Indica la hora en formato HH:mm.",
        "clinical-category":"Selecciona el tipo de atención.",
        "clinical-system":"Selecciona el sistema afectado.",
        "clinical-segment":"Especifica el segmento osteomuscular afectado.",
        "clinical-diagnosis":"Escribe el diagnóstico presuntivo o comentario clínico.",
        "allergy-status":"Confirma la revisión de alergias.",
        "allergy-substances":"Registra las sustancias reportadas como alergias.",
        "treatment-items":"Revisa la cantidad y el procedimiento de cada producto.",
        "result-permission-time":"Indica una hora válida para el permiso."
    ]
}
extension N2NativeFormDraft {
    public func clinicalIssues(step:Int,context:N2FormContext)->[String] {
        let worker=context.workers.first{$0.dni==dni}
        let allergy=context.allergies[dni]
        let input=N1hClinicalInput(worker:N1hWorkerInput(dni:dni,name:worker?.name ?? ""),
            date:date,time:time,category:category,system:system,segment:segment,
            diagnosis:diagnosis,items:items.map{N1hItemInput(quantity:Double($0.quantity),procedure:$0.procedure)},
            permission:permission,permissionTime:permissionTime)
        let validation=N1hClinicalContext(validCategories:N2ClinicalFormOptions.categories,
            validSystems:N2ClinicalFormOptions.systems,rosterRequired:true,
            workerInRoster:worker != nil,rosterException:false,
            allergiesReviewed:allergy?.reviewed ?? false,
            allergyStatus:allergy?.status ?? "unknown",allergySubstances:allergy?.substances ?? "")
        return N1hClinicalValidator.invalidFields(step:step,form:input,context:validation)
    }
}
