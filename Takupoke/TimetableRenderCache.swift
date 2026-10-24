import Foundation

/// Literal rendering must not reuse a differently encoded transcription.
struct TimetableRenderedText: Hashable {
    let value: String
    static func == (lhs:Self,rhs:Self) -> Bool { lhs.value.utf8.elementsEqual(rhs.value.utf8) }
    func hash(into hasher:inout Hasher) { hasher.combine(value) }
}

@MainActor
final class TimetableBoundedMemo<Key:Hashable,Value> {
    private struct Entry { let value:Value }
    private var values = [Key:Entry]()
    private let limit:Int
    var count:Int { values.count }
    init(limit:Int) { precondition(limit > 0); self.limit = limit }
    func value(for key:Key,make:() -> Value) -> Value {
        if let entry = values[key] { return entry.value }
        let value = make()
        if values.count >= limit { values.removeAll(keepingCapacity:true) }
        values[key] = Entry(value:value); return value
    }
    func removeAll() { values.removeAll(keepingCapacity:false) }
}

#if canImport(UIKit)
import UIKit

@MainActor
final class TimetableTextMeasurements {
    private enum Metric:Hashable { case width, height }
    private struct Key:Hashable {
        let text:TimetableRenderedText
        let descriptor:UIFontDescriptor
        let pointSize:CGFloat
        let width:CGFloat
        let metric:Metric
    }
    private struct FitKey:Hashable {
        let text:TimetableRenderedText
        let alternatives:[TimetableRenderedText]
        let descriptor:UIFontDescriptor
        let pointSize:CGFloat
        let width:CGFloat
        let lines:Int
    }
    private let metrics = TimetableBoundedMemo<Key,CGFloat>(limit:2048)
    private let fitted = TimetableBoundedMemo<FitKey,String>(limit:1024)
    private var suspended = true
    func resume() { suspended = false }
    func suspend() { metrics.removeAll(); fitted.removeAll(); suspended = true }
    private func measured(_ text:String,font:UIFont,width:CGFloat,metric:Metric) -> CGFloat {
        metrics.value(for:Key(text:.init(value:text),descriptor:font.fontDescriptor,pointSize:font.pointSize,width:width,metric:metric)) {
            let attributes:[NSAttributedString.Key:Any] = [.font:font]
            if metric == .width { return (text as NSString).size(withAttributes:attributes).width }
            return (text as NSString).boundingRect(with:CGSize(width:width,height:.greatestFiniteMagnitude),
                options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:attributes,context:nil).height
        }
    }
    func height(_ text:String,font:UIFont,width:CGFloat) -> CGFloat {
        guard !suspended else { return 0 }
        return max(font.lineHeight,ceil(measured(text,font:font,width:max(1,width),metric:.height)))
    }
    func fits(_ text:String,font:UIFont,width:CGFloat,lines:Int) -> Bool {
        guard !suspended else { return false }
        if lines == 1 { return measured(text,font:font,width:0,metric:.width) <= width }
        return measured(text,font:font,width:width,metric:.height) <= font.lineHeight*CGFloat(lines)+0.5
    }
    func fit(_ text:String,alternatives:[String],font:UIFont,width:CGFloat,lines:Int,make:() -> String) -> String {
        guard !suspended else { return "" }
        return fitted.value(for:FitKey(text:.init(value:text),alternatives:alternatives.map { .init(value:$0) },
            descriptor:font.fontDescriptor,pointSize:font.pointSize,width:width,lines:lines),make:make)
    }
}
#endif
