import Foundation

struct CheckState: Equatable {
    enum Status { case unknown, online, offline, noTargets }
    var status: Status = .unknown
    var reachable = 0
    var total = 0
    var checkedAt: Date?
}

@MainActor
final class Poller {
    var config: AppConfig {
        didSet { if loopTask != nil { restart() } }
    }
    private(set) var state = CheckState()
    var onUpdate: ((CheckState) -> Void)?
    /// Fires when the online/offline status changes and two consecutive cycles agree on it.
    var onTransition: ((CheckState.Status) -> Void)?

    private let prober: Prober
    private let probeTimeout: TimeInterval
    private var loopTask: Task<Void, Never>?
    private var lastRaw: CheckState.Status?
    private var confirmed: CheckState.Status?

    init(prober: Prober, config: AppConfig, probeTimeout: TimeInterval = 3) {
        self.prober = prober
        self.config = config
        self.probeTimeout = probeTimeout
    }

    func start() { restart() }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    func refreshNow() { restart() }

    func didWake() { restart() }

    private func restart() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runCycle()
                let seconds = max(self.config.interval, AppConfig.minInterval)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    /// One probe round over all enabled targets; results from a cancelled round are dropped.
    func runCycle() async {
        let targets = config.targets.filter(\.enabled)
        let prober = self.prober
        let timeout = probeTimeout
        let reachable = await withTaskGroup(of: Bool.self) { group in
            for target in targets {
                group.addTask { await prober.probe(target, timeout: timeout) }
            }
            return await group.reduce(0) { $0 + ($1 ? 1 : 0) }
        }
        guard !Task.isCancelled else { return }
        let status: CheckState.Status = targets.isEmpty ? .noTargets : (reachable > 0 ? .online : .offline)
        state = CheckState(status: status, reachable: reachable, total: targets.count, checkedAt: Date())
        debounce(status)
        onUpdate?(state)
    }

    private func debounce(_ status: CheckState.Status) {
        defer { lastRaw = status }
        guard status == .online || status == .offline else { return }
        guard status == lastRaw, status != confirmed else { return }
        let previous = confirmed
        confirmed = status
        if previous != nil { onTransition?(status) }
    }
}
