import Foundation
import Photos
import SwiftUI

@MainActor
final class ReviewSessionStore: ObservableObject {
    @Published private(set) var phase: ReviewPhase = .loading
    @Published private(set) var progress = ReviewProgress()
    @Published private(set) var currentGroupAssetIDs: [String] = []
    @Published private(set) var currentGroupMarkedDeleteIDs: Set<String> = []
    @Published private(set) var pendingDeleteIDs: [String] = []
    @Published private(set) var reviewedAssetIDs: Set<String> = []
    @Published private(set) var currentAssetID: String?
    @Published private(set) var currentSwipeHint: String = ""
    @Published private(set) var isDeletingGroup = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var groupSize: Int
    @Published private(set) var datePreference: PhotoDatePreference
    @Published private(set) var pendingKeptIDs: Set<String> = []
    @Published private(set) var deletedPhotoCount: Int
    @Published private(set) var savedByteCount: Int64
    @Published private(set) var hapticsEnabled: Bool

    let service: PhotoLibraryService

    private var groupedAssetIDs: [[String]] = []
    private var currentGroupReviewHistory: [ReviewedAction] = []

    init(service: PhotoLibraryService) {
        self.service = service
        let savedGroupSize = UserDefaults.standard.integer(forKey: StoreKeys.groupSize)
        self.groupSize = savedGroupSize == 0 ? 10 : Self.normalizedGroupSize(savedGroupSize)
        let savedDatePreference = UserDefaults.standard.string(forKey: StoreKeys.datePreference)
        self.datePreference = savedDatePreference.flatMap(PhotoDatePreference.init(rawValue:)) ?? .all
        self.reviewedAssetIDs = Self.loadReviewedAssetIDs()
        self.deletedPhotoCount = UserDefaults.standard.integer(forKey: StoreKeys.deletedPhotoCount)
        self.savedByteCount = Self.loadSavedByteCount()
        self.hapticsEnabled = Self.loadHapticsEnabled()
    }

    func bootstrap() async {
        phase = .loading
        errorMessage = nil

        let status = service.authorizationStatus()
        switch status {
        case .authorized, .limited:
            await reloadSession(preserveReviewedHistory: true)
        case .notDetermined:
            let requested = await service.requestAuthorization()
            switch requested {
            case .authorized, .limited:
                await reloadSession(preserveReviewedHistory: true)
            default:
                phase = .permissionRequired
            }
        default:
            phase = .permissionRequired
        }
    }

    func reloadSession(preserveReviewedHistory: Bool) async {
        errorMessage = nil

        if !preserveReviewedHistory {
            reviewedAssetIDs.removeAll()
            persistReviewedAssetIDs()
        }

        let allAssetIDs = service.fetchImageAssetIDs(preferredDatePreference: datePreference)
        if allAssetIDs.isEmpty {
            groupedAssetIDs = []
            currentGroupAssetIDs = []
            currentAssetID = nil
            currentGroupMarkedDeleteIDs = []
            pendingDeleteIDs = []
            pendingKeptIDs = []
            currentGroupReviewHistory = []
            updateProgress(totalCount: reviewedAssetIDs.count, reviewedCount: reviewedAssetIDs.count)
            phase = reviewedAssetIDs.isEmpty ? .emptyLibrary : .completed
            return
        }

        let remainingAssetIDs = allAssetIDs.filter { !reviewedAssetIDs.contains($0) }

        if remainingAssetIDs.isEmpty {
            groupedAssetIDs = []
            currentGroupAssetIDs = []
            currentAssetID = nil
            currentGroupMarkedDeleteIDs = []
            pendingDeleteIDs = []
            pendingKeptIDs = []
            currentGroupReviewHistory = []
            updateProgress(totalCount: reviewedAssetIDs.count, reviewedCount: reviewedAssetIDs.count)
            phase = .completed
            return
        }

        groupedAssetIDs = Self.chunk(remainingAssetIDs, by: groupSize)
        currentGroupMarkedDeleteIDs = []
        pendingDeleteIDs = []
        pendingKeptIDs = []
        currentGroupReviewHistory = []
        loadGroup(at: 0, totalCount: allAssetIDs.count)
    }

