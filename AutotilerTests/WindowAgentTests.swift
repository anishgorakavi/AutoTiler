import XCTest

final class WindowAgentTests: XCTestCase {
    private struct Call {
        let state: String
        let options: [(key: String, description: String)]
    }

    /// Always picks the first offered option and records every call.
    private final class RecordingChooser {
        var calls: [Call] = []
        var forcedKey: String?

        func choose(state: String, options: [(key: String, description: String)]) async throws -> String {
            calls.append(Call(state: state, options: options))
            return forcedKey ?? options[0].key
        }
    }

    func testEveryWindowCountHasThatManyDistinctSlots() {
        for count in 1...WindowAgent.maxWindows {
            let slots = WindowAgent.slots(forCount: count)
            XCTAssertEqual(slots.count, count)
            XCTAssertEqual(Set(slots).count, count)
        }
        XCTAssertTrue(WindowAgent.slots(forCount: WindowAgent.maxWindows + 1).isEmpty)
    }

    func testPlanGivesEachWindowItsOwnSlot() async throws {
        let chooser = RecordingChooser()
        let plan = try await WindowAgent.plan(appNames: ["Xcode", "Safari", "Notes", "Terminal"], choose: chooser.choose)
        XCTAssertEqual(plan.count, 4)
        XCTAssertEqual(Set(plan), Set(WindowAgent.slots(forCount: 4)))
    }

    func testLastWindowTakesTheLastSlotWithoutAskingD3() async throws {
        let chooser = RecordingChooser()
        _ = try await WindowAgent.plan(appNames: ["Xcode", "Safari", "Notes"], choose: chooser.choose)
        XCTAssertEqual(chooser.calls.count, 2)
    }

    func testSingleWindowIsMaximizedWithoutAskingD3() async throws {
        let chooser = RecordingChooser()
        let plan = try await WindowAgent.plan(appNames: ["Xcode"], choose: chooser.choose)
        XCTAssertEqual(plan, [.maximized])
        XCTAssertTrue(chooser.calls.isEmpty)
    }

    func testEachStepOffersOnlyFreeSlotsAndReportsWhatIsPlaced() async throws {
        let chooser = RecordingChooser()
        _ = try await WindowAgent.plan(appNames: ["Xcode", "Safari", "Notes", "Terminal"], choose: chooser.choose)
        XCTAssertEqual(chooser.calls.map(\.options.count), [4, 3, 2])
        XCTAssertTrue(chooser.calls[0].state.contains("Xcode"))
        XCTAssertTrue(chooser.calls[0].state.contains("Already placed: nothing"))
        let firstPick = chooser.calls[0].options[0]
        XCTAssertFalse(chooser.calls[1].options.contains { $0.key == firstPick.key })
        XCTAssertTrue(chooser.calls[1].state.contains("Xcode at top left"))
    }

    func testAnAnswerOutsideTheOfferedSlotsFallsBackToTheFirstFreeSlot() async throws {
        let chooser = RecordingChooser()
        chooser.forcedKey = "not-a-slot"
        let plan = try await WindowAgent.plan(appNames: ["Xcode", "Safari"], choose: chooser.choose)
        XCTAssertEqual(plan, [.leftHalf, .rightHalf])
    }

    func testThreeWindowsTellD3WhichSlotIsTheMainOne() async throws {
        let chooser = RecordingChooser()
        _ = try await WindowAgent.plan(appNames: ["Xcode", "Safari", "Notes"], choose: chooser.choose)
        let descriptions = chooser.calls[0].options.map(\.description)
        XCTAssertTrue(descriptions.contains { $0.contains("main app") })
        XCTAssertTrue(descriptions.contains { $0.contains("supporting app") })
    }

    func testMoreThanTheMaximumThrows() async {
        let chooser = RecordingChooser()
        do {
            _ = try await WindowAgent.plan(appNames: Array(repeating: "App", count: 5), choose: chooser.choose)
            XCTFail("expected tooManyWindows")
        } catch let error as WindowAgent.Error {
            guard case .tooManyWindows(5) = error else { return XCTFail("wrong error \(error)") }
        } catch {
            XCTFail("wrong error \(error)")
        }
        XCTAssertTrue(chooser.calls.isEmpty)
    }

    func testNoWindowsGivesAnEmptyPlan() async throws {
        let plan = try await WindowAgent.plan(appNames: [], choose: RecordingChooser().choose)
        XCTAssertTrue(plan.isEmpty)
    }
}
