import Foundation
import CoreLocation
import Photos
import UIKit

enum PhotoLibraryServiceError: LocalizedError {
    case noPermission
    case noAssetFound
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .noPermission:
            return "没有获得相册权限。"
        case .noAssetFound:
            return "未找到照片。"
        case .deleteFailed:
            return "删除失败。"
        }
    }
}

final class PhotoLibraryService {
    private let imageManager = PHCachingImageManager()
    private let thumbnailCache = NSCache<NSString, UIImage>()
    private var locationCache: [String: String] = [:]

    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func fetchImageAssetIDs(preferredDatePreference: PhotoDatePreference = .all) -> [String] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: options)
        var preferredIdentifiers: [String] = []
        var fallbackIdentifiers: [String] = []
        preferredIdentifiers.reserveCapacity(fetchResult.count)
        fallbackIdentifiers.reserveCapacity(fetchResult.count)
        let cutoffDate = Self.cutoffDate(for: preferredDatePreference)

        fetchResult.enumerateObjects { asset, _, _ in
            guard let cutoffDate else {
                preferredIdentifiers.append(asset.localIdentifier)
                return
            }

            if let creationDate = asset.creationDate, creationDate >= cutoffDate {
                preferredIdentifiers.append(asset.localIdentifier)
            } else {
                fallbackIdentifiers.append(asset.localIdentifier)
            }
        }
        return preferredIdentifiers.shuffled() + fallbackIdentifiers.shuffled()
    }

    func fetchAsset(localIdentifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    func metadata(localIdentifier: String) async -> PhotoMetadata? {
        guard let asset = fetchAsset(localIdentifier: localIdentifier) else {
            return nil
        }

        async let byteCount = byteCount(for: asset)
        async let locationText = locationText(for: asset.location)
        return PhotoMetadata(
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            byteCount: await byteCount,
            locationText: await locationText
        )
    }

    func byteCount(localIdentifier: String) async -> Int64? {
        guard let asset = fetchAsset(localIdentifier: localIdentifier) else {
            return nil
        }
        return await byteCount(for: asset)
    }

    func requestImage(localIdentifier: String, targetSize: CGSize) async -> UIImage? {
        let roundedWidth = Int(targetSize.width.rounded())
        let roundedHeight = Int(targetSize.height.rounded())
        let cacheKey = "\(localIdentifier)-\(roundedWidth)x\(roundedHeight)" as NSString

        if let cached = thumbnailCache.object(forKey: cacheKey) {
            return cached
        }

        guard let asset = fetchAsset(localIdentifier: localIdentifier) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast

            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !didResume else { return }

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    didResume = true
                    continuation.resume(returning: nil)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    didResume = true
                    print("Image request failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                if let degraded = info?[PHImageResultIsDegradedKey] as? Bool, degraded {
                    return
                }

                didResume = true
                if let image {
                    self.thumbnailCache.setObject(image, forKey: cacheKey)
                }
                continuation.resume(returning: image)
            }
        }
    }

    func deleteAssets(localIdentifiers: [String]) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        guard assets.count > 0 else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assets)
            }, completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: PhotoLibraryServiceError.deleteFailed)
                }
            })
        }
    }

    private func byteCount(for asset: PHAsset) async -> Int64? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else { return nil }

        var total: Int64 = 0
        for resource in resources {
            guard let size = await byteCount(for: resource) else {
                continue
            }
            total += size
        }

        return total > 0 ? total : nil
    }

    private func byteCount(for resource: PHAssetResource) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false

            var total: Int64 = 0
            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    total += Int64(data.count)
                },
                completionHandler: { error in
                    if error != nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: total)
                    }
                }
            )
        }
    }

    private func locationText(for location: CLLocation?) async -> String? {
        guard let location else { return nil }

        let cacheKey = Self.locationCacheKey(for: location)
        if let cached = locationCache[cacheKey] {
            return cached
        }

        let fallback = Self.coordinateText(for: location)
        let resolved = await reverseGeocodedLocationText(for: location) ?? fallback
        locationCache[cacheKey] = resolved
        return resolved
    }

    private func reverseGeocodedLocationText(for location: CLLocation) async -> String? {
        await withCheckedContinuation { continuation in
            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let street = [placemark.thoroughfare, placemark.subThoroughfare]
                    .compactMap { $0 }
                    .joined(separator: " ")

                let parts = [
                    placemark.name,
                    street.isEmpty ? nil : street,
                    placemark.subLocality,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ]
                .compactMap { $0 }
                .removingDuplicates()

                continuation.resume(returning: parts.isEmpty ? nil : parts.joined(separator: " · "))
            }
        }
    }

    private static func locationCacheKey(for location: CLLocation) -> String {
        let latitude = (location.coordinate.latitude * 10000).rounded() / 10000
        let longitude = (location.coordinate.longitude * 10000).rounded() / 10000
        return "\(latitude),\(longitude)"
    }

    private static func coordinateText(for location: CLLocation) -> String {
        let latitude = String(format: "%.4f", location.coordinate.latitude)
        let longitude = String(format: "%.4f", location.coordinate.longitude)
        return "\(latitude), \(longitude)"
    }

    private static func cutoffDate(for preference: PhotoDatePreference) -> Date? {
        guard let monthCount = preference.monthCount else {
            return nil
        }
        return Calendar.current.date(byAdding: .month, value: -monthCount, to: Date())
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
