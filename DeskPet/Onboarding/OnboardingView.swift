import SwiftUI
import DeskPetKit

/// 首次启动引导：4 页介绍核心玩法
struct OnboardingView: View {

    @AppStorage("hasFinishedOnboarding") private var hasFinished = false
    @State private var page = 0

    var onFinish: () -> Void

    var body: some View {
        TabView(selection: $page) {
            page1.tag(0)
            page2.tag(1)
            page3.tag(2)
            page4.tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: 第 1 页：欢迎

    private var page1: some View {
        VStack(spacing: 32) {
            Spacer()
            ZStack {
                Circle().fill(Color.orange.opacity(0.85)).frame(width: 200, height: 200)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(.white)
            }
            .symbolEffect(.bounce)

            VStack(spacing: 12) {
                Text("桌宠 DeskPet")
                    .font(.largeTitle.bold())
                Text("一只住在你手机桌面、锁屏、灵动岛上的电子宠物")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Spacer()

            nextButton("开始")
        }
        .padding()
    }

    // MARK: 第 2 页：互动玩法

    private var page2: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack(spacing: 16) {
                iconCard("hand.draw.fill", "摸摸头", "加心情", .pink)
                iconCard("fork.knife", "喂食", "加饱腹", .orange)
                iconCard("drop.fill", "洗澡", "加清洁", .blue)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                Text("和它互动")
                    .font(.title.bold())
                Text("单击摸头、长按喂食、双击让它跳，\n还能拖拽投掷")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            nextButton("下一步")
        }
        .padding()
    }

    // MARK: 第 3 页：系统事件

    private var page3: some View {
        VStack(spacing: 24) {
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                eventCard("bolt.circle.fill", "充电", .green)
                eventCard("moon.zzz.fill", "夜间", .indigo)
                eventCard("figure.walk", "步数达标", .orange)
                eventCard("music.note", "戴耳机", .pink)
            }
            .padding(.horizontal)

            VStack(spacing: 8) {
                Text("它会懂你")
                    .font(.title.bold())
                Text("充电时吃饭、夜间睡觉、走路达标会庆祝，\n它在用自己的方式陪你")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            nextButton("下一步")
        }
        .padding()
    }

    // MARK: 第 4 页：生成形象 + 完成

    private var page4: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color.purple.opacity(0.2)).frame(width: 200, height: 200)
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 80))
                    .foregroundStyle(.purple)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 8) {
                Text("生成你家的宠物")
                    .font(.title.bold())
                Text("拍一张你宠物的照片，用 Image Playground\n生成独一无二的卡通形象")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    hasFinished = true
                    onFinish()
                } label: {
                    Text("开始养成")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button("先用默认形象") {
                    hasFinished = true
                    onFinish()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: 复用组件

    private func nextButton(_ title: String) -> some View {
        Button {
            withAnimation { page += 1 }
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
        }
    }

    private func iconCard(_ icon: String, _ title: String, _ desc: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(color)
            Text(title).font(.headline)
            Text(desc).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func eventCard(_ icon: String, _ title: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(color)
            Text(title).font(.caption.bold())
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
