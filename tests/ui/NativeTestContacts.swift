import XCTest
import UIKit
import ObjectiveC
import Darwin

// Individual XCTest coordinate commands wait for quiescence between actions.
// Schedule known screen coordinates on the simulator test bundle's native clock.
enum NativeTestContacts {
    struct Contact {
        let start: CGPoint
        let end: CGPoint
        let duration: TimeInterval
        let pauseAfterLift: TimeInterval
    }

    private static func typeEncoding(_ copied: UnsafeMutablePointer<CChar>?) -> String {
        guard let copied else { return "unavailable" }
        defer { free(copied) }
        return String(String(cString: copied).drop(while: { "rnNoORV".contains($0) }))
    }

    private static func matches(_ actual: String, _ expected: String) -> Bool {
        if expected == "@" { return actual == "@" || actual.hasPrefix("@\"") }
        if expected == "@?" {
            return ["@?", "@?<v@?B@>", "@?<v@?B@\"NSError\">", "@?<vB@>", "@?<vB@\"NSError\">"].contains(actual)
        }
        return actual == expected
    }

    private static func method<Signature>(
        _ name: String, on type: AnyClass?, returns: String, arguments: [String], as signature: Signature.Type
    ) throws -> (Signature, Selector) {
        let selector = NSSelectorFromString(name)
        guard let entry = class_getInstanceMethod(type, selector) else {
            throw NSError(domain: "NativeTestContacts", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Native XCTest selector unavailable: " + name])
        }
        let types = ["@", ":"] + arguments
        let actualResult = typeEncoding(method_copyReturnType(entry))
        let actualArguments = (0..<method_getNumberOfArguments(entry)).map {
            typeEncoding(method_copyArgumentType(entry, $0))
        }
        guard matches(actualResult, returns), actualArguments.count == types.count,
              zip(actualArguments, types).allSatisfy({ matches($0.0, $0.1) }) else {
            throw NSError(domain: "NativeTestContacts", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "\(name) has result \(actualResult) and arguments \(actualArguments)",
            ])
        }
        return (unsafeBitCast(method_getImplementation(entry), to: signature), selector)
    }

    private static func allocate(_ type: AnyClass) throws -> Unmanaged<AnyObject> {
        typealias Allocate = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
        let (allocate, selector) = try method("alloc", on: object_getClass(type),
                                              returns: "@", arguments: [], as: Allocate.self)
        return try XCTUnwrap(allocate(type as AnyObject, selector))
    }

    static func send(_ contacts: [Contact], named name: String) throws {
        typealias RecordInit = @convention(c) (AnyObject, Selector, NSString, Int64) -> Unmanaged<AnyObject>?
        typealias PathInit = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Unmanaged<AnyObject>?
        typealias Add = @convention(c) (AnyObject, Selector, AnyObject) -> Void
        typealias Move = @convention(c) (AnyObject, Selector, CGPoint, Double) -> Void
        typealias Lift = @convention(c) (AnyObject, Selector, Double) -> Void
        let recordType: AnyClass = try XCTUnwrap(NSClassFromString("XCSynthesizedEventRecord"))
        let pathType: AnyClass = try XCTUnwrap(NSClassFromString("XCPointerEventPath"))
        let pointArguments = ["{CGPoint=dd}", "d"]
        let (makeRecord, recordSelector) = try method("initWithName:interfaceOrientation:", on: recordType,
                                                     returns: "@", arguments: ["@", "q"], as: RecordInit.self)
        let (makePath, pathSelector) = try method("initForTouchAtPoint:offset:", on: pathType,
                                                 returns: "@", arguments: pointArguments, as: PathInit.self)
        let (add, addSelector) = try method("addPointerEventPath:", on: recordType,
                                            returns: "v", arguments: ["@"], as: Add.self)
        let (move, moveSelector) = try method("moveToPoint:atOffset:", on: pathType,
                                              returns: "v", arguments: pointArguments, as: Move.self)
        let (lift, liftSelector) = try method("liftUpAtOffset:", on: pathType,
                                              returns: "v", arguments: ["d"], as: Lift.self)
        let record = try XCTUnwrap(makeRecord(try allocate(recordType).takeUnretainedValue(), recordSelector,
                                             name as NSString, Int64(UIInterfaceOrientation.portrait.rawValue))).takeRetainedValue()
        var next = 0.04
        for contact in contacts {
            let path = try XCTUnwrap(makePath(try allocate(pathType).takeUnretainedValue(), pathSelector,
                                             contact.start, next)).takeRetainedValue()
            if contact.start != contact.end {
                let samples = max(4, Int(contact.duration / 0.02) - 2)
                for sample in 1...samples {
                    let fraction = CGFloat(sample) / CGFloat(samples)
                    let position = CGPoint(x: contact.start.x + (contact.end.x - contact.start.x) * fraction,
                                           y: contact.start.y + (contact.end.y - contact.start.y) * fraction)
                    move(path, moveSelector, position, next + 0.02 + Double(fraction) * (contact.duration - 0.04))
                }
            }
            lift(path, liftSelector, next + contact.duration)
            add(record, addSelector, path)
            next += contact.duration + contact.pauseAfterLift
        }

        try deliver(record)
    }

