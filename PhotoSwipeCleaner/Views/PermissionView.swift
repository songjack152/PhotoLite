import SwiftUI
import UIKit

struct PermissionView: View {
    @EnvironmentObject private var store: ReviewSessionStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("需要相册权限")
                .font(.title2.bold())

            Text("授权后才能随机读取并分组浏览你的照片。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("授权相册") {
                Task { await store.bootstrap() }
            }
            .buttonStyle(.borderedProminent)

            Button("打开设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
