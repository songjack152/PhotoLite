import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    @State private var showSettings = false
    @State private var showOperationTips = false
    @State private var neverShowOperationTips = false
    @State private var suppressOperationTipsThisWeek = false

    var body: some View {
        ZStack {
            Group {
                switch store.phase {
                case .loading:
                    loadingView
                case .permissionRequired:
                    PermissionView()
                case .reviewing:
                    ReviewScreenView(showSettings: $showSettings)
                case .confirmingDelete:
                    ReviewScreenView(showSettings: $showSettings)
                case .completed:
                    completedView
                case .emptyLibrary:
                    emptyView
                case .error(let message):
                    errorView(message: message)
                }
            }

            if showOperationTips {
                OperationTipsView(
                    neverShow: $neverShowOperationTips,
                    suppressThisWeek: $suppressOperationTipsThisWeek,
                    confirm: confirmOperationTips
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.snappy(duration: 0.22), value: showOperationTips)
        .task {
            await store.bootstrap()
            presentOperationTipsIfNeeded()
        }
        .onChange(of: store.phase) { _, _ in
            presentOperationTipsIfNeeded()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
        }
    }

    private func presentOperationTipsIfNeeded() {
        guard store.phase == .reviewing else { return }
        guard !showOperationTips else { return }
        guard !UserDefaults.standard.bool(forKey: StoreKeys.operationTipsNeverShow) else { return }

        let suppressedUntil = UserDefaults.standard.double(forKey: StoreKeys.operationTipsSuppressedUntil)
        if suppressedUntil > Date().timeIntervalSince1970 {
            return
        }

        showOperationTips = true
    }

    private func confirmOperationTips() {
        HapticFeedback.shared.lightImpact()

        if neverShowOperationTips {
            UserDefaults.standard.set(true, forKey: StoreKeys.operationTipsNeverShow)
        } else if suppressOperationTipsThisWeek {
            let nextWeek = Date().addingTimeInterval(7 * 24 * 60 * 60)
            UserDefaults.standard.set(nextWeek.timeIntervalSince1970, forKey: StoreKeys.operationTipsSuppressedUntil)
        }

        showOperationTips = false
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("正在读取图库")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
            Text("图库里没有可处理的照片")
                .font(.headline)
            Button("重新扫描") {
                Task { await store.reloadSession(preserveReviewedHistory: true) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var completedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("本轮处理完成")
                .font(.title2.bold())
            Text("已处理 \(store.overallProgressText) 张")
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("重新开始") {
                    Task { await store.restartCompletely() }
                }
                .buttonStyle(.borderedProminent)

                Button("调整组大小") {
                    showSettings = true
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("出现错误")
                .font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("重试") {
                Task { await store.bootstrap() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct OperationTipsView: View {
    @Binding var neverShow: Bool
    @Binding var suppressThisWeek: Bool
    let confirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.blue)

                    Text("操作提示")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 8) {
                    gestureCue(systemImage: "arrow.left", title: "左滑", subtitle: "下一张")
                    gestureCue(systemImage: "arrow.up", title: "上滑", subtitle: "删除")
                    gestureCue(systemImage: "arrow.right", title: "右滑", subtitle: "上一张")
                }

                VStack(spacing: 7) {
                    tipLine("左滑进入下一张")
                    tipLine("右滑返回上一张")
                    tipLine("上滑标记删除")
                    Text("每组结束后会二次确认，确认后才会调用系统删除。")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }

                VStack(spacing: 0) {
                    checkRow(
                        title: "再也不弹出",
                        isSelected: neverShow
                    ) {
                        neverShow.toggle()
                        if neverShow {
                            suppressThisWeek = false
                        }
                    }

                    Divider()
                        .overlay(.white.opacity(0.10))
                        .padding(.leading, 36)

                    checkRow(
                        title: "本周不弹出",
                        isSelected: suppressThisWeek
                    ) {
                        suppressThisWeek.toggle()
                        if suppressThisWeek {
                            neverShow = false
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(optionPanelBackground)

                Button(action: confirm) {
                    Text("确定")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.blue, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: 320)
            .background(tipsPanelBackground)
            .padding(.horizontal, 28)
        }
    }

    private func tipLine(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.medium))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func gestureCue(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(.blue.opacity(0.16), in: Circle())

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(gestureCueBackground)
    }

    private func checkRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .blue : .white.opacity(0.42))
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.88))

                Spacer()
            }
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .simultaneousGesture(TapGesture().onEnded {
            HapticFeedback.shared.selectionChanged()
        })
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var gestureCueBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: shape)
        } else {
            shape
                .fill(.white.opacity(0.055))
                .background(.ultraThinMaterial, in: shape)
        }
    }

    @ViewBuilder
    private var tipsPanelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.24)).interactive(), in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.52), .white.opacity(0.14), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                }
        } else {
            shape
                .fill(.black.opacity(0.62))
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.16), lineWidth: 0.8)
                }
        }
    }

    @ViewBuilder
    private var optionPanelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: shape)
        } else {
            shape
                .fill(.white.opacity(0.06))
                .background(.ultraThinMaterial, in: shape)
        }
    }
}
