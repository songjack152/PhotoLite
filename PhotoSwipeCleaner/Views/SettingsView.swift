import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    @Binding var isPresented: Bool
    @State private var draftGroupSize: Int
    @State private var draftDatePreference: PhotoDatePreference
    @State private var draftHapticsEnabled: Bool
    @State private var isSyncingDrafts = false

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._draftGroupSize = State(initialValue: 10)
        self._draftDatePreference = State(initialValue: .all)
        self._draftHapticsEnabled = State(initialValue: true)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        section {
                            Stepper(value: $draftGroupSize, in: 5...30, step: 1) {
                                HStack {
                                    Label("每组照片数", systemImage: "rectangle.stack")
                                    Spacer()
                                    Text("\(draftGroupSize)")
                                        .foregroundStyle(.white.opacity(0.62))
                                }
                            }
                            .tint(.blue)
                            .onChange(of: draftGroupSize) { _, newValue in
                                guard !isSyncingDrafts else { return }
                                Task {
                                    await store.applyGroupSize(newValue)
                                }
                            }
                        }

                        section {
                            Menu {
                                ForEach(PhotoDatePreference.allCases) { preference in
                                    Button {
                                        draftDatePreference = preference
                                        Task {
                                            await store.applyDatePreference(preference)
                                        }
                                    } label: {
                                        if draftDatePreference == preference {
                                            Label(preference.title, systemImage: "checkmark")
                                        } else {
                                            Text(preference.title)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Label("照片范围", systemImage: "calendar")
                                    Spacer()
                                    HStack(spacing: 6) {
                                        Text(draftDatePreference.title)
                                            .foregroundStyle(.white.opacity(0.62))
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.36))
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .tint(.blue)
                        }

                        section {
                            Toggle(isOn: $draftHapticsEnabled) {
                                Label("振动反馈", systemImage: "iphone.radiowaves.left.and.right")
                            }
                            .tint(.blue)
                            .onChange(of: draftHapticsEnabled) { _, newValue in
                                guard !isSyncingDrafts else { return }
                                store.applyHapticsEnabled(newValue)
                            }
                        }

                        section {
                            settingsRow(title: "已筛选", value: "\(store.progress.reviewedCount) 张", systemImage: "checkmark.circle")
                            Divider().overlay(.white.opacity(0.10))
                            settingsRow(title: "已删除", value: "\(store.deletedPhotoCount) 张", systemImage: "trash")
                            Divider().overlay(.white.opacity(0.10))
                            settingsRow(title: "节省空间", value: store.savedSpaceText, systemImage: "internaldrive")
                        }

                        section {
                            Button(role: .destructive) {
                                Task {
                                    await store.restartCompletely()
                                }
                                isPresented = false
                            } label: {
                                settingsButtonLabel("清空所有已处理记录", systemImage: "trash", color: .red)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                isSyncingDrafts = true
                draftGroupSize = store.groupSize
                draftDatePreference = store.datePreference
                draftHapticsEnabled = store.hapticsEnabled
                Task { @MainActor in
                    await Task.yield()
                    isSyncingDrafts = false
                }
            }
        }
        .presentationBackground(.black)
    }

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(settingsGlassPanel)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.52))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 22)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.white.opacity(0.62))
        }
        .font(.body)
    }

    private func settingsButtonLabel(_ title: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 22)
            Text(title)
            Spacer()
        }
        .font(.body.weight(.medium))
        .foregroundStyle(color)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var settingsGlassPanel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.10)).interactive(), in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.54), .white.opacity(0.16), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                }
        } else {
            shape
                .fill(.white.opacity(0.04))
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.16), lineWidth: 0.8)
                }
        }
    }
}
