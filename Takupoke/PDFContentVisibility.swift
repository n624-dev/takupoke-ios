import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// Device color assignments are state, not paint. Reject unsupported visible
// paint when used; an unused white stroke must not reject black filled text.
struct PDFDevicePaint {
    var components = [0.0]
    var count = 1
    #if canImport(CoreGraphics)
    var resolvedSpace: PDFPaintSpace?
    var renderingIntent = CGColorRenderingIntent.defaultIntent
    private var interpretedSpace: PDFPaintSpace? {
        if let resolvedSpace { return resolvedSpace }
        switch count {
        case 1: return PDFPaintSpace(count:1,space:CGColorSpaceCreateDeviceGray())
        case 3: return PDFPaintSpace(count:3,space:CGColorSpaceCreateDeviceRGB())
        case 4: return PDFPaintSpace(count:4,space:CGColorSpaceCreateDeviceCMYK())
        default: return nil
        }
    }
    #endif
    var isBlack: Bool { PDFTextVisibility.blackColor(components, count: count) }
    var isWhite: Bool {
        #if canImport(CoreGraphics)
        if resolvedSpace == nil && (count == 4 ? components == [0,0,0,0] : components.allSatisfy({ $0 == 1 })) { return true }
        if let interpretedSpace {
            guard let rgb = interpretedSpace.rgb(components,intent:renderingIntent) else { return false }
            return rgb.allSatisfy { $0 >= 254.5 / 255 }
        }
        #endif
        return count == 4 ? components == [0, 0, 0, 0] : components.allSatisfy { $0 == 1 }
    }
    var isVisibleInk: Bool {
        guard !isWhite else { return false }
        #if canImport(CoreGraphics)
        if let interpretedSpace {
            guard let rgb = interpretedSpace.rgb(components,intent:renderingIntent) else { return false }
            return rgb.contains { $0 < 254.5 / 255 }
        }
        #endif
        return count == 4 || components.contains { $0 < 254.5 / 255 }
    }
    mutating func device(_ values: [Double], count: Int) throws {
        #if canImport(CoreGraphics)
        resolvedSpace = nil
        #endif
        try set(values, count: count)
    }
    mutating func set(_ values: [Double], count: Int) throws {
        guard [1, 3, 4].contains(count), values.count == count,
              values.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw PDFParseError(code:.unsupported,stage:.paintVisibility)
        }
        self.count = count; components = values
    }
    mutating func space(_ name: String) throws {
        switch name {
        case "DeviceGray": try device([0], count: 1)
        case "DeviceRGB": try device([0, 0, 0], count: 3)
        case "DeviceCMYK": try device([0, 0, 0, 1], count: 4)
        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility)
        }
    }
}

struct PDFPaintColors {
    var fill = PDFDevicePaint(), stroke = PDFDevicePaint()
}

enum PDFClipValidation {
    static func contains(_ outer: PDFBox, _ inner: PDFBox) -> Bool {
        guard [outer.left,outer.top,outer.right,outer.bottom,inner.left,inner.top,inner.right,inner.bottom].allSatisfy(\.isFinite),
              outer.left < outer.right, outer.top < outer.bottom,
              inner.left <= inner.right, inner.top <= inner.bottom else { return false }
        return outer.left <= inner.left && outer.top <= inner.top &&
        inner.right <= outer.right && inner.bottom <= outer.bottom
    }
    static func requireContains(_ boxes: [PDFBox], clips: [PDFBox], work: () throws -> Void = {}, check: () throws -> Void) throws {
        guard clips.count <= 128 else { throw PDFParseError(code: .limit) }
        var comparisons = 0
        for clip in clips { for box in boxes {
            try work()
            comparisons += 1
            guard comparisons <= 1_000_000 else { throw PDFParseError(code: .limit) }
            if comparisons % 128 == 0 { try check() }
            guard contains(clip, box) else { throw PDFParseError(code:.unsupported,stage:.clippingBounds) }
        } }
        try check()
    }
}

#if canImport(CoreGraphics)
import CoreGraphics

extension PDFPaintColors {
    mutating func intent(_ name: String) throws {
        let value: CGColorRenderingIntent
        switch name {
        case "Perceptual": value = .perceptual
        case "RelativeColorimetric": value = .relativeColorimetric
        case "Saturation": value = .saturation
        case "AbsoluteColorimetric": value = .absoluteColorimetric
        default: throw PDFParseError(code:.unsupported,stage:.paintVisibility)
        }
        fill.renderingIntent = value; stroke.renderingIntent = value
    }
    mutating func intent(_ scanner: CGPDFScannerRef) throws {
        var name: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner,&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
        try intent(String(cString:name))
    }
    mutating func applyIntent(_ dictionary: CGPDFDictionaryRef) throws {
        var object: CGPDFObjectRef?, name: UnsafePointer<CChar>?
        guard CGPDFDictionaryGetObject(dictionary,"RI",&object) else { return }
        guard CGPDFDictionaryGetName(dictionary,"RI",&name), let name else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
        try intent(String(cString:name))
    }
}

