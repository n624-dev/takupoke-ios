/// Isolate an additional research diagnostic from the frozen baseline. Task cancellation/deadline stays terminal.
struct IndependentInkProof {
    let uncoveredInk:Bool?
    let error:Error?
    static func measure(evaluate:() throws -> Bool,check:() throws -> Void) throws -> IndependentInkProof {
        let outcome:IndependentInkProof
        do {outcome=IndependentInkProof(uncoveredInk:try evaluate(),error:nil)}
        catch {outcome=IndependentInkProof(uncoveredInk:nil,error:error)}
        try check()
        return outcome
    }
}
