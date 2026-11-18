import KeeperCore
import SwiftUI
import TKLocalize
import TKUIKit

struct WalletBalanceMultichainAssetsListView: View {
    @ObservedObject var viewModel: WalletBalanceMultichainAssetsListViewModel
    @ObservedObject private var demoBalanceStore: DemoBalanceStore
    let showsSkeleton: Bool

    @State private var showsDemoEditor = false

    init(viewModel: WalletBalanceMultichainAssetsListViewModel, showsSkeleton: Bool) {
        self.viewModel = viewModel
        self._demoBalanceStore = ObservedObject(wrappedValue: viewModel.demoBalanceStore)
        self.showsSkeleton = showsSkeleton
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsSkeleton {
                listTitle
                cellsGroup {
                    skeletonRows
                }
            } else {
                switch viewModel.presentation {
                case .error:
                    errorPlaceholder
                case .allAssetsHidden:
                    listTitle
                    cellsGroup {
                        SetupCell(content: allAssetsHiddenCellContent)
                    }
                case let .rows(rows):
                    listTitle
                    cellsGroup {
                        assetRows(rows)
                    }
                }
            }
        }
        .sheet(isPresented: $showsDemoEditor) {
            DemoBalanceEditorView(
                store: demoBalanceStore,
                assets: viewModel.demoAssets
            )
        }
    }

    private func cellsGroup(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .asCellsGroup(config: CellsGroupModifier.Config(horizontalPadding: 0, cornerRadius: 16, backgroundColor: .backgroundContent))
    }

    private func assetRows(_ rows: [WalletBalanceMultichainAssetsListViewModel.Row]) -> some View {
        ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
            let showsDivider = index < rows.count - 1
            switch item {
            case let .asset(row):
                AssetBalanceRowCell(
                    config: .content(row),
                    showsDivider: showsDivider,
                    action: {
                        viewModel.selectAsset(row: row)
                    },
                    commentAction: viewModel.commentAction(for: row)
                )
            case let .moreAssets(previewAvatars):
                WalletBalanceMoreAssetsCell(
                    previewAvatars: previewAvatars,
                    showsDivider: showsDivider,
                    action: {
                        withAnimation(Layout.expandAnimation) {
                            viewModel.expandMoreAssets()
                        }
                    }
                )
            }
        }
    }

    private var errorPlaceholder: some View {
        PlaceholderView(
            config: PlaceholderView.Config(
                lottieResource: .exclamationmarkCircle,
                title: TKLocales.Trade.Placeholder.errorTitle,
                subtitle: TKLocales.Trade.Placeholder.errorSubtitle,
                button: PlaceholderView.ButtonConfig(
                    title: TKLocales.Actions.retry,
                    icon: .TKUIKit.Icons.Size16.refresh,
                    action: {
                        viewModel.onRetry?()
                    }
                )
            )
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Layout.errorTopPadding)
    }

    private var skeletonRows: some View {
        ForEach(0 ..< Layout.skeletonRowCount, id: \.self) { _ in
            AssetBalanceRowCell(
                config: .shimmer,
                showsDivider: false
            )
        }
    }

    private var listTitle: some View {
        HStack(spacing: 8) {
            ListTitleView(config: listTitleConfig)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                showsDemoEditor = true
            } label: {
                Text(demoBalanceStore.isEnabled ? "DEMO ON" : "DEMO")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(demoBalanceStore.isEnabled ? Color.white : Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        demoBalanceStore.isEnabled ? Color.accentColor : Color.accentColor.opacity(0.10),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 7)
    }

    private var listTitleConfig: ListTitleView.Config {
        if showsSkeleton {
            return .shimmer(hasAccessory: true)
        }

        return .text(
            TKLocales.Trade.Assets.title,
            accessory: manageAccessory,
            titleAction: viewModel.onTapOpenAssets
        )
    }

    private var manageAccessory: ListTitleView.Accessory? {
        guard viewModel.canManage else { return nil }
        return ListTitleView.Accessory(
            title: TKLocales.WalletBalanceList.ManageButton.title,
            icon: .TKUIKit.Icons.Size16.sliders,
            foregroundColor: .textSecondary,
            textStyle: .label2,
            action: {
                viewModel.onTapManage?()
            }
        )
    }

    private var allAssetsHiddenCellContent: SetupCellContent {
        SetupCellContent(
            icon: SetupCellContent.Icon(
                image: .TKUIKit.Icons.Size28.eyeClosedOutline,
                tintColor: .iconSecondary,
                backgroundColor: .backgroundContentTint
            ),
            title: TKLocales.WalletBalanceList.AllAssetsHidden.title,
            subtitle: SetupCellContent.Subtitle(
                text: TKLocales.WalletBalanceList.AllAssetsHidden.subtitle
            ),
            accessory: .none
        )
    }
}

private extension WalletBalanceMultichainAssetsListView {
    enum Layout {
        static let errorTopPadding: CGFloat = 32
        static let expandAnimation: Animation = .easeInOut(duration: 0.25)
        static let skeletonRowCount = 10
    }
}


private struct DemoBalanceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DemoBalanceStore
    let assets: [MultichainAsset]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(
                        "Demo Mode",
                        isOn: Binding(
                            get: { store.isEnabled },
                            set: { store.setEnabled($0) }
                        )
                    )
                } footer: {
                    Text("Изменения влияют только на отображение балансов на этом экране. Реальные средства и транзакции не меняются.")
                }

                Section("Баланс активов") {
                    if assets.isEmpty {
                        Text("Сначала дождись загрузки списка активов.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(assets, id: \.asset.assetId) { asset in
                            HStack(spacing: 12) {
                                Text(asset.asset.symbol)
                                    .font(.body.weight(.medium))
                                    .frame(minWidth: 56, alignment: .leading)
                                TextField(
                                    "Демо-количество",
                                    text: Binding(
                                        get: { store.savedAmountText(for: asset.asset.assetId) ?? "" },
                                        set: { _ = store.setAmount($0, for: asset.asset.assetId) }
                                    )
                                )
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }

                Section {
                    Button("Сбросить демо-балансы", role: .destructive) {
                        store.reset()
                    }
                }
            }
            .navigationTitle("Demo Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
