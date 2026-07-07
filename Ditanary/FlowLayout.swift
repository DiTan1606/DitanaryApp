import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        _ = layout(proposal: proposal, subviews: subviews, bounds: bounds)
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews, bounds: CGRect? = nil) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = bounds?.minX ?? 0
        var currentY: CGFloat = bounds?.minY ?? 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > (bounds?.minX ?? 0) {
                currentX = bounds?.minX ?? 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            if let _ = bounds {
                subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX)
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), positions)
    }
}