    func openSettings() {
        errorMessage = nil
    }

    func markKeep() {
        guard phase == .reviewing, let assetID = currentAssetID else { return }
        markReviewed(assetID)
        currentGroupReviewHistory.append(ReviewedAction(assetID: assetID, wasMarkedDelete: false))
        currentSwipeHint = "保留"
        advanceToNextAssetOrGroup()
    }

    func markDelete() {
        guard phase == .reviewing, let assetID = currentAssetID else { return }
        markReviewed(assetID)
        currentGroupMarkedDeleteIDs.insert(assetID)
        currentGroupReviewHistory.append(ReviewedAction(assetID: assetID, wasMarkedDelete: true))
        currentSwipeHint = "删除"
        advanceToNextAssetOrGroup()
    }

    func goBackToPreviousPhoto() -> Bool {
        guard phase == .reviewing,
              !currentGroupReviewHistory.isEmpty,
              !currentGroupAssetIDs.isEmpty else {
            return false
        }

        let lastAction = currentGroupReviewHistory.removeLast()
        reviewedAssetIDs.remove(lastAction.assetID)
        if lastAction.wasMarkedDelete {
            currentGroupMarkedDeleteIDs.remove(lastAction.assetID)
            pendingDeleteIDs.removeAll { $0 == lastAction.assetID }
        }
        persistReviewedAssetIDs()

        let currentIndex = min(currentGroupReviewHistory.count, currentGroupAssetIDs.count - 1)
        currentAssetID = currentGroupAssetIDs[currentIndex]
        progress.currentIndexInGroup = currentIndex + 1
        currentSwipeHint = ""
        updateProgress(totalCount: progress.totalCount, reviewedCount: reviewedAssetIDs.count)
        phase = .reviewing
        return true
    }

    func clearSwipeHint() {
        currentSwipeHint = ""
    }

    func clearSwipeHintIfMatches(_ hint: String) {
        guard currentSwipeHint == hint else { return }
        currentSwipeHint = ""
    }

    func setSwipePreview(_ hint: String) {
        currentSwipeHint = hint
    }

    func clearError() {
        errorMessage = nil
    }

    func restartWithCurrentHistory() async {
        await reloadSession(preserveReviewedHistory: true)
    }

    func restartCompletely() async {
        reviewedAssetIDs.removeAll()
        deletedPhotoCount = 0
        savedByteCount = 0
        persistReviewedAssetIDs()
        persistReviewStats()
        await reloadSession(preserveReviewedHistory: true)
    }

