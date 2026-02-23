import SwiftUI

/// Full note display with optional similarity score badge
struct NoteDetailView: View {
    let note: Note
    @ObservedObject private var manager = ZvecManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Score badge (only shown when note came from search)
                if note.score > 0 {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Similarity Score: \(String(format: "%.4f", note.score))")
                            .font(.subheadline.monospacedDigit())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }

                // Body text
                Text(note.body.isEmpty ? "No content" : note.body)
                    .font(.body)
                    .foregroundColor(note.body.isEmpty ? .secondary : .primary)

                Divider()

                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Label("ID: \(note.id)", systemImage: "key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(note.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    manager.deleteNote(pk: note.id)
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}