extension PDFDevicePaint {
    mutating func applyDefault(_ scanner: CGPDFScannerRef, resolver: PDFPaintSpaceResolver) throws {
        resolvedSpace = try resolver.deviceDefault(scanner, count: count)
    }
    mutating func space(_ scanner: CGPDFScannerRef, resolver: PDFPaintSpaceResolver) throws {
        var pointer: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner,&pointer), let pointer else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
        let name = String(cString:pointer)
        if ["DeviceGray", "DeviceRGB", "DeviceCMYK"].contains(name) {
            try space(name); try applyDefault(scanner, resolver: resolver)
        } else {
            let space = try resolver.named(scanner, name: name)
            count = space.count
            components = count == 4 ? [0,0,0,1] : Array(repeating:0,count:count)
            resolvedSpace = space.device ? try resolver.deviceDefault(scanner,count:count) : space
        }
    }
    mutating func color(_ scanner: CGPDFScannerRef) throws {
        if count == 0 {
            // Unsupported unused state may be superseded before any paint.
            // Consume its bounded operands without certifying that color.
            for _ in 0..<32 {
                var object: CGPDFObjectRef?
                if !CGPDFScannerPopObject(scanner,&object) { return }
            }
            throw PDFParseError(code:.limit)
        }
        var values = [Double]()
        for _ in 0..<count {
            var value: CGPDFReal = 0
            guard CGPDFScannerPopNumber(scanner,&value) else { throw PDFParseError(code:.unsupported,stage:.paintVisibility) }
            values.insert(Double(value),at:0)
        }
        try set(values,count:count)
    }
}

// Conservatively support only a single axis-aligned rectangular clipping path.
// Readers additionally require the whole media page to fit each clip. Advance
// and ascent/descent bounds alone cannot prove that glyph outlines fit a clip.
// Retained geometry must also fit, including clips in saved states.
struct PDFRectangularClipPath {
    private var candidate: PDFBox?
    private var occupied = false
    mutating func invalidate() { occupied = true; candidate = nil }
    mutating func reset() { occupied = false; candidate = nil }
    mutating func rectangle(_ n: [Double], matrix: PDFTextMatrix) throws {
        guard !occupied else { candidate = nil; return }
        occupied = true
        let p = [matrix.point(n[0], n[1]), matrix.point(n[0]+n[2], n[1]),
                 matrix.point(n[0]+n[2], n[1]+n[3]), matrix.point(n[0], n[1]+n[3])]
        guard p.allSatisfy({ $0.x.isFinite && $0.y.isFinite }),
              Set(p.map(\.x)).count == 2, Set(p.map(\.y)).count == 2,
              zip(p, Array(p.dropFirst())+[p[0]]).allSatisfy({ a,b in (a.x == b.x) != (a.y == b.y) }) else { return }
        candidate = PDFBox(left: Double(p.map(\.x).min()!), top: Double(p.map(\.y).min()!),
                           right: Double(p.map(\.x).max()!), bottom: Double(p.map(\.y).max()!))
    }
    func clippingBox() throws -> PDFBox {
        guard let candidate else { throw PDFParseError(code:.unsupported,stage:.clippingBounds) }
        return candidate
    }
}

struct PDFMarkedContent {
    private var depth = 0
    mutating func begin(_ scanner: CGPDFScannerRef, properties: Bool) throws {
        guard depth < 64 else { throw PDFParseError(code: .limit) }
        if properties {
            var object: CGPDFObjectRef?
            guard CGPDFScannerPopObject(scanner, &object), let object else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
            var dictionary: CGPDFDictionaryRef?
            if CGPDFObjectGetType(object) == .name {
                var name: UnsafePointer<CChar>?
                guard CGPDFObjectGetValue(object, .name, &name), let name,
                      let resource = CGPDFContentStreamGetResource(CGPDFScannerGetContentStream(scanner), "Properties", String(cString: name)),
                      CGPDFObjectGetValue(resource, .dictionary, &dictionary) else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
            } else if !CGPDFObjectGetValue(object, .dictionary, &dictionary) { throw PDFParseError(code:.unsupported,stage:.contentTags) }
            guard let dictionary else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
            // Only structure ID and language metadata are inert. Replacement,
            // optional-content membership, and unknown entries remain rejected.
            var known = 0, metadataObject: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(dictionary, "MCID", &metadataObject) {
                var value: CGPDFInteger = 0
                guard CGPDFDictionaryGetInteger(dictionary, "MCID", &value), value >= 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
                known += 1
            }
            if CGPDFDictionaryGetObject(dictionary, "Lang", &metadataObject) {
                var language: CGPDFStringRef?
                guard CGPDFDictionaryGetString(dictionary, "Lang", &language), let language,
                      CGPDFStringGetLength(language) <= 256 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
                known += 1
            }
            guard CGPDFDictionaryGetCount(dictionary) == known else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
        }
        var tag: UnsafePointer<CChar>?
        guard CGPDFScannerPopName(scanner, &tag), let tag, String(cString: tag) != "OC" else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
        depth += 1
    }
    mutating func end() throws {
        guard depth > 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
        depth -= 1
    }
    func finish() throws {
        guard depth == 0 else { throw PDFParseError(code:.unsupported,stage:.contentTags) }
    }
}
#endif