    func confirmDeleteCurrentGroup() async {
        let deletingIDs = activePendingDeleteIDs
        guard !deletingIDs.isEmpty else {
            advanceToNextGroup()
            return
        }

        isDeletingGroup = true
        errorMessage = nil
        do {
            let byteCount = await totalByteCount(for: deletingIDs)
            try await service.deleteAssets(localIdentifiers: deletingIDs)
            deletedPhotoCount += deletingIDs.count
            savedByteCount += byteCount
            persistReviewStats()
            isDeletingGroup = false
            pendingDeleteIDs.removeAll()
            pendingKeptIDs.removeAll()
            currentGroupMarkedDeleteIDs.removeAll()
            advanceToNextGroup()
        } catch {
            isDeletingGroup = false
            guard !Self.isUserCancelledDeletion(error) else {
                errorMessage = nil
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func keepPendingPhoto(_ assetID: String) {
        guard pendingDeleteIDs.contains(assetID) else { return }
        pendingKeptIDs.insert(assetID)
        currentGroupMarkedDeleteIDs.remove(assetID)
    }

    func restorePendingPhoto(_ assetID: String) {
        guard pendingDeleteIDs.contains(assetID) else { return }
        pendingKeptIDs.remove(assetID)
        currentGroupMarkedDeleteIDs.insert(assetID)
    }

    func togglePendingPhoto(_ assetID: String) {
        if pendingKeptIDs.contains(assetID) {
            restorePendingPhoto(assetID)
        } else {
            keepPendingPhoto(assetID)
        }
    }

    func keepCurrentGroup() {
        pendingDeleteIDs.removeAll()
        pendingKeptIDs.removeAll()
        currentGroupMarkedDeleteIDs.removeAll()
        advanceToNextGroup()
    }

    func applyGroupSize(_ newValue: Int) async {
        let normalizedValue = Self.normalizedGroupSize(newValue)
        guard groupSize != normalizedValue else { return }
        groupSize = normalizedValue
        persistGroupSize()
        await reloadSession(preserveReviewedHistory: true)
    }

    func applyDatePreference(_ newValue: PhotoDatePreference) async {
        guard datePreference != newValue else { return }
        datePreference = newValue
        persistDatePreference()
        await reloadSession(preserveReviewedHistory: true)
    }

    func applyReviewSettings(groupSize newGroupSize: Int, datePreference newDatePreference: PhotoDatePreference) async {
        groupSize = Self.normalizedGroupSize(newGroupSize)
        datePreference = newDatePreference
        persistGroupSize()
        persistDatePreference()
        await reloadSession(preserveReviewedHistory: true)
    }

    func applyHapticsEnabled(_ isEnabled: Bool) {
        guard hapticsEnabled != isEnabled else { return }
        hapticsEnabled = isEnabled
        UserDefaults.standard.set(isEnabled, forKey: StoreKeys.hapticsEnabled)
        if isEnabled {
            HapticFeedback.shared.prepare()
        }
    }

    var currentGroupCount: Int {
        currentGroupAssetIDs.count
    }

    var currentGroupDeleteCount: Int {
        currentGroupMarkedDeleteIDs.count
    }

    var activePendingDeleteIDs: [String] {
        pendingDeleteIDs.filter { !pendingKeptIDs.contains($0) }
    }

    var currentGroupProgressText: String {
        guard currentGroupCount > 0 else { return "0/0" }
        return "\(min(progress.currentIndexInGroup, currentGroupCount))/\(currentGroupCount)"
    }

    var overallProgressText: String {
        guard progress.totalCount > 0 else { return "0/0" }
        return "\(progress.reviewedCount)/\(progress.totalCount)"
    }

    var totalRemainingCount: Int {
        max(progress.totalCount - progress.reviewedCount, 0)
    }

    var savedSpaceText: String {
        ByteCountFormatter.string(fromByteCount: savedByteCount, countStyle: .file)
    }

    var currentReviewSubtitle: String {
        "每组 \(groupSize) 张"
    }

    private func loadGroup(at index: Int, totalCount: Int) {
        guard index < groupedAssetIDs.count else {
            groupedAssetIDs = []
            currentGroupAssetIDs = []
            currentAssetID = nil
            currentGroupMarkedDeleteIDs = []
            pendingDeleteIDs = []
            pendingKeptIDs = []
            currentGroupReviewHistory = []
            updateProgress(totalCount: totalCount, reviewedCount: reviewedAssetIDs.count)
            phase = .completed
            return
        }

        progress.totalGroups = groupedAssetIDs.count
        progress.currentGroupIndex = index + 1
        currentGroupAssetIDs = groupedAssetIDs[index]
        currentAssetID = currentGroupAssetIDs.first
        currentGroupMarkedDeleteIDs = []
        pendingDeleteIDs = []
        pendingKeptIDs = []
        currentGroupReviewHistory = []
        currentSwipeHint = ""
        progress.currentIndexInGroup = 1
        progress.currentGroupCount = currentGroupAssetIDs.count
        updateProgress(totalCount: totalCount, reviewedCount: reviewedAssetIDs.count)
        phase = .reviewing
    }

    private func advanceToNextAssetOrGroup() {
        guard !currentGroupAssetIDs.isEmpty else { return }

        let nextIndex = progress.currentIndexInGroup
        if nextIndex < currentGroupAssetIDs.count {
            currentSwipeHint = ""
            currentAssetID = currentGroupAssetIDs[nextIndex]
            progress.currentIndexInGroup = nextIndex + 1
            updateProgress(totalCount: progress.totalCount, reviewedCount: reviewedAssetIDs.count)
            phase = .reviewing
            return
        }

        if currentGroupMarkedDeleteIDs.isEmpty {
            advanceToNextGroup(noticeAfterLoad: "本组没有删除\n开启下一组")
        } else {
            pendingDeleteIDs = currentGroupAssetIDs.filter { currentGroupMarkedDeleteIDs.contains($0) }
            pendingKeptIDs = []
            phase = .confirmingDelete
        }
    }

    private func advanceToNextGroup(noticeAfterLoad: String? = nil) {
        let nextIndex = progress.currentGroupIndex
        if nextIndex >= groupedAssetIDs.count {
            currentGroupAssetIDs = []
            currentAssetID = nil
            currentGroupMarkedDeleteIDs = []
            pendingDeleteIDs = []
            pendingKeptIDs = []
            currentGroupReviewHistory = []
            currentSwipeHint = ""
            updateProgress(totalCount: progress.totalCount, reviewedCount: reviewedAssetIDs.count)
            phase = .completed
            return
        }

        loadGroup(at: nextIndex, totalCount: progress.totalCount)
        if let noticeAfterLoad {
            currentSwipeHint = noticeAfterLoad
        }
    }

    private func markReviewed(_ assetID: String) {
        reviewedAssetIDs.insert(assetID)
        persistReviewedAssetIDs()
        progress.reviewedCount = reviewedAssetIDs.count
        updateProgress(totalCount: progress.totalCount, reviewedCount: reviewedAssetIDs.count)
    }

    private func updateProgress(totalCount: Int, reviewedCount: Int) {
        progress.totalCount = max(totalCount, reviewedCount)
        progress.reviewedCount = reviewedCount
    }

    private func persistGroupSize() {
        UserDefaults.standard.set(groupSize, forKey: StoreKeys.groupSize)
    }

    private func persistDatePreference() {
        UserDefaults.standard.set(datePreference.rawValue, forKey: StoreKeys.datePreference)
    }

    private func persistReviewedAssetIDs() {
        let values = Array(reviewedAssetIDs)
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: StoreKeys.reviewedAssetIDs)
        }
    }

    private func persistReviewStats() {
        UserDefaults.standard.set(deletedPhotoCount, forKey: StoreKeys.deletedPhotoCount)
        UserDefaults.standard.set(savedByteCount, forKey: StoreKeys.savedByteCount)
    }

    private func totalByteCount(for assetIDs: [String]) async -> Int64 {
        var total: Int64 = 0
        for assetID in assetIDs {
            total += await service.byteCount(localIdentifier: assetID) ?? 0
        }
        return total
    }

    private static func loadReviewedAssetIDs() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: StoreKeys.reviewedAssetIDs),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(values)
    }

    private static func loadHapticsEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: StoreKeys.hapticsEnabled) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: StoreKeys.hapticsEnabled)
    }

    private static func loadSavedByteCount() -> Int64 {
        guard let value = UserDefaults.standard.object(forKey: StoreKeys.savedByteCount) as? NSNumber else {
            return 0
        }
        return value.int64Value
    }

    private static func isUserCancelledDeletion(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.code == NSUserCancelledError {
            return true
        }

        let message = [nsError.localizedDescription, nsError.localizedFailureReason]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        return message.contains("cancel") || message.contains("取消")
    }

    private static func normalizedGroupSize(_ value: Int) -> Int {
        min(max(value, 5), 30)
    }

    private static func chunk(_ values: [String], by size: Int) -> [[String]] {
        guard size > 0 else { return [values] }
        var result: [[String]] = []
        result.reserveCapacity((values.count / size) + 1)
        var index = 0
        while index < values.count {
            let end = min(index + size, values.count)
            result.append(Array(values[index..<end]))
            index = end
        }
        return result
    }
}

private struct ReviewedAction {
    let assetID: String
    let wasMarkedDelete: Bool
}
