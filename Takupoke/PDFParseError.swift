import Foundation

struct PDFParseAttempt: Codable {
    var date: Date
    var sourceDigest: String?
    var failure: PDFParseError?
    var recoveryJob: RecoveryJob? = nil
    var parserVersion: Int? = nil
    static func needsAnalysis(digest: String, parserVersion: Int, analysisDigest: String?, analysisVersion: Int?,
                              attemptDigest: String?, failure: PDFParseError?, attemptVersion: Int?) -> Bool {
        if analysisDigest == digest && analysisVersion == parserVersion { return false }
        if attemptDigest == digest, let failure, failure.code != .cancelled, failure.code != .storage, attemptVersion == parserVersion { return false }
        return true
    }
}
struct PDFParseError: Error, LocalizedError, Codable, Equatable {
    enum Code: String, Codable { case unreadable, unsupported, ambiguous, limit, cancelled, storage }
    // Fixed labels only: never include source text, filenames, URLs or personal data.
    enum Stage: String, Codable, CaseIterable {
        case characterMapping, pageRotation, yearHeading, documentHeading, periodHeading
        case gridColumn, gridRow, gridCell, eventColumns, calendarDates, monthHeading, vectorObjects, textOrder
        case classLabel, gradeLabel, duplicateClass, lessonLines, parallelLessons, emptySubject
        case fragmentOverlap, fragmentAlignment, rasterInput
        case paintVisibility, clippingBounds, contentTags

        var diagnosticCode: String {
            let number: Int
            switch self {
            case .characterMapping: number = 1
            case .pageRotation: number = 2
            case .yearHeading: number = 3
            case .documentHeading: number = 4
            case .periodHeading: number = 5
            case .gridColumn: number = 6
            case .gridRow: number = 7
            case .gridCell: number = 8
            case .eventColumns: number = 9
            case .calendarDates: number = 10
            case .monthHeading: number = 11
            case .vectorObjects: number = 12
            case .textOrder: number = 13
            case .classLabel: number = 14
            case .gradeLabel: number = 15
            case .duplicateClass: number = 16
            case .lessonLines: number = 17
            case .parallelLessons: number = 18
            case .emptySubject: number = 19
            case .fragmentOverlap: number = 20
            case .fragmentAlignment: number = 21
            case .rasterInput: number = 22
            case .paintVisibility: number = 23
            case .clippingBounds: number = 24
            case .contentTags: number = 25
            }
            return String(format: "P%02d", number)
        }

