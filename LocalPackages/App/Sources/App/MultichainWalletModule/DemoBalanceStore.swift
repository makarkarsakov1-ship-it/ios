import Combine
import Foundation

/// Local-only display overrides for the wallet home screen.
/// These values must never be passed to transaction or signing flows.
@MainActor
final class DemoBalanceStore: ObservableObject {
    struct Override: Codable, Equatable {
        let amount: String
    }

    private struct Snapshot: Codable {
        var isEnabled: Bool
        var overrides: [String: Override]
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var overrides: [String: Override]

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = "com.tonkeeper.demo-balance-mode"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey

        if let data = defaults.data(forKey: storageKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            isEnabled = snapshot.isEnabled
            overrides = snapshot.overrides
        } else {
            isEnabled = false
            overrides = [:]
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        persist()
    }

    func amountText(for assetId: String) -> String? {
        guard isEnabled else { return nil }
        return overrides[assetId]?.amount
    }

    func amount(for assetId: String) -> Decimal? {
        guard let text = amountText(for: assetId) else { return nil }
        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    @discardableResult
    func setAmount(_ text: String, for assetId: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !assetId.isEmpty else { return false }

        if trimmed.isEmpty {
            overrides.removeValue(forKey: assetId)
            persist()
            return true
        }

        guard let value = Decimal(string: trimmed, locale: Locale(identifier: "en_US_POSIX")),
              value >= .zero,
        else {
            return false
        }

        overrides[assetId] = Override(amount: NSDecimalNumber(decimal: value).stringValue)
        persist()
        return true
    }

    func reset() {
        overrides = [:]
        isEnabled = false
        persist()
    }

    private func persist() {
        let snapshot = Snapshot(isEnabled: isEnabled, overrides: overrides)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
