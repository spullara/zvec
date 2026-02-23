import SwiftUI

/// Main tab view with Notes, Search, and Info tabs
struct ContentView: View {
    var body: some View {
        TabView {
            NotesListView()
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            InfoView()
                .tabItem {
                    Label("Info", systemImage: "info.circle")
                }
        }
    }
}

/// Shows collection stats and path info
struct InfoView: View {
    @ObservedObject private var manager = ZvecManager.shared

    var body: some View {
        NavigationView {
            List {
                Section("Collection Stats") {
                    HStack {
                        Label("Documents", systemImage: "doc.fill")
                        Spacer()
                        Text("\(manager.docCount)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Notes Tracked", systemImage: "list.number")
                        Spacer()
                        Text("\(manager.notes.count)")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Storage") {
                    let docs = FileManager.default.urls(
                        for: .documentDirectory, in: .userDomainMask).first!
                    let path = docs.appendingPathComponent("zvec_notes").path
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Collection Path")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(path)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }

                Section("About") {
                    Text("Zvec Notes is a demo app showing how to use the Zvec vector database Swift package for semantic note search.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Info")
        }
    }
}

