import XCTest
@testable import InternetCheck

private struct FakeProber: Prober {
    var answers: [String: Bool] = [:]
    var delay: TimeInterval = 0
    func probe(_ target: Target, timeout: TimeInterval) async -> Bool {
        if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        return answers[target.address] ?? false
    }
}

private func config(_ addresses: [String], enabled: Bool = true) -> AppConfig {
    var config = AppConfig()
    config.targets = addresses.map {
        Target(id: $0, name: $0, address: $0, isBuiltIn: false, enabled: enabled)
    }
    return config
}

/// Prober whose answers can be flipped between cycles.
private final class Switch: @unchecked Sendable { var online = true }
private struct SwitchProber: Prober {
    let sw: Switch
    func probe(_ target: Target, timeout: TimeInterval) async -> Bool { sw.online }
}

@MainActor
final class PollerTests: XCTestCase {
    func testOnlineIfAnyTargetAnswers() async {
        let poller = Poller(prober: FakeProber(answers: ["b": true]), config: config(["a", "b", "c"]))
        await poller.runCycle()
        XCTAssertEqual(poller.state.status, .online)
        XCTAssertEqual(poller.state.reachable, 1)
        XCTAssertEqual(poller.state.total, 3)
    }

    func testOfflineWhenAllFail() async {
        let poller = Poller(prober: FakeProber(), config: config(["a", "b"]))
        await poller.runCycle()
        XCTAssertEqual(poller.state.status, .offline)
        XCTAssertEqual(poller.state.reachable, 0)
        XCTAssertEqual(poller.state.total, 2)
    }

    func testNoTargetsWhenAllDisabled() async {
        let poller = Poller(prober: FakeProber(answers: ["a": true]), config: config(["a"], enabled: false))
        await poller.runCycle()
        XCTAssertEqual(poller.state.status, .noTargets)
        XCTAssertEqual(poller.state.total, 0)
    }

    func testDisabledTargetsAreNotProbed() async {
        var cfg = config(["a", "b"])
        cfg.targets[0].enabled = false
        let poller = Poller(prober: FakeProber(answers: ["a": true]), config: cfg)
        await poller.runCycle()
        XCTAssertEqual(poller.state.status, .offline)
        XCTAssertEqual(poller.state.total, 1)
    }

    func testProbesRunInParallel() async {
        let poller = Poller(prober: FakeProber(answers: ["a": true], delay: 0.3), config: config(["a", "b", "c"]))
        let start = Date()
        await poller.runCycle()
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.7)
    }

    func testTransitionFiresOnlyAfterTwoAgreeingCycles() async {
        let sw = Switch()
        let poller = Poller(prober: SwitchProber(sw: sw), config: config(["a"]))
        var transitions: [CheckState.Status] = []
        poller.onTransition = { transitions.append($0) }

        await poller.runCycle()
        await poller.runCycle()
        XCTAssertEqual(transitions, [], "first confirmed status is the baseline, not a transition")

        sw.online = false
        await poller.runCycle()
        XCTAssertEqual(transitions, [], "a single failed cycle is not confirmed")
        sw.online = true
        await poller.runCycle()
        sw.online = false
        await poller.runCycle()
        XCTAssertEqual(transitions, [], "a blip between online cycles never confirms")

        await poller.runCycle()
        XCTAssertEqual(transitions, [.offline])
        sw.online = true
        await poller.runCycle()
        await poller.runCycle()
        XCTAssertEqual(transitions, [.offline, .online])
    }

    func testRefreshNowRunsImmediately() async {
        let poller = Poller(prober: FakeProber(answers: ["a": true]), config: config(["a"]))
        let updated = expectation(description: "update")
        poller.onUpdate = { _ in updated.fulfill() }
        poller.refreshNow()
        await fulfillment(of: [updated], timeout: 2)
        XCTAssertEqual(poller.state.status, .online)
        poller.stop()
    }

    func testWakeDoesNotConfirmTransitionFromPreSleepCycle() async {
        let sw = Switch()
        var cfg = config(["a"])
        cfg.interval = 3600
        let poller = Poller(prober: SwitchProber(sw: sw), config: cfg)
        var transitions: [CheckState.Status] = []
        poller.onTransition = { transitions.append($0) }
        await poller.runCycle()
        await poller.runCycle()
        sw.online = false
        await poller.runCycle() // pre-sleep failure, not yet confirmed

        let updated = expectation(description: "post-wake cycle")
        poller.onUpdate = { _ in updated.fulfill() }
        poller.didWake()
        await fulfillment(of: [updated], timeout: 2)
        poller.stop()
        XCTAssertEqual(transitions, [], "the first cycle after wake must not confirm on its own")
    }
}
