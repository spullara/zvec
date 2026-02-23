import Foundation
import Zvec

/// Singleton manager wrapping Zvec collection operations for the demo app.
/// Handles collection lifecycle, CRUD operations, and text-to-vector conversion.
@MainActor
final class ZvecManager: ObservableObject {
    static let shared = ZvecManager()

    @Published var notes: [Note] = []
    @Published var errorMessage: String?
    @Published var docCount: UInt64 = 0

    private var collection: Collection?
    /// We track all primary keys in UserDefaults since Zvec has no "scan all" API
    private let pkKey = "zvec_note_pks"

    private var collectionPath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("zvec_notes").path
    }

    private init() {}

    // MARK: - Setup

    /// Create or open the notes collection
    func setup() {
        do {
            if FileManager.default.fileExists(atPath: collectionPath) {
                collection = try Collection.open(path: collectionPath)
                print("[ZvecManager] Opened existing collection at \(collectionPath)")
            } else {
                let schema = CollectionSchema(name: "notes")
                try schema.addField("title", dataType: .string)
                try schema.addField("body", dataType: .string)
                try schema.addVectorField("embedding", dataType: .vectorFP32,
                                          dimension: 64, metric: .cosine)
                collection = try Collection.createAndOpen(path: collectionPath, schema: schema)
                print("[ZvecManager] Created new collection at \(collectionPath)")
            }
            refreshNotes()
        } catch {
            errorMessage = "Failed to open collection: \(error.localizedDescription)"
            print("[ZvecManager] Error: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// Add a new note with the given title and body
    func addNote(title: String, body: String) {
        guard let collection = collection else { return }
        do {
            let pk = UUID().uuidString
            let doc = Doc(pk: pk)
            try doc.set("title", string: title)
            try doc.set("body", string: body)
            let embedding = Self.textToVector("\(title) \(body)")
            try doc.set("embedding", vector: embedding)
            try collection.insert([doc])
            try collection.flush()

            // Track the PK
            var pks = storedPKs
            pks.append(pk)
            savePKs(pks)

            refreshNotes()
            print("[ZvecManager] Added note '\(title)' with pk=\(pk)")
        } catch {
            errorMessage = "Failed to add note: \(error.localizedDescription)"
        }
    }

    /// Delete a note by primary key
    func deleteNote(pk: String) {
        guard let collection = collection else { return }
        do {
            try collection.delete(pks: [pk])
            try collection.flush()

            var pks = storedPKs
            pks.removeAll { $0 == pk }
            savePKs(pks)

            refreshNotes()
            print("[ZvecManager] Deleted note pk=\(pk)")
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }

    /// Search notes by semantic similarity to the query text
    func searchNotes(query: String, topk: Int = 10) -> [Note] {
        guard let collection = collection else { return [] }
        do {
            let queryVector = Self.textToVector(query)
            let results = try collection.query(
                fieldName: "embedding",
                vector: queryVector,
                topk: topk
            )
            return results.compactMap { doc -> Note? in
                guard let title = try? doc.getString("title"),
                      let body = try? doc.getString("body") else { return nil }
                return Note(id: doc.pk, title: title, body: body, score: doc.score)
            }
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            return []
        }
    }

    /// Refresh the notes list and doc count from the collection
    func refreshNotes() {
        guard let collection = collection else { return }
        do {
            docCount = try collection.docCount()
            let pks = storedPKs
            guard !pks.isEmpty else { notes = []; return }
            let docs = try collection.fetch(pks: pks)
            notes = docs.compactMap { doc -> Note? in
                guard let title = try? doc.getString("title"),
                      let body = try? doc.getString("body") else { return nil }
                return Note(id: doc.pk, title: title, body: body)
            }
        } catch {
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
    }

    // MARK: - PK Storage (UserDefaults)

    private var storedPKs: [String] {
        UserDefaults.standard.stringArray(forKey: pkKey) ?? []
    }

    private func savePKs(_ pks: [String]) {
        UserDefaults.standard.set(pks, forKey: pkKey)
    }

    // MARK: - Text to Vector

    /// Convert text to a 64-dimensional vector using deterministic word hashing.
    /// Words are lowercased and hashed to bucket indices; the result is L2-normalized.
    /// This is a simple demo — not a real embedding model.
    static func textToVector(_ text: String, dimension: Int = 64) -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        let words = text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        for word in words {
            // Simple FNV-1a-style hash for determinism (hashValue varies across runs)
            var h: UInt64 = 14695981039346656037
            for byte in word.utf8 {
                h ^= UInt64(byte)
                h &*= 1099511628211
            }
            let index = Int(h % UInt64(dimension))
            vector[index] += 1.0
        }
        // L2 normalize
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            vector = vector.map { $0 / norm }
        }
        return vector
    }
}

