import Foundation

/// The instruction and the complete picker have disjoint rectangles. The
/// provider's navigation, search, footer and tabs all remain inside the picker.
struct MaterialPickerLayout {
    let instruction: CGRect
    let picker: CGRect

    init(bounds: CGRect, topInset: CGFloat, instructionHeight: CGFloat) {
        let top = min(bounds.maxY, bounds.minY + max(0, topInset) + 8)
        let height = min(max(0, ceil(instructionHeight)), max(0, bounds.maxY - top - 8))
        instruction = CGRect(x: bounds.minX + 12, y: top,
                             width: max(0, bounds.width - 24), height: height)
        let start = min(bounds.maxY, instruction.maxY + 8)
        picker = CGRect(x: bounds.minX, y: start, width: bounds.width, height: bounds.maxY - start)
    }
}
