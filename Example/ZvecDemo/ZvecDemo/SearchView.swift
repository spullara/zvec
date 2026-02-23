import SwiftUI

/// Search view with a text field and results list showing similarity scores
struct SearchView: View {
    @ObservedObject private var manager = ZvecManager.shared
    @State private var query = ""
    @State private var results: [Note] = []
    @State private var hasSearched = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search notes by similarity…", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }
                    if !query.isEmpty {
                        Button(action: {
                            query = ""
                            results = []
                            hasSearched = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)

                // Results
                if hasSearched && results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No results found")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !results.isEmpty {
                    List(results) { note in
                        NavigationLink(destination: NoteDetailView(note: note)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.headline)
                                    Text(note.preview)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                // Similarity score badge
                                Text(String(format: "%.2f", note.score))
                                    .font(.caption.monospacedDigit())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(scoreColor(note.score).opacity(0.15))
                                    .foregroundColor(scoreColor(note.score))
                                    .cornerRadius(6)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Enter a query to search")
                            .foregroundColor(.secondary)
                        Text("Results are ranked by vector similarity")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Search")
        }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        results = manager.searchNotes(query: query)
        hasSearched = true
    }

    private func scoreColor(_ score: Float) -> Color {
        if score > 0.8 { return .green }
        if score > 0.5 { return .orange }
        return .red
    }
}

