import Foundation

enum MenuModel {
    static func statusLine(_ state: CheckState) -> String {
        switch state.status {
        case .unknown: "Checking…"
        case .online: "Online"
        case .offline: "Offline"
        case .noTargets: "No targets enabled"
        }
    }

    static func reachabilityLine(_ state: CheckState) -> String? {
        switch state.status {
        case .online, .offline: "\(state.reachable)/\(state.total) reachable"
        case .unknown, .noTargets: nil
        }
    }
}
