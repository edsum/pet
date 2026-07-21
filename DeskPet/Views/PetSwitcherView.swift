import SwiftUI
import DeskPetKit

/// 宠物切换浮层：在主页顶部下拉切换/添加/删除宠物
struct PetSwitcherView: View {

    @EnvironmentObject var vm: PetViewModel
    @SwiftUI.Environment(\.dismiss) var dismiss
    @State private var showAddSheet = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section("我的宠物（\(vm.manager.pets.count)/\(vm.manager.maxPetsDisplay)）") {
                    ForEach(vm.manager.pets) { pet in
                        petRow(pet)
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            vm.manager.removePet(id: vm.manager.pets[i].petID)
                        }
                        vm.refreshCurrentPet()
                    }
                }

                if vm.manager.pets.count < 5 {
                    Section {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("添加新宠物", systemImage: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .navigationTitle("切换宠物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                addSheet
            }
        }
    }

    // MARK: 单行

    private func petRow(_ pet: PetState) -> some View {
        Button {
            vm.manager.switchTo(id: pet.petID)
            vm.refreshCurrentPet()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                PetAvatarView(state: pet, size: 56, disableAnimation: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.name).font(.headline)
                    Text("Lv.\(pet.level) · \(pet.mood.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if pet.petID == vm.manager.currentPetID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: 添加新宠物

    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("新宠物") {
                    TextField("名字", text: $newName)
                    Picker("性格", selection: $newPersonality) {
                        ForEach(PetPersonality.allCases, id: \.self) { p in
                            Text(p.label).tag(p)
                        }
                    }
                }
            }
            .navigationTitle("添加宠物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { showAddSheet = false; newName = "" }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("创建") {
                        let name = newName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        vm.manager.addPet(name: name,
                                          appearance: PetAppearance(personality: newPersonality))
                        vm.refreshCurrentPet()
                        showAddSheet = false
                        newName = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    @State private var newPersonality: PetPersonality = .lively
}

// MARK: - 辅助

extension PetPersonality {
    var label: String {
        switch self {
        case .lively: return "活泼 🌟"
        case .calm:   return "高冷 🐱"
        case .clingy: return "黔人 🐶"
        case .goofy:  return "憨厚 🐻"
        }
    }
}

extension PetManager {
    /// UI 显示用的最大值（与内部 maxPets 同步）
    var maxPetsDisplay: Int { 5 }
}

// MARK: - PetAppearance 便捷构造

public extension PetAppearance {
    init(personality: PetPersonality) {
        self.init(style: .clay, color: "#FFC078",
                  outfit: PetOutfit(), personality: personality)
    }
}
