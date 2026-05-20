import SwiftUI
import UIKit

struct ReviewScreenView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    @Binding var showSettings: Bool
    @State private var dragOffset: CGSize = .zero
    @State private var dragRotationDegrees: Double = 0
    @State private var isAnimatingDecision = false
    @State private var isLoadingImage = false
    @State private var currentImage: UIImage?
    @State private var currentMetadata: PhotoMetadata?
    @State private var isShowingShareSheet = false
    @State private var animatesCardMotion = true
    @State private var transientSwipeHint: String?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            PhotoCardView(
                image: currentImage,
                dragOffset: dragOffset,
                rotationDegrees: dragRotationDegrees,
                swipeHint: transientSwipeHint ?? store.currentSwipeHint,
                animatesMotion: animatesCardMotion
            )
            .padding(.top, 116)
            .padding(.bottom, 132)
            .gesture(dragGesture)
            .task(id: store.currentAssetID) {
                await loadCurrentImage()
            }

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                bottomBar
            }
        }
        .sheet(isPresented: Binding(
            get: { store.phase == .confirmingDelete },
            set: { _ in }
        )) {
            GroupConfirmationView()
                .environmentObject(store)
                .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let currentImage {
                ActivityView(items: [currentImage])
            }
        }
        .alert("提示", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        .onAppear {
            HapticFeedback.shared.prepare()
        }
        .onChange(of: store.currentSwipeHint) { _, hint in
            guard hint == "本组没有删除\n开启下一组" else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_250_000_000)
                store.clearSwipeHintIfMatches(hint)
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("设置")
                .background(edgeButtonBackground)

                Spacer()

                VStack(spacing: 2) {
                    Text(metadataDateLine)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(metadataTimeLine)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.68))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(liquidGlassPanel(cornerRadius: 22))

                Spacer()

                Button {
                    if currentImage != nil {
                        isShowingShareSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(currentImage == nil ? .white.opacity(0.28) : .blue)
                        .frame(width: 38, height: 38)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(currentImage == nil)
                .accessibilityLabel("分享当前照片")
                .background(edgeButtonBackground)
            }

            groupProgressBar
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 14)
        .background(topBarBackground)
    }

    private var groupProgressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.95), .blue.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * groupProgressValue)
                    .animation(.spring(response: 0.32, dampingFraction: 0.86), value: groupProgressValue)
            }
        }
        .frame(width: 142, height: 4)
        .background(progressGlassTrack)
        .accessibilityLabel("本组进度")
        .accessibilityValue(store.currentGroupProgressText)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            metadataRow(systemImage: "location", text: metadataLocationText)
            HStack(spacing: 14) {
                metadataInlineItem(systemImage: "aspectratio", text: metadataSizeText)
                metadataInlineItem(systemImage: "doc", text: metadataFileText)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .frame(width: 300)
        .background(bottomLiquidGlassPanel)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }

    private func metadataRow(systemImage: String, text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func metadataInlineItem(systemImage: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))
                .frame(width: 15)
            Text(text)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
    }

    @ViewBuilder
    private var bottomLiquidGlassPanel: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.black.opacity(0.02))
                .glassEffect(.regular.tint(.black.opacity(0.24)).interactive(), in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.16), .white.opacity(0.06), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                }
                .shadow(color: .black.opacity(0.42), radius: 18, y: 9)
        } else {
            shape
                .fill(.black.opacity(0.20))
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                }
                .shadow(color: .black.opacity(0.40), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var topBarBackground: some View {
        LinearGradient(
            colors: [.black.opacity(0.78), .black.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .top)
    }

    @ViewBuilder
    private var progressGlassTrack: some View {
        let shape = Capsule()

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.08)), in: shape)
                .padding(-5)
        } else {
            shape
                .fill(.white.opacity(0.05))
                .background(.ultraThinMaterial, in: shape)
                .padding(-5)
        }
    }

    @ViewBuilder
    private func liquidGlassPanel(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.10)).interactive(), in: shape)
                .overlay {
                    shape
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.55), .white.opacity(0.18), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                }
                .shadow(color: .black.opacity(0.30), radius: 20, y: 10)
        } else {
            shape
                .fill(.white.opacity(0.04))
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.36), .white.opacity(0.12), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
                .shadow(color: .black.opacity(0.30), radius: 16, y: 8)
        }
    }

    @ViewBuilder
    private var edgeButtonBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.white.opacity(0.03))
                .glassEffect(.regular, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 0.7)
                }
        } else {
            Circle()
                .fill(.black.opacity(0.16))
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.16), lineWidth: 0.7)
                }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isAnimatingDecision else { return }
                let decision = swipeDecision(for: value.translation)
                let tracked = decision == .none
                    ? trajectoryState(for: value.translation)
                    : snapTrajectoryState(for: decision)
                dragOffset = tracked.offset
                dragRotationDegrees = tracked.rotationDegrees

                switch decision {
                case .delete:
                    transientSwipeHint = nil
                    store.setSwipePreview("删除")
                case .keep:
                    transientSwipeHint = nil
                    store.setSwipePreview("下一张")
                case .previous:
                    transientSwipeHint = nil
                    store.setSwipePreview("上一张")
                case .none:
                    if isFirstPhotoPreviousAttempt(value.translation) {
                        transientSwipeHint = "这是第一张"
                        store.clearSwipeHint()
                    } else {
                        transientSwipeHint = nil
                        store.clearSwipeHint()
                    }
                }
            }
            .onEnded { value in
                guard !isAnimatingDecision else { return }
                let decision = swipeDecision(for: value.translation)

                guard decision != .none else {
                    let shouldKeepFirstPhotoHint = isFirstPhotoPreviousAttempt(value.translation)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        dragOffset = .zero
                        dragRotationDegrees = 0
                    }
                    if shouldKeepFirstPhotoHint {
                        HapticFeedback.shared.warning()
                        transientSwipeHint = "这是第一张"
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 950_000_000)
                            if transientSwipeHint == "这是第一张" {
                                transientSwipeHint = nil
                            }
                        }
                    } else {
                        transientSwipeHint = nil
                        store.clearSwipeHint()
                    }
                    return
                }

                playHaptic(for: decision)
                let exitState = exitTrajectoryState(for: decision, from: value.translation)
                isAnimatingDecision = true
                withAnimation(.interpolatingSpring(stiffness: 180, damping: 24)) {
                    dragOffset = exitState.offset
                    dragRotationDegrees = exitState.rotationDegrees
                }

                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    completeDecision(decision)
                }
            }
    }

    private func completeDecision(_ decision: SwipeDecision) {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        animatesCardMotion = false
        withTransaction(transaction) {
            dragOffset = .zero
            dragRotationDegrees = 0
            currentImage = nil
            currentMetadata = nil
            transientSwipeHint = nil
            store.clearSwipeHint()

            switch decision {
            case .delete:
                store.markDelete()
            case .keep:
                store.markKeep()
            case .previous:
                _ = store.goBackToPreviousPhoto()
            case .none:
                break
            }

            isAnimatingDecision = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 40_000_000)
            animatesCardMotion = true
        }
    }

    private func playHaptic(for decision: SwipeDecision) {
        switch decision {
        case .delete:
            HapticFeedback.shared.strongImpact()
        case .keep, .previous:
            HapticFeedback.shared.mediumImpact()
        case .none:
            break
        }
    }

    private func isFirstPhotoPreviousAttempt(_ translation: CGSize) -> Bool {
        let horizontalDominance = abs(translation.width) >= abs(translation.height) * 0.72
        return horizontalDominance
            && translation.width >= 42
            && store.progress.currentIndexInGroup <= 1
    }

    private func loadCurrentImage() async {
        guard let assetID = store.currentAssetID else {
            currentImage = nil
            currentMetadata = nil
            return
        }

        isLoadingImage = true
        currentImage = nil
        currentMetadata = nil
        let targetSize = CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)
        async let image = store.service.requestImage(localIdentifier: assetID, targetSize: targetSize)
        async let metadata = store.service.metadata(localIdentifier: assetID)
        currentImage = await image
        currentMetadata = await metadata
        isLoadingImage = false
    }

    private func trajectoryState(for translation: CGSize) -> TrajectoryState {
        let circleRadius: CGFloat = min(UIScreen.main.bounds.width * 0.94, 430)
        let arcDragWidth: CGFloat = 92
        let maxArcAngle: CGFloat = .pi * 0.075
        let horizontalDrag = abs(translation.width) * 2.55
        let horizontalProgress = min(horizontalDrag / arcDragWidth, 1)
        let easedProgress = 1 - pow(1 - horizontalProgress, 1.45)

        if translation.height > 0, abs(translation.height) > abs(translation.width) {
            return TrajectoryState(
                offset: CGSize(width: translation.width * 0.08, height: min(translation.height * 0.14, 28)),
                rotationDegrees: 0
            )
        }

        let isDeleteArc = translation.height < 0 && abs(translation.height) > abs(translation.width) * 1.05
        if isDeleteArc {
            let rotation = max(min(translation.width / 38, 12), -12)
            return TrajectoryState(
                offset: CGSize(width: translation.width * 0.34, height: translation.height * 2.45),
                rotationDegrees: Double(rotation)
            )
        }

        guard abs(translation.width) > 1 else {
            return TrajectoryState(
                offset: CGSize(width: 0, height: -circleRadius * easedProgress * 0.08),
                rotationDegrees: 0
            )
        }

        let side: CGFloat = translation.width > 0 ? 1 : -1
        let theta = side * easedProgress * maxArcAngle
        let arcOffset = CGSize(
            width: circleRadius * sin(theta),
            height: circleRadius * (1 - cos(theta))
        )
        let extraDrag = max(horizontalDrag - arcDragWidth, 0)
        let exitX = side * extraDrag
        let tangentSlope = tan(maxArcAngle)
        let exitY = extraDrag * tangentSlope

        return TrajectoryState(
            offset: CGSize(width: arcOffset.width + exitX, height: arcOffset.height + exitY),
            rotationDegrees: Double(theta * 180 / .pi * 0.56)
        )
    }

    private func snapTrajectoryState(for decision: SwipeDecision) -> TrajectoryState {
        let screen = UIScreen.main.bounds
        let snapX = min(screen.width * 0.38, 150)
        let snapY = min(screen.height * 0.17, 138)

        switch decision {
        case .delete:
            return TrajectoryState(
                offset: CGSize(width: 0, height: -snapY),
                rotationDegrees: 0
            )
        case .keep:
            return TrajectoryState(
                offset: CGSize(width: -snapX, height: 16),
                rotationDegrees: -5.4
            )
        case .previous:
            return TrajectoryState(
                offset: CGSize(width: snapX, height: 16),
                rotationDegrees: 5.4
            )
        case .none:
            return TrajectoryState(offset: .zero, rotationDegrees: 0)
        }
    }

    private func exitTrajectoryState(for decision: SwipeDecision, from translation: CGSize) -> TrajectoryState {
        let screen = UIScreen.main.bounds
        switch decision {
        case .delete:
            return TrajectoryState(
                offset: CGSize(width: translation.width * 0.08, height: -(screen.height + 220)),
                rotationDegrees: max(min(Double(translation.width / 36), 8), -8)
            )
        case .keep:
            return TrajectoryState(
                offset: CGSize(width: -(screen.width + 260), height: translation.height * 0.12),
                rotationDegrees: -24
            )
        case .previous:
            return TrajectoryState(
                offset: CGSize(width: screen.width + 260, height: translation.height * 0.12),
                rotationDegrees: 24
            )
        case .none:
            return TrajectoryState(offset: .zero, rotationDegrees: 0)
        }
    }

    private func swipeDecision(for translation: CGSize) -> SwipeDecision {
        let distance = hypot(translation.width, translation.height)
        guard distance >= 62 else { return .none }

        let horizontalDominance = abs(translation.width) >= abs(translation.height) * 0.72
        let verticalDominance = abs(translation.height) >= abs(translation.width) * 0.72

        if horizontalDominance, translation.width <= -54 {
            return .keep
        }

        if horizontalDominance, translation.width >= 54, store.progress.currentIndexInGroup > 1 {
            return .previous
        }

        if verticalDominance, translation.height <= -54 {
            return .delete
        }

        return .none
    }

    private var metadataDateLine: String {
        guard let date = currentMetadata?.creationDate else {
            return isLoadingImage ? "正在读取照片信息" : "时间未知"
        }
        return Self.dateFormatter.string(from: date)
    }

    private var metadataTimeLine: String {
        guard let date = currentMetadata?.creationDate else {
            return isLoadingImage ? "" : "--:--"
        }
        return Self.timeFormatter.string(from: date)
    }

    private var metadataLocationText: String {
        currentMetadata?.locationText ?? "地点未知"
    }

    private var metadataSizeText: String {
        guard let metadata = currentMetadata else {
            return "尺寸"
        }
        return "\(metadata.pixelWidth) × \(metadata.pixelHeight)"
    }

    private var metadataFileText: String {
        guard let byteCount = currentMetadata?.byteCount else {
            return "大小未知"
        }
        return ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    private var groupProgressValue: CGFloat {
        guard store.currentGroupCount > 0 else { return 0 }
        let current = min(max(store.progress.currentIndexInGroup, 1), store.currentGroupCount)
        return CGFloat(current) / CGFloat(store.currentGroupCount)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

private enum SwipeDecision {
    case none
    case keep
    case delete
    case previous
}

private struct TrajectoryState {
    var offset: CGSize
    var rotationDegrees: Double
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
