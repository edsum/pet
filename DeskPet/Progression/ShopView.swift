import SwiftUI
import DeskPetKit

/// 商店页：按分类展示商品，支持购买
struct ShopView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var selectedCategory: ShopItem.Category = .food
    @State private var showBoughtToast = false
    @State private var lastBoughtName = ""

    var body: some View {
        VStack(spacing: 0) {
            walletBar

            Picker("分类", selection: $selectedCategory) {
                ForEach(ShopItem.Category.allCases, id: \.self) { cat in
                    Text(cat.displayName).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List(filteredItems) { item in
                shopRow(item)
            }
        }
        .navigationTitle("商店")
        .overlay(alignment: .top) {
            if showBoughtToast {
                toastView
            }
        }
    }

    // MARK: 顶部钱包

    private var walletBar: some View {
        HStack {
            Label("\(vm.state.coins)", systemImage: "bitcoinsign.circle.fill")
                .font(.title3.bold())
            Spacer()
            Label("Lv.\(vm.state.level)", systemImage: "star.fill")
                .font(.subheadline.bold())
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: 单个商品

    private func shopRow(_ item: ShopItem) -> some View {
        HStack(spacing: 12) {
            Text(item.icon).font(.system(size: 36)).frame(width: 50)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text(item.desc).font(.caption).foregroundStyle(.secondary)
                if vm.state.level < item.requiredLevel {
                    Text("需要 Lv.\(item.requiredLevel)")
                        .font(.caption2).foregroundStyle(.red)
                }
            }

            Spacer()

            buyButton(item)
        }
        .padding(.vertical, 4)
    }

    private func buyButton(_ item: ShopItem) -> some View {
        let owned = vm.progression.isOwned(item)
        let canAfford = vm.state.coins >= item.price
        let levelOk = vm.state.level >= item.requiredLevel
        let isPermanent = (item.category == .outfit || item.category == .background)

        if isPermanent && owned {
            return AnyView(
                Label("已拥有", systemImage: "checkmark")
                    .font(.caption).foregroundStyle(.green)
            )
        }

        return AnyView(
            Button {
                buy(item)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bitcoinsign.circle")
                    Text("\(item.price)")
                }
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(canAfford && levelOk ? Color.accentColor : Color.gray.opacity(0.3),
                            in: Capsule())
                .foregroundStyle(.white)
            }
            .disabled(!canAfford || !levelOk)
        )
    }

    // MARK: 过滤

    private var filteredItems: [ShopItem] {
        ShopLibrary.all.filter { $0.category == selectedCategory }
    }

    // MARK: 购买

    private func buy(_ item: ShopItem) {
        var pet = vm.state
        let ok = vm.progression.buy(item, pet: &pet)
        guard ok else { return }
        vm.state = pet
        vm.persist()

        lastBoughtName = item.name
        withAnimation { showBoughtToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showBoughtToast = false }
        }
    }

    private var toastView: some View {
        VStack(spacing: 4) {
            Image(systemName: "bag.fill").font(.title2)
            Text("已购买 \(lastBoughtName)").font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 6)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

extension ShopItem.Category {
    var displayName: String {
        switch self {
        case .food:       return "食物"
        case .outfit:     return "装扮"
        case .background: return "背景"
        case .booster:    return "增益"
        case .consumable: return "消耗品"
        }
    }
}
