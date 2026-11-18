@testable import App
import XCTest

@MainActor
final class DemoBalanceStoreTests: XCTestCase {
    func test_demoOverrideIsHiddenUntilDemoModeIsEnabledAndPersists() {
        let (suiteName, defaults) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DemoBalanceStore(defaults: defaults)

        XCTAssertTrue(store.setAmount("12.5", for: "ton"))
        XCTAssertNil(store.amountText(for: "ton"))

        store.setEnabled(true)

        XCTAssertEqual(store.amount(for: "ton"), Decimal(string: "12.5"))

        let restored = DemoBalanceStore(defaults: defaults)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(restored.amount(for: "ton"), Decimal(string: "12.5"))
    }

    func test_demoOverridesAreScopedToWallet() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DemoBalanceStore(defaults: defaults)

        store.setWalletID("wallet-a")
        XCTAssertTrue(store.setAmount("5", for: "ton"))
        store.setEnabled(true)

        store.setWalletID("wallet-b")
        XCTAssertNil(store.amount(for: "ton"))
        XCTAssertTrue(store.setAmount("9", for: "ton"))

        store.setWalletID("wallet-a")
        XCTAssertEqual(store.amount(for: "ton"), Decimal(5))

        store.setWalletID("wallet-b")
        XCTAssertEqual(store.amount(for: "ton"), Decimal(9))
    }

    func test_invalidOrNegativeAmountsAreRejected() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DemoBalanceStore(defaults: defaults)

        XCTAssertFalse(store.setAmount("-1", for: "ton"))
        XCTAssertFalse(store.setAmount("1.2.3", for: "ton"))
        XCTAssertNil(store.savedAmountText(for: "ton"))
    }

    func test_resetClearsOverridesAndDisablesDemoMode() {
        let defaults = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DemoBalanceStore(defaults: defaults)

        XCTAssertTrue(store.setAmount("100", for: "ton"))
        store.setEnabled(true)
        store.reset()

        XCTAssertFalse(store.isEnabled)
        XCTAssertNil(store.savedAmountText(for: "ton"))
    }
}

private extension DemoBalanceStoreTests {
    func makeDefaults() -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "DemoBalanceStoreTests.\(UUID().uuidString)"
        return (suiteName, UserDefaults(suiteName: suiteName)!)
    }
}
