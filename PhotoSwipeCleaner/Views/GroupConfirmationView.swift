import SwiftUI

struct GroupConfirmationView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if store.pendingDeleteIDs.isEmpty {
                    ContentUnavailableView("没有待删除照片", systemImage: "checkmark.circle", description: Text("这些照片都会保留。"))
                } else {
                    ThumbnailGridView(
                        assetIDs: store.pendingDeleteIDs,
                        selectedIDs: Set(store.activePendingDeleteIDs),
                        onToggle: { assetID in
                            HapticFeedback.shared.selectionChanged()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                store.togglePendingPhoto(assetID)
                            }
                        }
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            let hasPhotosToDelete = !store.activePendingDeleteIDs.isEmpty
                            await store.confirmDeleteCurrentGroup()
                            if store.phase != .confirmingDelete {
                                if hasPhotosToDelete {
                                    HapticFeedback.shared.strongImpact()
                                    HapticFeedback.shared.success()
                                } else {
                                    HapticFeedback.shared.mediumImpact()
                                }
                                dismiss()
                            } else if store.errorMessage != nil {
                                HapticFeedback.shared.error()
                            }
                        }
                    } label: {
                        HStack {
                            if store.isDeletingGroup {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(confirmButtonTitle)
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(store.isDeletingGroup || store.activePendingDeleteIDs.isEmpty)

                    Button {
                        HapticFeedback.shared.lightImpact()
                        store.keepCurrentGroup()
                        dismiss()
                    } label: {
                        Text("取消删除")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isDeletingGroup)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
    }

    private var confirmButtonTitle: String {
        if store.isDeletingGroup {
            return "正在删除..."
        }
        if store.pendingDeleteIDs.isEmpty {
            return "继续下一组"
        }
        return "删除 \(store.activePendingDeleteIDs.count) 张照片"
    }
}
