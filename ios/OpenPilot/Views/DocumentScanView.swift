import SwiftUI

/// Escanear documento → OCR → insertar el texto en el composer.
struct DocumentScanView: View {
    @Environment(\.dismiss) private var dismiss
    var onInsert: (String) -> Void
    @State private var scanning = true
    @State private var processing = false
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Group {
                if scanning {
                    DocumentScanner(onScan: { images in
                        scanning = false; processing = true
                        Task { text = await DocumentOCR.recognize(images); processing = false }
                    }, onCancel: { dismiss() })
                    .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        if processing {
                            Spacer(); ProgressView(T("Extracting text…", "Extrayendo texto…")); Spacer()
                        } else if text.isEmpty {
                            ContentUnavailableView(T("No text found", "Sin texto"),
                                                   systemImage: "doc.text",
                                                   description: Text(T("Try scanning again.", "Prueba a escanear de nuevo.")))
                        } else {
                            ScrollView {
                                Text(text).font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                            }
                        }
                        HStack(spacing: 12) {
                            Button { scanning = true; text = "" } label: {
                                Label(T("Rescan", "Reescanear"), systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            if !text.isEmpty {
                                Button { onInsert(text); dismiss() } label: {
                                    Label(T("Use", "Usar"), systemImage: "checkmark").frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(T("Scan document", "Escanear documento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(T("Close", "Cerrar")) { dismiss() } }
            }
        }
    }
}