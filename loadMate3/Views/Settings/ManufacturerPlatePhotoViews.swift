import SwiftUI
import UIKit

struct ManufacturerPlateThumbnail: View {
    let image: UIImage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(LyneqoTheme.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Manufacturer plate photo")
        .accessibilityHint("Opens the attached plate photo")
    }
}

struct ManufacturerPlatePhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ScrollView {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .appScreenBackground()
            .navigationTitle("Manufacturer plate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