    private typealias EventSynthesizer = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    private typealias Completion = @convention(block) (ObjCBool, NSError?) -> Void
    private typealias Synthesize = @convention(c) (AnyObject, Selector, AnyObject, Completion) -> Void

    private static func simulatorEventProxy() throws -> (AnyObject, Synthesize, Selector) {
        let device = XCUIDevice.shared
        let (findSynthesizer, synthSelector) = try method("eventSynthesizer", on: object_getClass(device),
                                                         returns: "@", arguments: [], as: EventSynthesizer.self)
        guard let proxy = findSynthesizer(device, synthSelector)?.takeUnretainedValue() else {
            throw NSError(domain: "NativeTestContacts", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The simulator has no XCTest event proxy"])
        }
        let (synthesize, sendSelector) = try method("synthesizeEvent:completion:", on: object_getClass(proxy),
                                                    returns: "v", arguments: ["@", "@?"], as: Synthesize.self)
        return (proxy, synthesize, sendSelector)
    }

    private static func deliver(_ record: AnyObject) throws {
        let proxy: (AnyObject, Synthesize, Selector)
        do {
            proxy = try simulatorEventProxy()
        } catch {
            // Choose the compatible entry point before any input is sent.
            print("TAKUPOKE_NATIVE_SYNTHESIS_PROXY \(error.localizedDescription)")
            typealias RecordSynthesis = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
            let (synthesize, selector) = try method("synthesizeWithError:", on: object_getClass(record),
                                                     returns: "B", arguments: ["^@"], as: RecordSynthesis.self)
            var nativeError: Unmanaged<AnyObject>?
            let delivered = withUnsafeMutablePointer(to: &nativeError) { error in
                synthesize(record, selector, UnsafeMutableRawPointer(error))
            }
            guard delivered else {
                throw (nativeError?.takeUnretainedValue() as? NSError) ?? NSError(domain: "NativeTestContacts", code: 2)
            }
            // Callers still require the app's real response to the delivered input.
            return
        }
        let (synthesizer, synthesize, sendSelector) = proxy
        let delivered = XCTestExpectation(description: "XCTest delivered all timed contacts as native events")
        var eventError: NSError?
        synthesize(synthesizer, sendSelector, record) { sent, error in
            eventError = error ?? (sent.boolValue ? nil : NSError(domain: "NativeTestContacts", code: 2))
            delivered.fulfill()
        }
        guard XCTWaiter.wait(for: [delivered], timeout: 8) == .completed else {
            throw NSError(domain: "NativeTestContacts", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "The native synthesizer did not return"])
        }
        if let eventError { throw eventError }
    }
}
