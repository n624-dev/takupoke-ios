import Foundation

enum LinkSearch {
    private static let kana: [String: String] = [
        "あ":"a", "い":"i", "う":"u", "え":"e", "お":"o",
        "か":"ka", "き":"ki", "く":"ku", "け":"ke", "こ":"ko",
        "さ":"sa", "し":"shi", "す":"su", "せ":"se", "そ":"so",
        "た":"ta", "ち":"chi", "つ":"tsu", "て":"te", "と":"to",
        "な":"na", "に":"ni", "ぬ":"nu", "ね":"ne", "の":"no",
        "は":"ha", "ひ":"hi", "ふ":"fu", "へ":"he", "ほ":"ho",
        "ま":"ma", "み":"mi", "む":"mu", "め":"me", "も":"mo",
        "や":"ya", "ゆ":"yu", "よ":"yo",
        "ら":"ra", "り":"ri", "る":"ru", "れ":"re", "ろ":"ro",
        "わ":"wa", "を":"o", "ん":"n",
        "が":"ga", "ぎ":"gi", "ぐ":"gu", "げ":"ge", "ご":"go",
        "ざ":"za", "じ":"ji", "ず":"zu", "ぜ":"ze", "ぞ":"zo",
        "だ":"da", "ぢ":"ji", "づ":"zu", "で":"de", "ど":"do",
        "ば":"ba", "び":"bi", "ぶ":"bu", "べ":"be", "ぼ":"bo",
        "ぱ":"pa", "ぴ":"pi", "ぷ":"pu", "ぺ":"pe", "ぽ":"po",
        "ぁ":"a", "ぃ":"i", "ぅ":"u", "ぇ":"e", "ぉ":"o", "ゔ":"vu",
        "きゃ":"kya", "きゅ":"kyu", "きょ":"kyo",
        "しゃ":"sha", "しゅ":"shu", "しょ":"sho",
        "ちゃ":"cha", "ちゅ":"chu", "ちょ":"cho",
        "にゃ":"nya", "にゅ":"nyu", "にょ":"nyo",
        "ひゃ":"hya", "ひゅ":"hyu", "ひょ":"hyo",
        "みゃ":"mya", "みゅ":"myu", "みょ":"myo",
        "りゃ":"rya", "りゅ":"ryu", "りょ":"ryo",
        "ぎゃ":"gya", "ぎゅ":"gyu", "ぎょ":"gyo",
        "じゃ":"ja", "じゅ":"ju", "じょ":"jo",
        "びゃ":"bya", "びゅ":"byu", "びょ":"byo",
        "ぴゃ":"pya", "ぴゅ":"pyu", "ぴょ":"pyo",
        "うぇ":"we", "うぃ":"wi", "うぉ":"wo", "てぃ":"ti", "でぃ":"di",
        "ふぁ":"fa", "ふぃ":"fi", "ふぇ":"fe", "ふぉ":"fo"
    ]

    private static func hiragana(_ value: String) -> String {
        String(String.UnicodeScalarView(value.unicodeScalars.map { scalar in
            (0x30A1...0x30F6).contains(scalar.value) ? Unicode.Scalar(scalar.value - 0x60)! : scalar
        }))
    }

    private static func canonicalRomaji(_ value: String) -> String {
        value.replacingOccurrences(of: "shi", with: "si")
            .replacingOccurrences(of: "chi", with: "ti")
            .replacingOccurrences(of: "tsu", with: "tu")
            .replacingOccurrences(of: "fu", with: "hu")
            .replacingOccurrences(of: "ji", with: "zi")
    }

    static func normalize(_ value: String) -> String {
        let source = hiragana(value.precomposedStringWithCompatibilityMapping.lowercased())
        let ignored = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)
        let filtered = String(String.UnicodeScalarView(source.unicodeScalars.filter { !ignored.contains($0) }))
        return canonicalRomaji(filtered)
    }

    static func romaji(_ value: String) -> String {
        let source = Array(hiragana(value.precomposedStringWithCompatibilityMapping.lowercased()))
        var result = ""
        var doubled = false
        var index = 0
        while index < source.count {
            let character = source[index]
            if character == "っ" { doubled = true; index += 1; continue }
            if character == "ー" {
                if let last = result.last, "aeiou".contains(last) { result.append(last) }
                index += 1
                continue
            }
            let pair = index + 1 < source.count ? String(source[index...index + 1]) : ""
            let syllable: String
            if let combined = kana[pair] { syllable = combined; index += 2 }
            else { syllable = kana[String(character)] ?? String(character); index += 1 }
            if doubled, let first = syllable.unicodeScalars.first, (97...122).contains(first.value) {
                result.unicodeScalars.append(first)
            }
            doubled = false
            result += syllable
        }
        return canonicalRomaji(result)
    }

    static func score(terms: String, query: String) -> Int {
        let query = normalize(query)
        guard !query.isEmpty else { return -1 }
        var expanded: [String] = []
        for term in terms.split(separator: "|", omittingEmptySubsequences: false) {
            guard !term.isEmpty else { continue }
            let text = String(term)
            expanded.append(text)
            if text.unicodeScalars.contains(where: { (0x3041...0x3096).contains($0.value) }) {
                let value = normalize(romaji(text))
                expanded.append(value)
                expanded.append(value.replacingOccurrences(of: "ou", with: "o")
                    .replacingOccurrences(of: "uu", with: "o")
                    .replacingOccurrences(of: "oo", with: "o"))
            }
        }
        return expanded.enumerated().reduce(-1) { best, entry in
            let (index, term) = entry
            guard !term.isEmpty else { return best }
            if term == query { return max(best, 1000 - index) }
            if term.hasPrefix(query) { return max(best, 800 - index) }
            if term.contains(query) { return max(best, 500 - index) }
            return best
        }
    }
}
