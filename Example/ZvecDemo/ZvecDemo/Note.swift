import Foundation

/// A note stored in the Zvec vector database
struct Note: Identifiable {
    let id: String       // primary key (UUID string)
    let title: String
    let body: String
    var score: Float = 0 // similarity score from vector search

    /// Preview of the body text (first 100 characters)
    var preview: String {
        if body.count <= 100 { return body }
        return String(body.prefix(100)) + "…"
    }
}

