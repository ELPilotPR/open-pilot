import SwiftUI
import SwiftData

/// Galería de todas las imágenes generadas/adjuntas, con visor y compartir.
struct ImageGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var conversations: [Conversation]
    @State private var selected: GalleryItem?
    private let cols = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    private var items: [GalleryItem] { ImageGallerySupport.collect(from: conversations) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(T("No images yet", "Sin imágenes"),
                                           systemImage: "photo.on.rectangle.angled",
                                           description: Text(T("Generated and attached images appear here.",
                                                               "Las imágenes generadas y adjuntas aparecen aquí.")))
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 8) {
                            ForEach(items) { item in
                                Button { selected = item } label: {
                                    if let ui = UIImage(data: item.data) {
                                        Image(uiImage: ui).resizable().scaledToFill()
                                            .frame(width: 110, height: 110).clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.title)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(T("Gallery", "Galería"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } }
            }
            .sheet(item: $selected) { item in ImageViewer(item: item) }
        }
    }
}

private struct ImageViewer: View {
    let item: GalleryItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let ui = UIImage(data: item.data) {
                    Image(uiImage: ui).resizable().scaledToFit().padding()
                    ShareLink(item: Image(uiImage: ui),
                              preview: SharePreview(item.title, image: Image(uiImage: ui)))
                        .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } }
            }
        }
    }
}