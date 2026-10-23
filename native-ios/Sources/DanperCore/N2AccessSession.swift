import Foundation

public struct N2AccessSession:Sendable {
    public private(set) var authenticated=false
    public private(set) var running=false
    public private(set) var automaticAttempted=false
    public init() {}
    public mutating func reserveAutomatic()->Bool {
        guard !authenticated,!running,!automaticAttempted else{return false}
        automaticAttempted=true
        return true
    }
    public mutating func begin()->Bool {
        guard !authenticated,!running else{return false}
        running=true
        return true
    }
    public mutating func complete(success:Bool) {
        guard running else{return}
        running=false;authenticated=success
    }
    public mutating func lock() {
        authenticated=false;running=false;automaticAttempted=false
    }
}
