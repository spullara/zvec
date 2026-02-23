import SwiftUI

/// Sheet view for adding a new note with title and body fields
struct AddNoteView: View {
    @ObservedObject private var manager = ZvecManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""

    var body: some View {
        NavigationView {
            Form {
                Section("Title") {
                    TextField("Note title", text: $title)
                }
                Section("Body") {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 150)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !title.isEmpty else { return }
                        manager.addNote(title: title, body: bodyText)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

