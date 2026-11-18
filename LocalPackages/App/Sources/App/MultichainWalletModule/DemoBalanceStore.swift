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
    private var walletID: String?

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

    func setWalletID(_ walletID: String) {
        self.walletID = walletID
    }

    private func scopedKey(for assetId: String) -> String {
        "\(walletID ?? "default")|\(assetId)"
    }

    func savedAmountText(for assetId: String) -> String? {
        overrides[scopedKey(for: assetId)]?.amount
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }
        isEnabled = enabled
        persist()
    }

    func amountText(for assetId: String) -> String? {
        guard isEnabled else { return nil }
        return savedAmountText(for: assetId)
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
            overrides.removeValue(forKey: scopedKey(for: assetId))
            persist()
            return true
        }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        guard normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              normalized.filter({ $0 == "." }).count <= 1
        else {
            return false
        }
        if let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")) {
            guard value >= .zero else { return false }
            overrides[scopedKey(for: assetId)] = Override(amount: normalized)
        } else if normalized == "." {
            // Keep an in-progress decimal separator editable; it is ignored in calculations.
            overrides[scopedKey(for: assetId)] = Override(amount: normalized)
        } else {
            return false
        }
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
