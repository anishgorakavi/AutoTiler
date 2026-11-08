import XCTest

final class TilingLayoutTests: XCTestCase {
    private let area = CGRect(x: 100, y: 50, width: 1000, height: 600)
    private let gap: CGFloat = 10
    private var usable: CGRect { area.insetBy(dx: gap, dy: gap) }

    func testEveryLayoutFitsInsideTheAreaWithoutOverlap() {
        for kind in LayoutKind.allCases {
            for count in 1...6 {
                let frames = TilingLayout.frames(count: count, in: area, kind: kind, gap: gap)
                XCTAssertEqual(frames.count, count, "\(kind) \(count)")
                for (index, frame) in frames.enumerated() {
                    XCTAssertTrue(usable.insetBy(dx: -0.001, dy: -0.001).contains(frame), "\(kind) \(count) escapes the area")
                    for other in frames[(index + 1)...] {
                        XCTAssertFalse(frame.insetBy(dx: 0.01, dy: 0.01).intersects(other), "\(kind) \(count) overlaps")
                    }
                }
            }
        }
    }

    func testNoWindowsGivesNoFrames() {
        XCTAssertTrue(TilingLayout.frames(count: 0, in: area, kind: .dwindle, gap: gap).isEmpty)
    }

    func testSingleWindowFillsTheUsableArea() {
        for kind in LayoutKind.allCases {
            XCTAssertEqual(TilingLayout.frames(count: 1, in: area, kind: kind, gap: gap), [usable])
        }
    }

    func testHalvesSplitTheWidthWithOneGapBetween() {
        let left = SnapRegion.leftHalf.frame(in: area, gap: gap)
        let right = SnapRegion.rightHalf.frame(in: area, gap: gap)
        XCTAssertEqual(left.minX, usable.minX)
        XCTAssertEqual(right.maxX, usable.maxX, accuracy: 0.001)
        XCTAssertEqual(right.minX - left.maxX, gap, accuracy: 0.001)
        XCTAssertEqual(left.width, right.width, accuracy: 0.001)
        XCTAssertEqual(left.height, usable.height)
    }

    func testTopAndBottomHalvesSplitTheHeightWithOneGapBetween() {
        let top = SnapRegion.topHalf.frame(in: area, gap: gap)
        let bottom = SnapRegion.bottomHalf.frame(in: area, gap: gap)
        XCTAssertEqual(top.minY, usable.minY)
        XCTAssertEqual(bottom.maxY, usable.maxY, accuracy: 0.001)
        XCTAssertEqual(bottom.minY - top.maxY, gap, accuracy: 0.001)
        XCTAssertEqual(top.width, usable.width)
    }

    func testThirdsAreEqualAdjacentColumns() {
        let thirds = [SnapRegion.leftThird, .centerThird, .rightThird].map { $0.frame(in: area, gap: gap) }
        XCTAssertEqual(thirds[0].minX, usable.minX)
        XCTAssertEqual(thirds[2].maxX, usable.maxX, accuracy: 0.001)
        for index in 0..<2 {
            XCTAssertEqual(thirds[index + 1].minX - thirds[index].maxX, gap, accuracy: 0.001)
            XCTAssertEqual(thirds[index].width, thirds[index + 1].width, accuracy: 0.001)
        }
        XCTAssertEqual(thirds[0].width, (usable.width - 2 * gap) / 3, accuracy: 0.001)
    }

    func testZeroGapRegionsTileTheAreaExactly() {
        XCTAssertEqual(SnapRegion.leftHalf.frame(in: area, gap: 0), CGRect(x: 100, y: 50, width: 500, height: 600))
        XCTAssertEqual(SnapRegion.bottomHalf.frame(in: area, gap: 0), CGRect(x: 100, y: 350, width: 1000, height: 300))
    }

    func testSnapRegionsStayInsideTheArea() {
        for region in SnapRegion.allCases {
            XCTAssertTrue(usable.insetBy(dx: -0.001, dy: -0.001).contains(region.frame(in: area, gap: gap)), "\(region)")
        }
    }

    func testQuartersFormAGridWithGapsAndFillTheArea() {
        let topLeft = SnapRegion.topLeft.frame(in: area, gap: gap)
        let topRight = SnapRegion.topRight.frame(in: area, gap: gap)
        let bottomLeft = SnapRegion.bottomLeft.frame(in: area, gap: gap)
        let bottomRight = SnapRegion.bottomRight.frame(in: area, gap: gap)
        XCTAssertEqual(topLeft.minX, usable.minX)
        XCTAssertEqual(topLeft.minY, usable.minY)
        XCTAssertEqual(bottomRight.maxX, usable.maxX, accuracy: 0.001)
        XCTAssertEqual(bottomRight.maxY, usable.maxY, accuracy: 0.001)
        XCTAssertEqual(topRight.minX - topLeft.maxX, gap, accuracy: 0.001)
        XCTAssertEqual(bottomLeft.minY - topLeft.maxY, gap, accuracy: 0.001)
        XCTAssertEqual(topRight.minY, topLeft.minY)
        XCTAssertEqual(bottomRight.minX, topRight.minX)
        XCTAssertEqual(topLeft.size, bottomRight.size)
    }

    func testMaximizedFillsTheUsableArea() {
        XCTAssertEqual(SnapRegion.maximized.frame(in: area, gap: gap), usable)
    }

    func testEveryRegionHasADistinctName() {
        XCTAssertEqual(Set(SnapRegion.allCases.map(\.displayName)).count, SnapRegion.allCases.count)
    }
}
