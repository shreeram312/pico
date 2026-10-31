import os

/// Unified logging. Use `.notice` for anything worth seeing after the fact (it is persisted;
/// `.info` is not). Read with:
///   log show --last 5m --predicate 'subsystem == "app.pico.mac"'
enum Log {
    static let app = Logger(subsystem: "app.pico.mac", category: "app")
}
