import SwiftUI
import DeskPetKit

struct SettingsView: View {

    @EnvironmentObject var vm: PetViewModel
    @State private var showGenerateAvatar = false

    var body: some View {
        NavigationStack {
            Form {
                Section("宠物") {
                    TextField("名字", text: .init(get: { vm.state.name },
                                                  set: { vm.state.name = $0; vm.persist() }))
                    Picker("性格", selection: .init(get: { vm.state.appearance.personality },
                                                    set: { vm.state.appearance.personality = $0; vm.persist() })) {
                        ForEach(PetPersonality.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                }

                Section("形象风格") {
                    Picker("风格", selection: .init(get: { vm.state.appearance.style },
                                                    set: { vm.state.appearance.style = $0; vm.persist() })) {
                        ForEach(PetAppearance.Style.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Button {
                        showGenerateAvatar = true
                    } label: {
                        Label("重新生成形象", systemImage: "wand.and.stars")
                    }
                }

                Section("数据") {
                    LabeledContent("等级", value: "\(vm.state.level)")
                    LabeledContent("经验", value: "\(vm.state.exp) / \(vm.state.expToNext())")
                    LabeledContent("金币", value: "\(vm.state.coins)")
                    LabeledContent("上次更新", value: vm.state.lastUpdate.formatted())
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0 (MVP)")
                    Link("Apple Image Playground",
                         destination: URL(string: "https://developer.apple.com/image-playground/")!)
                }
            }
            .navigationTitle("设置")
        }
        .sheet(isPresented: $showGenerateAvatar) {
            GenerateAvatarView()
                .environmentObject(vm)
        }
    }
}
