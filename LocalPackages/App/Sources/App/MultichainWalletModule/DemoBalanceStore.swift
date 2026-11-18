import Combine
import Foundation

/// Local-only display overrides for the wallet home screen.
/// These values must never be passed to transaction or signing flows.
@MainActor
final class DemoBalanceStore: ObservableObject {
    struct Override: Codable, Equatable {
        let amount: String
    }

    struct CustomAsset: Codable, Equatable, Identifiable {
        let id: String
        var name: String
        var symbol: String
        var amount: String
        var unitPrice: String
    }

    private struct Snapshot: Codable {
        var isEnabled: Bool
        var overrides: [String: Override]
        var customAssets: [CustomAsset]

        private enum CodingKeys: String, CodingKey {
            case isEnabled
            case overrides
            case customAssets
        }

        init(isEnabled: Bool, overrides: [String: Override], customAssets: [CustomAsset]) {
            self.isEnabled = isEnabled
            self.overrides = overrides
            self.customAssets = customAssets
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
            overrides = try container.decodeIfPresent([String: Override].self, forKey: .overrides) ?? [:]
            customAssets = try container.decodeIfPresent([CustomAsset].self, forKey: .customAssets) ?? []
        }
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var overrides: [String: Override]
    @Published private(set) var customAssets: [CustomAsset]

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
            customAssets = snapshot.customAssets
        } else {
            isEnabled = false
            overrides = [:]
            customAssets = []
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

    @discardableResult
    func addCustomAsset(name: String, symbol: String, amount: String, unitPrice: String) -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSymbol = symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanName.isEmpty, !cleanSymbol.isEmpty,
              let normalizedAmount = Self.normalizedNonNegativeDecimal(amount),
              let normalizedPrice = Self.normalizedNonNegativeDecimal(unitPrice)
        else { return false }

        customAssets.append(
            CustomAsset(
                id: UUID().uuidString,
                name: cleanName,
                symbol: cleanSymbol,
                amount: normalizedAmount,
                unitPrice: normalizedPrice
            )
        )
        persist()
        return true
    }

    @discardableResult
    func updateCustomAsset(_ asset: CustomAsset) -> Bool {
        guard let index = customAssets.firstIndex(where: { $0.id == asset.id }),
              !asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !asset.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let amount = Self.normalizedNonNegativeDecimal(asset.amount),
              let price = Self.normalizedNonNegativeDecimal(asset.unitPrice)
        else { return false }

        customAssets[index] = CustomAsset(
            id: asset.id,
            name: asset.name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: asset.symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            amount: amount,
            unitPrice: price
        )
        persist()
        return true
    }

    func removeCustomAsset(id: String) {
        customAssets.removeAll { $0.id == id }
        persist()
    }

    func reset() {
        overrides = [:]
        customAssets = []
        isEnabled = false
        persist()
    }

    private static func normalizedNonNegativeDecimal(_ text: String) -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isNumber || $0 == "." }),
              normalized.filter({ $0 == "." }).count <= 1,
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX")),
              value >= .zero
        else { return nil }
        return NSDecimalNumber(decimal: value).stringValue
    }

    private func persist() {
        let snapshot = Snapshot(isEnabled: isEnabled, overrides: overrides, customAssets: customAssets)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