        var label: String {
            switch self {
            case .characterMapping: return "文字と位置の対応（P01）"
            case .pageRotation: return "ページの向き（P02）"
            case .yearHeading: return "年度の見出し（P03）"
            case .documentHeading: return "資料名・学期・ページ数（P04）"
            case .periodHeading: return "時限の見出し（P05）"
            case .gridColumn: return "表の列の罫線（P06）"
            case .gridRow: return "日付の行の罫線（P07）"
            case .gridCell: return "表のセルの罫線（P08）"
            case .eventColumns: return "共通・高松・詫間の見出し（P09）"
            case .calendarDates: return "日付の列（P10）"
            case .monthHeading: return "月の見出し（P11）"
            case .vectorObjects: return "未対応の埋め込み描画（P12）"
            case .textOrder: return "文字の行と読み順（P13）"
            case .classLabel: return "クラス欄（P14）"
            case .gradeLabel: return "学年欄（P15）"
            case .duplicateClass: return "クラス行の重複（P16）"
            case .lessonLines: return "授業欄の行分け（P17）"
            case .parallelLessons: return "並記された授業の対応（P18）"
            case .emptySubject: return "並記された科目の空欄（P19）"
            case .fragmentOverlap: return "文字列断片の位置と読み順（P20）"
            case .rasterInput: return "画像からの文字認識が必要（P22）"
            case .fragmentAlignment: return "文字列断片が属する行（P21）"
            case .paintVisibility: return "文字・罫線・背景の表示（P23）"
            case .clippingBounds: return "表示範囲内の文字と罫線（P24）"
            case .contentTags: return "PDFの表示に関わる情報（P25）"
            }
        }
    }
    var code: Code
    var page: Int? = nil
    var stage: Stage? = nil
    struct Cell: Codable, Equatable {
        var classRow: Int
        var weekday: Int
        var period: Int
        var detectedLines: Int? = nil
        var label: String {
            let days = [1: "月", 2: "火", 3: "水", 4: "木", 5: "金"]
            return "表の上から\(classRow)番目のクラス・\(days[weekday] ?? "?")曜\(period)限" +
                (detectedLines.map { "・検出\($0)行" } ?? "")
        }
    }
    var cell: Cell? = nil
    var geometry: PDFCellGeometryDiagnostic? = nil
    var trace: PDFDiagnosticSnapshot? = nil
    // Fixed identifiers for program rejection sites, never PDF source values.
    enum Branch: String, Codable, CaseIterable {
        case b001 = "R001", b002 = "R002", b003 = "R003"
        case b004 = "R004", b005 = "R005", b006 = "R006"
        case b007 = "R007", b008 = "R008", b009 = "R009"
        case b010 = "R010", b011 = "R011", b012 = "R012"
        case b013 = "R013", b014 = "R014", b015 = "R015"
        case b016 = "R016", b017 = "R017", b018 = "R018"
        case b019 = "R019", b020 = "R020", b021 = "R021"
        case b022 = "R022", b023 = "R023", b024 = "R024"
        case b025 = "R025", b026 = "R026", b027 = "R027"
        case b028 = "R028", b029 = "R029", b030 = "R030"
        case b031 = "R031", b032 = "R032", b033 = "R033"
        case b034 = "R034", b035 = "R035", b036 = "R036"
        case b037 = "R037", b038 = "R038", b039 = "R039"
        case b040 = "R040", b041 = "R041", b042 = "R042"
        case b043 = "R043", b044 = "R044", b045 = "R045"
        case b046 = "R046", b047 = "R047", b048 = "R048"
        case b049 = "R049", b050 = "R050", b051 = "R051"
        case b052 = "R052", b053 = "R053", b054 = "R054"
        case b055 = "R055", b056 = "R056", b057 = "R057"
        case b058 = "R058", b059 = "R059", b060 = "R060"
        case b061 = "R061", b062 = "R062", b063 = "R063"
        case b064 = "R064", b065 = "R065", b066 = "R066"
        case b067 = "R067", b068 = "R068", b069 = "R069"
        case b070 = "R070", b071 = "R071", b072 = "R072"
        case b073 = "R073", b074 = "R074", b075 = "R075"
        case b076 = "R076", b077 = "R077", b078 = "R078"
        case b079 = "R079", b080 = "R080", b081 = "R081"
        case b082 = "R082", b083 = "R083", b084 = "R084"
        case b085 = "R085", b086 = "R086", b087 = "R087"
        case b088 = "R088", b089 = "R089", b090 = "R090"
        case b091 = "R091", b092 = "R092", b093 = "R093"
        case b094 = "R094", b095 = "R095", b096 = "R096"
        case b097 = "R097", b098 = "R098", b099 = "R099"
        case b100 = "R100", b101 = "R101", b102 = "R102"
        case b103 = "R103", b104 = "R104", b105 = "R105"
        case b106 = "R106", b107 = "R107", b108 = "R108"
        case b109 = "R109", b110 = "R110", b111 = "R111"
        case b112 = "R112", b113 = "R113", b114 = "R114"
        case b115 = "R115", b116 = "R116", b117 = "R117"
        case b118 = "R118", b119 = "R119", b120 = "R120"
        case b121 = "R121", b122 = "R122", b123 = "R123"
        case b124 = "R124", b125 = "R125", b126 = "R126"
        case b127 = "R127", b128 = "R128", b129 = "R129"
        case b130 = "R130", b131 = "R131", b132 = "R132"
        case b133 = "R133", b134 = "R134", b135 = "R135"
        case b136 = "R136", b137 = "R137", b138 = "R138"
        case b139 = "R139", b140 = "R140", b141 = "R141"
        case b142 = "R142", b143 = "R143", b144 = "R144"
        case b145 = "R145", b146 = "R146", b147 = "R147"
        case b148 = "R148", b149 = "R149", b150 = "R150"
        case b151 = "R151", b152 = "R152", b153 = "R153"
        case b154 = "R154", b155 = "R155", b156 = "R156"
        case b157 = "R157", b158 = "R158", b159 = "R159"
        case b160 = "R160", b161 = "R161", b162 = "R162"
        case b163 = "R163", b164 = "R164", b165 = "R165"
        case b166 = "R166", b167 = "R167", b168 = "R168"
        case b169 = "R169", b170 = "R170", b171 = "R171"
        case b172 = "R172", b173 = "R173", b174 = "R174"
        case b175 = "R175", b176 = "R176", b177 = "R177"
        case b178 = "R178", b179 = "R179", b180 = "R180"
        case b181 = "R181", b182 = "R182", b183 = "R183"
        case b184 = "R184", b185 = "R185", b186 = "R186"
        case b187 = "R187", b188 = "R188", b189 = "R189"
        case b190 = "R190", b191 = "R191", b192 = "R192"
        case b193 = "R193", b194 = "R194", b195 = "R195"
        case b196 = "R196", b197 = "R197", b198 = "R198"
        case b199 = "R199", b200 = "R200", b201 = "R201"
        case b202 = "R202", b203 = "R203", b204 = "R204"
        case b205 = "R205", b206 = "R206", b207 = "R207"
        case b208 = "R208", b209 = "R209", b210 = "R210"
        case b211 = "R211", b212 = "R212", b213 = "R213"
        case b214 = "R214", b215 = "R215", b216 = "R216"
        case b217 = "R217", b218 = "R218", b219 = "R219"
        case b220 = "R220", b221 = "R221", b222 = "R222"
        case b223 = "R223", b224 = "R224", b225 = "R225"
        case b226 = "R226", b227 = "R227", b228 = "R228"
        case b229 = "R229", b230 = "R230", b231 = "R231"
        case b232 = "R232", b233 = "R233", b234 = "R234"
        case b235 = "R235", b236 = "R236", b237 = "R237"
        case b238 = "R238", b239 = "R239", b240 = "R240"
        case b241 = "R241", b242 = "R242", b243 = "R243"
        case b244 = "R244", b245 = "R245", b246 = "R246"
        case b247 = "R247", b248 = "R248", b249 = "R249"
        case b250 = "R250", b251 = "R251", b252 = "R252"
        case b253 = "R253", b254 = "R254", b255 = "R255"
        case b256 = "R256", b257 = "R257", b258 = "R258"
        case b259 = "R259", b260 = "R260", b261 = "R261"
        case b262 = "R262"
        case b263 = "R263", b264 = "R264", b265 = "R265"
        case b266 = "R266", b267 = "R267"
        case b268 = "R268", b269 = "R269"
        case b270 = "R270"
        case b272 = "R272"
        case b273 = "R273"
        case b274 = "R274"
        case b275 = "R275"
        case b276 = "R276"
        case b277 = "R277"
        case b278 = "R278"
        case b279 = "R279"
        case b280 = "R280"
        case b281 = "R281"
        case b282 = "R282"
        case b283 = "R283"
        case b284 = "R284"
        case b285 = "R285"
        case b286 = "R286"
        case b287 = "R287"
        case b288 = "R288"
        case b289 = "R289"
        case b290 = "R290"
        case b291 = "R291"
        case b292 = "R292"
        case b293 = "R293"
        case b294 = "R294"
        case b295 = "R295"
        case b296 = "R296"
        case b297 = "R297"
        case b298 = "R298"
        case b299 = "R299"
        case b300 = "R300"
        case b301 = "R301"
        case b302 = "R302"
        case b303 = "R303"
        case b304 = "R304"
        case b305 = "R305"
        case b306 = "R306"
        case b307 = "R307"
        case b308 = "R308"
        case b309 = "R309"
        case b310 = "R310"
        case b311 = "R311"
        case b312 = "R312"
        case b313 = "R313"
        case b314 = "R314"
        case b315 = "R315"
        case b316 = "R316"
        case b317 = "R317"
        case b318 = "R318"
        case b319 = "R319"
        case b320 = "R320"
        case b321 = "R321"
        case b322 = "R322"
        case b323 = "R323"
        case b324 = "R324"
        case b325 = "R325"
        case b326 = "R326"
        case b327 = "R327"
        case b328 = "R328"
        case b329 = "R329"
        case b330 = "R330"
        case b331 = "R331"
        case b332 = "R332"
        case b333 = "R333"
        case b334 = "R334"
        case b335 = "R335"
        case b336 = "R336"
        case b337 = "R337"
        case b338 = "R338"
        case b339 = "R339"
        case b340 = "R340"
        case b341 = "R341"
        case b342 = "R342"
        case b343 = "R343"
        case b344 = "R344"
        case b345 = "R345"
        case b346 = "R346"
        case b347 = "R347"
        case b348 = "R348"
        case b349 = "R349"
        case b350 = "R350"
        case b351 = "R351"
        case b352 = "R352"
        case b353 = "R353"
        case b354 = "R354"
        case b355 = "R355"
        case b356 = "R356"
        case b357 = "R357"
        case b358 = "R358"
        case b359 = "R359"
        case b360 = "R360"
        case b361 = "R361"
        case b362 = "R362"
        case b363 = "R363"
        case b364 = "R364"
        case b365 = "R365"
        case b366 = "R366"
        case b367 = "R367"
        case b368 = "R368"
        case b369 = "R369"
        case b370 = "R370"
        case b371 = "R371"
        case b372 = "R372"
        case b373 = "R373"
        case b374 = "R374"
        case b375 = "R375"
        case b376 = "R376"
        case b377 = "R377"
        case b378 = "R378"
        case b379 = "R379"
        case b380 = "R380"
        case b381 = "R381"
        case b382 = "R382"
        case b383 = "R383"
        case b384 = "R384"
        case b385 = "R385"
        case b386 = "R386"
        case b387 = "R387"
        case b388 = "R388"
        case b389 = "R389"
        case b390 = "R390"
        case b391 = "R391"
        case b392 = "R392"
        case b393 = "R393"
        case b394 = "R394"
        case b395 = "R395"
        case b396 = "R396"
        case b397 = "R397"
        case b398 = "R398"
        case b399 = "R399"
        case b400 = "R400"
        case b401 = "R401"
        case b402 = "R402"
        case b403 = "R403"
        case b404 = "R404"
        case b405 = "R405"
        case b406 = "R406"
        case b407 = "R407"
        case b408 = "R408"
        case b409 = "R409"
        case b410 = "R410"
        case b411 = "R411"
        case b412 = "R412"
        case b413 = "R413"
        case b414 = "R414"
        case b415 = "R415"
        case b416 = "R416"
        case b417 = "R417"
        case b418 = "R418"
        case b419 = "R419"
        case b420 = "R420"
        case b421 = "R421"
        case b422 = "R422"
        // R423 was reserved for a withdrawn, unpublished vertical-label experiment. Do not reuse.
        case b424 = "R424"
        case b425 = "R425"
        case b271 = "R271"
    }
    var branch: Branch? = nil
    var diagnosticReport: String? {
        guard trace != nil || geometry != nil else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(self), let json = String(data: data, encoding: .utf8) else { return nil }
        return (trace == nil ? "TAKUPOKE-PDF-GEOMETRY-1\n" : "TAKUPOKE-PDF-TRACE-1\n") + json
    }
    var userMessage: String {
        switch code {
        case .unreadable: return "PDFを読み取れませんでした。"
        case .unsupported: return "PDFを解析できませんでした。対応していない書式が含まれています。"
        case .ambiguous: return "PDFの内容を確実に読み取れないため、解析を停止しました。"
        case .limit: return "PDFの解析上限を超えています。"
        case .cancelled: return "PDF解析を中止しました。"
        case .storage: return "PDF解析結果を保存できませんでした。"
        }
    }
    var retentionMessage: String { "前回の正常な解析結果は保持しています。" }
    var userCode: String? {
        let parts = [stage?.diagnosticCode, branch?.rawValue].compactMap { $0 }
        let code = parts.joined(separator: " / ")
        if let page { return code.isEmpty ? "\(page)ページ目" : "\(code)（\(page)ページ目）" }
        return code.isEmpty ? nil : code
    }
    var errorDescription: String? {
        [userMessage, retentionMessage, userCode.map { "エラーコード：\($0)" }]
            .compactMap { $0 }.joined(separator: " ")
    }
}
