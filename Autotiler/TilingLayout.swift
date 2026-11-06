import CoreGraphics

enum LayoutKind: String, CaseIterable {
    case dwindle
    case master
    case columns
}

/// Pure geometry: turns a window count and a work area into one frame per window.
/// Frames are returned in the same coordinate space as `area`.
enum TilingLayout {
    static let masterRatio: CGFloat = 0.55

    static func frames(count: Int, in area: CGRect, kind: LayoutKind, gap: CGFloat) -> [CGRect] {
        guard count > 0 else { return [] }
        let usable = area.insetBy(dx: gap, dy: gap)
        guard count > 1 else { return [usable] }

        switch kind {
        case .dwindle: return dwindle(count: count, in: usable, gap: gap)
        case .master: return master(count: count, in: usable, gap: gap)
        case .columns: return columns(count: count, in: usable, gap: gap)
        }
    }

    /// Hyprland-style: each window takes half of the remaining space, splitting along its longer side.
    private static func dwindle(count: Int, in usable: CGRect, gap: CGFloat) -> [CGRect] {
        var remaining = usable
        var result: [CGRect] = []
        for _ in 0..<(count - 1) {
            if remaining.width >= remaining.height {
                let width = (remaining.width - gap) / 2
                result.append(CGRect(x: remaining.minX, y: remaining.minY, width: width, height: remaining.height))
                remaining = CGRect(x: remaining.minX + width + gap, y: remaining.minY, width: width, height: remaining.height)
            } else {
                let height = (remaining.height - gap) / 2
                result.append(CGRect(x: remaining.minX, y: remaining.minY, width: remaining.width, height: height))
                remaining = CGRect(x: remaining.minX, y: remaining.minY + height + gap, width: remaining.width, height: height)
            }
        }
        result.append(remaining)
        return result
    }

    private static func master(count: Int, in usable: CGRect, gap: CGFloat) -> [CGRect] {
        let masterWidth = (usable.width - gap) * masterRatio
        let stackWidth = usable.width - gap - masterWidth
        let stackCount = count - 1
        let stackHeight = (usable.height - gap * CGFloat(stackCount - 1)) / CGFloat(stackCount)

        var result = [CGRect(x: usable.minX, y: usable.minY, width: masterWidth, height: usable.height)]
        for index in 0..<stackCount {
            result.append(CGRect(
                x: usable.minX + masterWidth + gap,
                y: usable.minY + CGFloat(index) * (stackHeight + gap),
                width: stackWidth,
                height: stackHeight))
        }
        return result
    }

    private static func columns(count: Int, in usable: CGRect, gap: CGFloat) -> [CGRect] {
        let width = (usable.width - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).map { index in
            CGRect(x: usable.minX + CGFloat(index) * (width + gap), y: usable.minY, width: width, height: usable.height)
        }
    }
}
