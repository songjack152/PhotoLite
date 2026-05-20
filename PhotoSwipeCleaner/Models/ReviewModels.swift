import Foundation

enum ReviewPhase: Equatable {
    case loading
    case permissionRequired
    case reviewing
    case confirmingDelete
    case completed
    case emptyLibrary
    case error(String)
}

enum SwipeAction {
    case keep
    case delete
}

struct ReviewProgress: Equatable {
    var currentGroupIndex: Int = 0
    var totalGroups: Int = 0
    var currentIndexInGroup: Int = 0
    var currentGroupCount: Int = 0
    var reviewedCount: Int = 0
    var totalCount: Int = 0
}

struct PhotoMetadata: Equatable {
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int64?
    var locationText: String?
}

enum PhotoDatePreference: String, CaseIterable, Identifiable {
    case all
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case fiveYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部照片"
        case .oneMonth:
            return "一个月内"
        case .threeMonths:
            return "三个月内"
        case .sixMonths:
            return "半年内"
        case .oneYear:
            return "一年内"
        case .fiveYears:
            return "五年内"
        }
    }

    var monthCount: Int? {
        switch self {
        case .all:
            return nil
        case .oneMonth:
            return 1
        case .threeMonths:
            return 3
        case .sixMonths:
            return 6
        case .oneYear:
            return 12
        case .fiveYears:
            return 60
        }
    }
}

enum StoreKeys {
    static let reviewedAssetIDs = "photoSwipeCleaner.reviewedAssetIDs"
    static let groupSize = "photoSwipeCleaner.groupSize"
    static let datePreference = "photoSwipeCleaner.datePreference"
    static let deletedPhotoCount = "photoSwipeCleaner.deletedPhotoCount"
    static let savedByteCount = "photoSwipeCleaner.savedByteCount"
    static let operationTipsNeverShow = "photoSwipeCleaner.operationTipsNeverShow"
    static let operationTipsSuppressedUntil = "photoSwipeCleaner.operationTipsSuppressedUntil"
    static let hapticsEnabled = "photoSwipeCleaner.hapticsEnabled"
}
