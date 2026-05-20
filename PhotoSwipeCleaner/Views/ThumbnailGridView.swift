import SwiftUI
import UIKit

struct ThumbnailGridView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    let assetIDs: [String]
    var selectedIDs: Set<String> = []
    var onToggle: ((String) -> Void)?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(assetIDs, id: \.self) { assetID in
                    ThumbnailTile(
                        assetID: assetID,
                        isMarkedForDelete: selectedIDs.contains(assetID),
                        onToggle: onToggle
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 3),
            GridItem(.flexible(), spacing: 3)
        ]
    }
}

private struct ThumbnailTile: View {
    @EnvironmentObject private var store: ReviewSessionStore
    let assetID: String
    let isMarkedForDelete: Bool
    let onToggle: ((String) -> Void)?
    @State private var image: UIImage?
    @State private var metadata: PhotoMetadata?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnail

            if !isMarkedForDelete {
                Color.black.opacity(0.34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if let onToggle {
                Button {
                    onToggle(assetID)
                } label: {
                    Image(systemName: isMarkedForDelete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 27, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            isMarkedForDelete ? .white : .white.opacity(0.86),
                            isMarkedForDelete ? .red : .black.opacity(0.34)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 6, y: 2)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isMarkedForDelete ? "已选择删除，点按取消" : "未选择删除，点按选择")
            }
        }
        .task(id: assetID) {
            async let loadedImage = store.service.requestImage(localIdentifier: assetID, targetSize: CGSize(width: 220, height: 220))
            async let loadedMetadata = store.service.metadata(localIdentifier: assetID)
            image = await loadedImage
            metadata = await loadedMetadata
        }
    }

    private var thumbnail: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(Color(.secondarySystemBackground))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ProgressView()
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ThumbnailRow: View {
    @EnvironmentObject private var store: ReviewSessionStore
    let assetID: String
    let isMarkedForDelete: Bool
    let onRemove: ((String) -> Void)?
    @State private var image: UIImage?
    @State private var metadata: PhotoMetadata?

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            Text(metadataDateText)
                .font(.headline)
                .lineLimit(1)
            Spacer()
        }
        .task(id: assetID) {
            async let loadedImage = store.service.requestImage(localIdentifier: assetID, targetSize: CGSize(width: 220, height: 220))
            async let loadedMetadata = store.service.metadata(localIdentifier: assetID)
            image = await loadedImage
            metadata = await loadedMetadata
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 86, height: 86)
                    .clipped()
            } else {
                ProgressView()
            }
        }
        .frame(width: 86, height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var metadataDateText: String {
        guard let date = metadata?.creationDate else {
            return "时间未知"
        }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
