import Foundation

/// Explicit choice when entering a *new* lot inside the current 9–8 cut.
/// Pure accounting: it does not generate clinical visits, FEFO events or
/// opening movements. The result is used to register today's real lot balance.
public enum N2StockRegistrationBasis:String,Sendable {
    case opening = "period-opening"
    case countedNow = "physical-count"
}
public enum N2StockRegistrationChoice {
    public enum Failure:Error,Equatable {
        case invalidAmount,ambiguousHistoricalOpenings,negativeCurrentStock
        case fractionalContainerBalance,negativeOpening
    }
    public struct Resolution:Equatable,Sendable {
        public let basis:N2StockRegistrationBasis
        public let entered:Double
        /// Quantity to store in the *current* lot, never a second physical debit.
        public let todayPhysical:Double
        /// Opening balance for the 9–8 cut, including previously saved uses.
        public let cutOpening:Double?
        public let historicalUse:Double
    }
    private static func rounded(_ x:Double)->Double {
        (x*1000).rounded()/1000
    }
    public static func resolve(_ basis:N2StockRegistrationBasis,quantity:Double,
                               historical:N2AutomaticCutAccounting.Row?,
                               isContainer:Bool)throws->Resolution {
        guard quantity.isFinite,quantity>0,quantity<=10_000_000,
              (quantity*1000).rounded()==quantity*1000 else{
            throw Failure.invalidAmount
        }
        let use=historical?.reportedUse ?? 0
        let receipts=historical?.received ?? 0
        let adjustments=historical?.adjusted ?? 0
        if basis == .opening {
            // An unopened bottle cannot be inferred from "used once".
            guard (historical?.unknownContainerOpenings ?? 0)==0 else{
                throw Failure.ambiguousHistoricalOpenings
            }
            let physicallyLeft=rounded(quantity-use+receipts+adjustments)
            guard physicallyLeft>=0 else{throw Failure.negativeCurrentStock}
            guard !isContainer || physicallyLeft.rounded()==physicallyLeft else{
                throw Failure.fractionalContainerBalance
            }
            return Resolution(basis:basis,entered:quantity,
                todayPhysical:physicallyLeft,cutOpening:quantity,
                historicalUse:use)
        }
        // A count of what is physically present right now must remain intact,
        // even when historical use/packaging cannot be reconstructed.
        let suggested=rounded(quantity+use-receipts-adjustments)
        let estimated=suggested>=0 &&
            (historical?.unknownContainerOpenings ?? 0)==0
            ? suggested : nil
        return Resolution(basis:basis,entered:quantity,
            todayPhysical:quantity,cutOpening:estimated,historicalUse:use)
    }
}
