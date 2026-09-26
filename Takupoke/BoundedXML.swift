import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

final class XMLNode {
    let name: String
    let namespace: String
    let attributes: [String: String]
    var allChildren: [XMLNode] = []
    var children: [XMLNode] { allChildren.filter { $0.namespace == namespace } }
    var text = ""
    init(_ name: String, namespace: String, attributes: [String: String]) {
        self.name = name; self.namespace = namespace; self.attributes = attributes
    }
    func child(_ name: String) -> XMLNode? { children.first { $0.name == name && $0.namespace == namespace } }
}

final class BoundedXML: NSObject, XMLParserDelegate {
    var stack: [XMLNode] = []
    var root: XMLNode?
    var failure: Error?
    var count = 0
    var prefixes: [String: [String]] = [:]
    let check: () throws -> Void
    init(check: @escaping () throws -> Void) { self.check = check }

    static func parse(_ data: Data, root: String, namespace: String, check: @escaping () throws -> Void) throws -> XMLNode {
        // Reject declarations before parsing, including internal entity expansion.
        guard let text = String(data: data, encoding: .utf8),
              text.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil,
              text.range(of: "<!ENTITY", options: .caseInsensitive) == nil else {
            throw ChangeParseError(code: .unsupported)
        }
        let delegate = BoundedXML(check: check)
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true
        parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        let success = parser.parse()
        if let failure = delegate.failure { throw failure }
        guard success, let node = delegate.root, node.name == root, node.namespace == namespace,
              delegate.stack.isEmpty else { throw ChangeParseError(code: .invalidXML) }
        return node
    }
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        prefixes[prefix, default: []].append(namespaceURI)
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = prefixes[prefix]?.popLast() }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        do { try check() } catch { failure = error; parser.abortParsing(); return }
        count += 1
        guard count <= 200_000, stack.count < 64 else { failure = ChangeParseError(code: .limit); parser.abortParsing(); return }
        var attrs: [String: String] = [:]
        for (key, value) in attributes {
            let parts = key.split(separator: ":", maxSplits: 1)
            if parts.count == 2, let uri = prefixes[String(parts[0])]?.last { attrs["{\(uri)}\(parts[1])"] = value }
            else { attrs[key] = value }
        }
        let node = XMLNode(name, namespace: namespaceURI ?? "", attributes: attrs)
        if let parent = stack.last {
            // A duplicate singleton element would make first-match interpretation ambiguous.
            if node.namespace == parent.namespace,
               ["workbookPr", "sheets", "sheetData", "v", "is", "f", "mergeCells"].contains(name),
               parent.children.contains(where: { $0.name == name }) {
                failure = ChangeParseError(code: .invalidXML); parser.abortParsing(); return
            }
            parent.allChildren.append(node)
        } else { root = node }
        stack.append(node)
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let node = stack.last, ["t", "v"].contains(node.name) else { return }
        guard node.text.utf8.count + string.utf8.count <= 4096 else { failure = ChangeParseError(code: .limit); parser.abortParsing(); return }
        node.text += string
    }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let value = String(data: CDATABlock, encoding: .utf8) else { failure = ChangeParseError(code: .invalidXML); parser.abortParsing(); return }
        self.parser(parser, foundCharacters: value)
    }
}
