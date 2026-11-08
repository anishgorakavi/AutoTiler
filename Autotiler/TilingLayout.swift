import CoreGraphics

enum LayoutKind: String, CaseIterable {
    case dwindle
    case master
    case columns
}

/// A hand-placed position on a screen: a half or a third.
enum SnapRegion: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case leftThird, centerThird, rightThird
    case topLeft, topRight, bottomLeft, bottomRight
    case maximized

    /// Plain-language name, shown to the user and to d3.
    var displayName: String {
        switch self {
        case .leftHalf: return "left half"
        case .rightHalf: return "right half"
        case .topHalf: return "top half"
        case .bottomHalf: return "bottom half"
        case .leftThird: return "left third"
        case .centerThird: return "center third"
        case .rightThird: return "right third"
        case .topLeft: return "top left"
        case .topRight: return "top right"
        case .bottomLeft: return "bottom left"
        case .bottomRight: return "bottom right"
        case .maximized: return "full screen"
        }
    }

    /// Uses the same outer and inner gap as the tiling layouts so snapped windows line up with tiled ones.
    /// `area` is in Accessibility coordinates, so "top" is the smaller y.
    func frame(in area: CGRect, gap: CGFloat) -> CGRect {
        switch self {
        case .leftHalf: return TilingLayout.frames(count: 2, in: area, kind: .columns, gap: gap)[0]
        case .rightHalf: return TilingLayout.frames(count: 2, in: area, kind: .columns, gap: gap)[1]
        case .leftThird: return TilingLayout.frames(count: 3, in: area, kind: .columns, gap: gap)[0]
        case .centerThird: return TilingLayout.frames(count: 3, in: area, kind: .columns, gap: gap)[1]
        case .rightThird: return TilingLayout.frames(count: 3, in: area, kind: .columns, gap: gap)[2]
        case .maximized: return area.insetBy(dx: gap, dy: gap)
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            let usable = area.insetBy(dx: gap, dy: gap)
            let width = (usable.width - gap) / 2
            let height = (usable.height - gap) / 2
            let isLeft = self == .topLeft || self == .bottomLeft
            let isTop = self == .topLeft || self == .topRight
            return CGRect(x: isLeft ? usable.minX : usable.minX + width + gap,
                          y: isTop ? usable.minY : usable.minY + height + gap,
                          width: width, height: height)
        case .topHalf, .bottomHalf:
            let usable = area.insetBy(dx: gap, dy: gap)
            let height = (usable.height - gap) / 2
            let y = self == .topHalf ? usable.minY : usable.minY + height + gap
            return CGRect(x: usable.minX, y: y, width: usable.width, height: height)
        }
    }
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
