import Foundation
import Crypto

/// Derived from authenticated data only; never persisted in the clinical schema.
public struct N2ClinicalAlert:Identifiable,Equatable,Sendable {
    public enum Kind:String,Sendable {case draft,expiryWarning,expiryDay,outOfStock}
    public let id:String
    public let sourceID:String
    public let kind:Kind
    public let dueAt:Int64
    public let detail:String
    public let actionable:Bool
}
public enum N2ClinicalAlerts {
    private static func identifier(_ kind:N2ClinicalAlert.Kind,_ key:String)->String {
        kind.rawValue+"."+SHA256.hash(data:Data(key.utf8)).map{String(format:"%02x",$0)}.joined()
    }
    private static func date(_ day:String)->Date? {
        let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX")
        f.timeZone=TimeZone(identifier:"America/Lima");f.dateFormat="yyyy-MM-dd";f.isLenient=false
        guard let date=f.date(from:day),f.string(from:date)==day else{return nil}
        return date
    }
    public static func plan(drafts:[N2RecoverableDraft],products:[N2SimpleProduct],now:Date)->[N2ClinicalAlert] {
        let span=N2PerformanceSpan("Clinical alert projection");defer{span.end()}
        let instant=Int64(now.timeIntervalSince1970*1000)
        var alerts=drafts.map { draft in
            let due=draft.updatedAt+3_600_000
            return N2ClinicalAlert(id:identifier(.draft,draft.id),sourceID:draft.id,kind:.draft,dueAt:due,
                detail:"Borrador sin edición durante 60 minutos",actionable:due<=instant)
        }
        for product in products {
            if product.quantity==0 {
                alerts.append(N2ClinicalAlert(id:identifier(.outOfStock,product.code),sourceID:product.code,kind:.outOfStock,
                    dueAt:0,detail:product.name+" · Sin existencias",actionable:true))
            }
            guard product.expiryVerified,product.quantity>0,let expiry=date(product.expiry) else{continue}
            var calendar=Calendar(identifier:.gregorian);calendar.timeZone=TimeZone(identifier:"America/Lima")!
            guard let warning=calendar.date(byAdding:.day,value:-30,to:expiry),
                  let warningMorning=calendar.date(bySettingHour:9,minute:0,second:0,of:warning),
                  let expiryMorning=calendar.date(bySettingHour:9,minute:0,second:0,of:expiry) else{continue}
            for (kind,day) in [(N2ClinicalAlert.Kind.expiryWarning,warningMorning),(.expiryDay,expiryMorning)] {
                if kind == .expiryWarning,expiryMorning<=now {continue}
                let due=Int64(day.timeIntervalSince1970*1000)
                alerts.append(N2ClinicalAlert(id:identifier(kind,product.code+"|"+product.expiry),sourceID:product.code,kind:kind,dueAt:due,
                    detail:product.name+" · Vencimiento acreditado: "+product.expiry,actionable:due<=instant))
            }
        }
        return alerts.sorted { a,b in a.dueAt==b.dueAt ? a.id<b.id:a.dueAt<b.dueAt }
    }
}
