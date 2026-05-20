import SwiftUI
import UIKit

struct PhotoCardView: View {
    let image: UIImage?
    let dragOffset: CGSize
    let rotationDegrees: Double
    let swipeHint: String
    let animatesMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                photo

                VStack {
                    if !swipeHint.isEmpty {
                        decisionIndicator
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 18)
            }
        }
    }

    private var photo: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("正在加载照片")
                        .foregroundStyle(.white.secondary)
                }
            }
        }
        .contentShape(Rectangle())
        .offset(dragOffset)
        .rotationEffect(.degrees(rotationDegrees))
        .animation(animatesMotion ? .interactiveSpring(response: 0.26, dampingFraction: 0.86) : nil, value: dragOffset)
        .animation(animatesMotion ? .interactiveSpring(response: 0.26, dampingFraction: 0.86) : nil, value: rotationDegrees)
    }

    private var decisionIndicator: some View {
        HStack(spacing: 10) {
            Image(systemName: decisionIndicatorImage)
                .font(.system(size: 20, weight: .semibold))
            Text(swipeHint)
                .font(.system(size: 18, weight: .semibold))
        }
        .foregroundStyle(decisionIndicatorColor)
        .padding(.horizontal, 22)
        .frame(height: 56)
        .background(indicatorBackground)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private var decisionIndicatorImage: String {
        switch swipeHint {
        case "删除":
            return "trash.fill"
        case "下一张":
            return "checkmark"
        case "这是第一张":
            return "1.circle.fill"
        case "本组没有删除\n开启下一组":
            return "arrow.forward.circle.fill"
        default:
            return "arrow.uturn.left"
        }
    }

    private var decisionIndicatorColor: Color {
        switch swipeHint {
        case "删除":
            return .red
        case "下一张":
            return .green
        case "这是第一张", "本组没有删除\n开启下一组":
            return .white
        default:
            return .blue
        }
    }

    @ViewBuilder
    private var indicatorBackground: some View {
        let shape = Capsule()

        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.regular.tint(.white.opacity(0.08)).interactive(), in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.22), lineWidth: 0.8)
                }
        } else {
            shape
                .fill(.black.opacity(0.18))
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(.white.opacity(0.18), lineWidth: 0.8)
                }
        }
    }
}
