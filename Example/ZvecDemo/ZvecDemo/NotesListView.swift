import SwiftUI

/// Displays all stored notes with swipe-to-delete and an add button
struct NotesListView: View {
    @ObservedObject private var manager = ZvecManager.shared
    @State private var showingAddSheet = false

    var body: some View {
        NavigationView {
            Group {
                if manager.notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Notes Yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("Tap + to add your first note")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(manager.notes) { note in
                            NavigationLink(destination: NoteDetailView(note: note)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.headline)
                                    Text(note.preview)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: deleteNotes)
                    }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddNoteView()
            }
            .alert("Error", isPresented: .constant(manager.errorMessage != nil)) {
                Button("OK") { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
        }
    }

    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = manager.notes[index]
            manager.deleteNote(pk: note.id)
        }
    }
}

