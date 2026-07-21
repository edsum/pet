import SwiftUI
import DeskPetKit

/// 进化页：展示当前形态 + 进化路线 + 进化历史
struct EvolutionView: View {

    @EnvironmentObject var vm: PetViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                currentFormCard
                evolutionPath
                historyCard
            }
            .padding()
        }
        .navigationTitle("进化")
    }

    // MARK: 当前形态

    private var currentFormCard: some View {
        let form = vm.state.form
        return VStack(spacing: 16) {
            ZStack {
                if form.hasGlow {
                    Circle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                }
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 100))
                    .foregroundStyle(formColor(form))
                    .scaleEffect(form.sizeScale)
            }
            .frame(height: 200)

            Text(form.displayName).font(.largeTitle.bold())
            Text("Lv.\(vm.state.level)")
                .font(.headline).foregroundStyle(.secondary)

            if form != .ultimate {
                let nextForm = PetForm(rawValue: form.rawValue + 1)
                if let next = nextForm {
                    Text("达到 Lv.\(next.requiredLevel) 可进化为「\(next.displayName)」")
                        .font(.caption).foregroundStyle(.secondary)
                    let progress = formProgress(next)
                    ProgressView(value: progress)
                        .tint(Color.accentColor)
                        .frame(height: 6)
                        .padding(.horizontal, 32)
                }
            } else {
                Text("已达终极形态").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formColor(_ form: PetForm) -> Color {
        switch form {
        case .baby:     return .orange
        case .teen:     return .yellow
        case .adult:    return .pink
        case .ultimate: return .purple
        }
    }

    private func formProgress(_ next: PetForm) -> Double {
        let current = PetForm.form(for: vm.state.level)
        let currentLevel = current.requiredLevel
        let range = next.requiredLevel - currentLevel
        let done = vm.state.level - currentLevel
        return min(1.0, Double(done) / Double(range))
    }

    // MARK: 进化路线

    private var evolutionPath: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("进化路线").font(.headline)
            HStack(spacing: 8) {
                ForEach(PetForm.allCases, id: \.self) { form in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(formUnlocked(form) ? formColor(form) : Color.gray.opacity(0.2))
                                .frame(width: 48, height: 48)
                            Image(systemName: "pawprint.fill")
                                .foregroundStyle(.white)
                                .scaleEffect(form.sizeScale)
                        }
                        Text(form.displayName).font(.caption2)
                        Text("Lv.\(form.requiredLevel)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formUnlocked(_ form: PetForm) -> Bool {
        vm.state.level >= form.requiredLevel
    }

    // MARK: 进化历史

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("进化记录").font(.headline)
            if vm.state.evolutionHistory.isEmpty {
                Text("还没有进化过")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(Array(vm.state.evolutionHistory.enumerated()), id: \.offset) { idx, date in
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.yellow)
                        Text("第 \(idx + 1) 次进化 → \(PetForm.allCases[min(idx + 1, PetForm.allCases.count - 1)].displayName)")
                            .font(.caption)
                        Spacer()
                        Text(date, style: .date)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
