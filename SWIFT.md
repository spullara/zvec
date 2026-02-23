# Zvec Swift API Reference

Zvec is an embedded vector database for iOS, Mac Catalyst, and macOS. It persists data to disk via RocksDB, supports vector similarity search (HNSW and flat indices), and stores scalar metadata alongside vectors in a single collection.

## Table of Contents

1. [Getting Started](#1-getting-started)
2. [Initialization](#2-initialization)
3. [Schema Definition](#3-schema-definition)
4. [Collection](#4-collection)
5. [Document](#5-document)
6. [Error Handling](#6-error-handling)
7. [Complete Examples](#7-complete-examples)
8. [Porting Guide: BFES → Zvec (for RememberWhen)](#8-porting-guide-bfes--zvec-for-rememberwhen)

---

## 1. Getting Started

### Swift Package Manager

Add the Zvec package to your project using the repository URL:

```
https://github.com/spullara/zvec
```

**In Xcode:** File → Add Package Dependencies → paste the URL above.

**In `Package.swift`:**

```swift
dependencies: [
    .package(url: "https://github.com/spullara/zvec", branch: "ios-support")
]
```

Then add `"Zvec"` to your target's dependencies:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "Zvec", package: "zvec")
])
```

### Package Details

- **Supported platforms:** iOS 15+, Mac Catalyst 15+, macOS 12+
- **Swift tools version:** 5.9
- **Binary target URL:** `https://github.com/spullara/zvec/releases/download/v0.1.0-ios/zvec.xcframework.zip`
- **Checksum:** `2934d9e5aa5f9c9abab46897685922ca75cb990ddbc21c97965ebebe5e2b9305`

### Linker Flag

The `-all_load` linker flag is **required** for Zvec to work correctly. This is handled automatically by the package manifest's `linkerSettings`. If you manually link the XCFramework without using SPM, you must add `-all_load` to your target's "Other Linker Flags" in Xcode build settings.

---

## 2. Initialization

```swift
import Zvec

// Call once at app launch, before any other Zvec API call
try Zvec.initialize()
```

`Zvec.initialize()` must be called exactly once before using any other Zvec functions. A good place is `application(_:didFinishLaunchingWithOptions:)` or your `@main` App's `init()`.

---

## 3. Schema Definition

A `CollectionSchema` defines the fields and vector columns in a collection.

### Creating a Schema

```swift
let schema = CollectionSchema(name: "my_collection")
```

### Adding Scalar Fields

```swift
@discardableResult
public func addField(_ name: String, dataType: DataType, nullable: Bool = false) throws -> CollectionSchema
```

```swift
try schema.addField("title", dataType: .string)
try schema.addField("count", dataType: .int64)
try schema.addField("lat", dataType: .float64, nullable: true)
try schema.addField("is_active", dataType: .bool)
```

### Adding Vector Fields

```swift
@discardableResult
public func addVectorField(_ name: String, dataType: DataType = .vectorFP32,
                            dimension: UInt32, nullable: Bool = false,
                            metric: MetricType = .ip) throws -> CollectionSchema
```

```swift
try schema.addVectorField("embedding", dimension: 512, metric: .cosine)
try schema.addVectorField("face_embedding", dimension: 2048, metric: .cosine)
```

### Method Chaining

Both `addField` and `addVectorField` return `self`, so you can chain calls:

```swift
let schema = CollectionSchema(name: "photos")
try schema
    .addField("date_taken", dataType: .string)
    .addField("place", dataType: .string, nullable: true)
    .addVectorField("embedding", dimension: 512, metric: .cosine)
```

### DataType

| Case | Raw Value | Description |
|------|-----------|-------------|
| `.string` | 2 | UTF-8 string |
| `.bool` | 3 | Boolean |
| `.int32` | 4 | 32-bit signed integer |
| `.int64` | 5 | 64-bit signed integer |
| `.uint32` | 6 | 32-bit unsigned integer |
| `.uint64` | 7 | 64-bit unsigned integer |
| `.float32` | 8 | 32-bit float |
| `.float64` | 9 | 64-bit float (double) |
| `.vectorFP32` | 23 | Vector of 32-bit floats |
| `.vectorFP16` | 22 | Vector of 16-bit floats |
| `.vectorInt8` | 26 | Vector of 8-bit integers |

### MetricType

| Case | Raw Value | Description |
|------|-----------|-------------|
| `.l2` | 1 | Euclidean (L2) distance |
| `.ip` | 2 | Inner product (default) |
| `.cosine` | 3 | Cosine similarity |

---

## 4. Collection

A `Collection` is the primary interface for storing, querying, and managing documents.

### Creating a New Collection

```swift
public static func createAndOpen(path: String, schema: CollectionSchema) throws -> Collection
```

```swift
let path = documentsDirectory + "/my_collection"
let collection = try Collection.createAndOpen(path: path, schema: schema)
```

The `path` is a directory on the filesystem where the collection data will be stored.

### Opening an Existing Collection

```swift
public static func open(path: String, readOnly: Bool = false) throws -> Collection
```

```swift
let collection = try Collection.open(path: path)
let readOnlyCollection = try Collection.open(path: path, readOnly: true)
```

### Inserting Documents

```swift
public func insert(_ docs: [Doc]) throws
```

```swift
let doc = Doc(pk: "photo_abc123")
try doc.set("title", string: "Sunset")
try doc.set("embedding", vector: clipEmbedding)
try collection.insert([doc])
try collection.flush()  // IMPORTANT: persist to disk
```

### Upserting Documents

Insert or update — if a document with the same PK exists, it is replaced.

```swift
public func upsert(_ docs: [Doc]) throws
```

```swift
try collection.upsert([updatedDoc])
try collection.flush()
```

### Deleting Documents

```swift
public func delete(pks: [String]) throws
```

```swift
try collection.delete(pks: ["photo_abc123", "photo_def456"])
try collection.flush()
```

### Vector Similarity Search

```swift
public func query(fieldName: String, vector: [Float], topk: Int,
                  filter: String? = nil) throws -> [Doc]
```

```swift
let results = try collection.query(
    fieldName: "embedding",
    vector: queryVector,
    topk: 10
)

for doc in results {
    print("\(doc.pk) — score: \(doc.score)")
}
```

Results are ordered by relevance. Each returned `Doc` has its `score` property set. The meaning of `score` depends on the metric:
- `.cosine` — higher is more similar (range -1 to 1)
- `.ip` — higher is more similar
- `.l2` — lower is more similar (distance)

### Fetching Documents by Primary Key

```swift
public func fetch(pks: [String]) throws -> [Doc]
```

```swift
let docs = try collection.fetch(pks: ["photo_abc123"])
if let doc = docs.first {
    let title = try doc.getString("title")
    let embedding = try doc.getVectorFloat("embedding")
}
```

### Flushing to Disk

```swift
public func flush() throws
```

**Important:** You must call `flush()` after inserts, upserts, or deletes to persist changes to disk. Without flushing, data may be lost if the process exits.

```swift
try collection.insert(docs)
try collection.flush()
```

### Document Count

```swift
public func docCount() throws -> UInt64
```

```swift
let count = try collection.docCount()
print("Collection has \(count) documents")
```

### Creating Indexes

Indexes improve query performance. Without an index, queries use brute-force linear scan.

#### HNSW Index (recommended for large collections)

```swift
public func createHnswIndex(fieldName: String, metric: MetricType,
                             m: Int32 = 50, efConstruction: Int32 = 500) throws
```

```swift
try collection.createHnswIndex(fieldName: "embedding", metric: .cosine)
```

- `m` — number of connections per node (higher = better recall, more memory). Default: 50.
- `efConstruction` — construction-time search width (higher = better index quality, slower build). Default: 500.

#### Flat Index (brute-force, exact results)

```swift
public func createFlatIndex(fieldName: String, metric: MetricType) throws
```

```swift
try collection.createFlatIndex(fieldName: "embedding", metric: .cosine)
```

### Collection Lifecycle

A `Collection` is automatically closed and its resources freed when the object is deallocated (via `deinit`). You do not need to call a close method. Hold a strong reference to the `Collection` for as long as you need it.

---

## 5. Document

A `Doc` represents a single record in a collection. Each document has a string primary key (PK) and typed fields.

### Creating a Document

```swift
let doc = Doc(pk: "unique_identifier")
```

### Properties

```swift
public var pk: String { get }     // Primary key
public var score: Float { get }   // Relevance score (populated after query)
```

### Setting Field Values

All setters are `@discardableResult` and return `self` for chaining. All throw `ZvecError`.

```swift
// Setters
try doc.set("name", string: "Beach sunset")
try doc.set("count", int32: Int32(42))
try doc.set("timestamp", int64: Int64(1700000000))
try doc.set("rating", float: Float(4.5))
try doc.set("latitude", double: 37.7749)
try doc.set("is_favorite", bool: true)
try doc.set("embedding", vector: [0.1, 0.2, 0.3, ...])  // [Float]
```

**Chaining example:**

```swift
let doc = try Doc(pk: "photo_001")
    .set("title", string: "Mountain view")
    .set("lat", double: 46.5197)
    .set("lon", double: 6.6323)
    .set("is_favorite", bool: false)
    .set("embedding", vector: clipVector)
```

### Getting Field Values

All getters throw `ZvecError` (e.g., `.notFound` if the field doesn't exist).

```swift
let name: String   = try doc.getString("name")
let ts: Int64      = try doc.getInt64("timestamp")
let rating: Float  = try doc.getFloat("rating")
let lat: Double    = try doc.getDouble("latitude")
let vec: [Float]   = try doc.getVectorFloat("embedding")
```

### Full Setter/Getter Signature Reference

| Setter | Parameter Label | Swift Type |
|--------|----------------|------------|
| `set(_:string:)` | `string` | `String` |
| `set(_:int32:)` | `int32` | `Int32` |
| `set(_:int64:)` | `int64` | `Int64` |
| `set(_:float:)` | `float` | `Float` |
| `set(_:double:)` | `double` | `Double` |
| `set(_:bool:)` | `bool` | `Bool` |
| `set(_:vector:)` | `vector` | `[Float]` |

| Getter | Return Type |
|--------|-------------|
| `getString(_:)` | `String` |
| `getInt64(_:)` | `Int64` |
| `getFloat(_:)` | `Float` |
| `getDouble(_:)` | `Double` |
| `getVectorFloat(_:)` | `[Float]` |

---

## 6. Error Handling

All Zvec API methods throw `ZvecError`, which conforms to `Error` and `LocalizedError`.

```swift
public enum ZvecError: Error, LocalizedError {
    case ok
    case notFound(String)
    case alreadyExists(String)
    case invalidArgument(String)
    case permissionDenied(String)
    case failedPrecondition(String)
    case resourceExhausted(String)
    case unavailable(String)
    case internalError(String)
    case notSupported(String)
    case unknown(String)
}
```

Each case (except `.ok`) carries an associated `String` message describing the error.

### Usage

```swift
do {
    let collection = try Collection.open(path: "/nonexistent/path")
} catch let error as ZvecError {
    switch error {
    case .notFound(let msg):
        print("Collection not found: \(msg)")
    case .alreadyExists(let msg):
        print("Already exists: \(msg)")
    default:
        print("Zvec error: \(error.localizedDescription)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

---

## 7. Complete Examples

### Minimal Example

```swift
import Zvec

// 1. Initialize
try Zvec.initialize()

// 2. Define schema
let schema = CollectionSchema(name: "demo")
try schema.addField("title", dataType: .string)
try schema.addVectorField("embedding", dimension: 4, metric: .cosine)

// 3. Create collection
let path = NSTemporaryDirectory() + "zvec_demo"
let collection = try Collection.createAndOpen(path: path, schema: schema)

// 4. Insert a document
let doc = Doc(pk: "doc1")
try doc.set("title", string: "Hello World")
try doc.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])
try collection.insert([doc])
try collection.flush()

// 5. Query
let results = try collection.query(fieldName: "embedding",
                                    vector: [1.0, 0.0, 0.0, 0.0],
                                    topk: 5)
for result in results {
    let title = try result.getString("title")
    print("\(result.pk): \(title) (score: \(result.score))")
}
```

### Realistic Example with Metadata

```swift
import Zvec

try Zvec.initialize()

// Schema with metadata fields
let schema = CollectionSchema(name: "photos")
try schema
    .addField("date_taken", dataType: .string)
    .addField("lat", dataType: .float64, nullable: true)
    .addField("lon", dataType: .float64, nullable: true)
    .addField("place", dataType: .string, nullable: true)
    .addField("is_favorite", dataType: .bool)
    .addVectorField("embedding", dimension: 512, metric: .cosine)

let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let path = docsDir.appendingPathComponent("photos_collection").path
let collection = try Collection.createAndOpen(path: path, schema: schema)

// Insert photos in batches
var batch: [Doc] = []
for photo in photos {
    let doc = try Doc(pk: photo.localIdentifier)
        .set("date_taken", string: photo.creationDate.iso8601)
        .set("is_favorite", bool: photo.isFavorite)
        .set("embedding", vector: photo.clipEmbedding)

    if let lat = photo.location?.latitude {
        try doc.set("lat", double: lat)
        try doc.set("lon", double: photo.location!.longitude)
    }
    if let place = photo.placeName {
        try doc.set("place", string: place)
    }
    batch.append(doc)

    if batch.count >= 100 {
        try collection.upsert(batch)
        batch.removeAll()
    }
}
if !batch.isEmpty {
    try collection.upsert(batch)
}
try collection.flush()

// Build HNSW index for fast search
try collection.createHnswIndex(fieldName: "embedding", metric: .cosine)

// Search
let queryVec: [Float] = getClipEmbedding(for: "sunset on the beach")
let results = try collection.query(fieldName: "embedding", vector: queryVec, topk: 20)

for doc in results {
    print("Photo: \(doc.pk), score: \(doc.score)")
    let dateTaken = try doc.getString("date_taken")
    print("  Date: \(dateTaken)")
}

// Fetch specific photos
let fetched = try collection.fetch(pks: ["ABC123", "DEF456"])

// Delete
try collection.delete(pks: ["OLD_PHOTO_ID"])
try collection.flush()

// Reopen later
let reopened = try Collection.open(path: path)
let count = try reopened.docCount()
print("Collection has \(count) photos")
```

---

## 8. Porting Guide: BFES → Zvec (for RememberWhen)

This section is a detailed guide for replacing BFES (brute-force embedding search) with Zvec in the RememberWhen iOS app.

### Architecture Overview

| Aspect | BFES (current) | Zvec (replacement) |
|--------|----------------|---------------------|
| Storage | In-memory only; relies on SQLite (`DBHelper`) to persist embeddings | Persists to disk via RocksDB; no separate persistence layer needed |
| Result format | `[(Int, Float)]` (integer index, score) | `[Doc]` with `.pk` (string) and `.score` |
| Identifier mapping | `localIdentifiers: [String]` array, index → identifier lookup | PK *is* the identifier; no mapping needed |
| Metadata storage | Separate `metadata_index` SQLite table | Stored as scalar fields in the same Zvec collection |
| Thread safety | Manual `NSLock` in `EmbeddingIndex` | Handled internally by Zvec |
| Initialization | Loads all embeddings from SQLite into memory at startup | Opens persistent collection from disk (fast, no bulk load) |

### Collections to Create

You need **two** Zvec collections, replacing the two BFES indices and three SQLite tables:

#### 1. Images Collection

Replaces: `photoIndex` (BFES) + `photo_index` table + `metadata_index` table

```swift
let imageSchema = CollectionSchema(name: "images")
try imageSchema
    .addField("date_taken", dataType: .string)         // ISO8601
    .addField("lat", dataType: .float64, nullable: true)
    .addField("lon", dataType: .float64, nullable: true)
    .addField("geohash", dataType: .string, nullable: true)
    .addField("place", dataType: .string, nullable: true)
    .addField("is_favorite", dataType: .bool)
    .addField("nsfw", dataType: .float64)
    .addVectorField("embedding", dimension: 512, metric: .cosine)

// PK = photo's localIdentifier (e.g., "ABC123-DEF456")
let imagesPath = documentsDirectory + "/zvec_images"
let images = try Collection.createAndOpen(path: imagesPath, schema: imageSchema)
```

#### 2. Faces Collection

Replaces: `faceIndex` (BFES) + `face_index` table

```swift
let faceSchema = CollectionSchema(name: "faces")
try faceSchema
    .addField("local_identifier", dataType: .string)   // parent photo's localIdentifier
    .addField("x", dataType: .float32)                  // bounding box
    .addField("y", dataType: .float32)
    .addField("width", dataType: .float32)
    .addField("height", dataType: .float32)
    .addVectorField("embedding", dimension: 2048, metric: .cosine)

// PK = "\(localIdentifier) \(faceIndex)" — matching current BFES convention
let facesPath = documentsDirectory + "/zvec_faces"
let faces = try Collection.createAndOpen(path: facesPath, schema: faceSchema)
```

### Code Pattern Changes

#### Search Results

```swift
// OLD (BFES):
let results: [(Int, Float)] = bfes_search(name, k, vector, dim)
let identifier = localIdentifiers[results[i].0]
let score = results[i].1

// NEW (Zvec):
let results: [Doc] = try collection.query(
    fieldName: "embedding", vector: vector, topk: k
)
let identifier = results[i].pk    // PK IS the identifier
let score = results[i].score
```

#### Adding Embeddings

```swift
// OLD (BFES + SQLite):
bfes_add(name, vector, dim)
localIdentifiers.append(localIdentifier)
dbHelper.insertPhotoIndex(localIdentifier: id, embedding: data)

// NEW (Zvec):
let doc = try Doc(pk: localIdentifier)
    .set("embedding", vector: clipEmbedding)
    .set("date_taken", string: dateTaken)
    .set("is_favorite", bool: isFavorite)
try collection.upsert([doc])
try collection.flush()
```

#### Adding Face Embeddings

```swift
// OLD (BFES + SQLite):
bfes_add(name, faceVector, dim)
localIdentifiers.append("\(localIdentifier) \(faceNum)")
dbHelper.insertFaceIndex(localIdentifier: id, boundingBox: box, embedding: data, faceNum: num)

// NEW (Zvec):
let doc = try Doc(pk: "\(localIdentifier) \(faceNum)")
    .set("local_identifier", string: localIdentifier)
    .set("x", float: Float(box.origin.x))
    .set("y", float: Float(box.origin.y))
    .set("width", float: Float(box.size.width))
    .set("height", float: Float(box.size.height))
    .set("embedding", vector: faceEmbedding)
try facesCollection.upsert([doc])
try facesCollection.flush()
```

#### SearchViewModel Changes

```swift
// OLD:
let results = indexer.search(text: query)  // returns [(Int, Float)]
for (index, score) in results {
    let id = indexer.getLocalIdentifier(index: index)
    // use id...
}

// NEW:
let results = try imagesCollection.query(
    fieldName: "embedding", vector: clipVector, topk: k
)
for doc in results {
    let id = doc.pk       // localIdentifier directly
    let score = doc.score
    // use id...
}
```

### What Changes in Each File

#### `EmbeddingIndex.swift` — **Remove or heavily simplify**
- The `localIdentifiers: [String]` array is no longer needed.
- The `NSLock` is no longer needed (Zvec is internally thread-safe).
- Replace the BFES C calls with `Collection.query()` / `Collection.upsert()`.
- The `add(vector:localIdentifier:)` → becomes `collection.upsert([doc])`.
- The `search(vector:k:)` → becomes `collection.query(fieldName:vector:topk:)`.

#### `PhotoIndex.swift` — **Simplify significantly**
- Remove `photoIndex` and `faceIndex` BFES instances.
- Hold two `Collection` instances instead: `imagesCollection` and `facesCollection`.
- Remove the startup loop that loads all embeddings from SQLite into BFES. Instead, just `Collection.open(path:)` — data is already on disk.
- Remove SQLite inserts for embeddings/metadata — `collection.upsert()` handles everything.

#### `DBHelper.swift` — **Keep partially**
- **Remove:** `photo_index`, `face_index`, and `metadata_index` tables and all methods that read/write them.
- **Keep:** `places.sqlite` lookups (`getPlace`), the `version` migration system, and any utility methods like `getCount()`/`getBounds()` if still needed for sync logic.

#### `SearchViewModel.swift` — **Update result handling**
- Change search result type from `[(Int, Float)]` to `[Doc]`.
- Use `doc.pk` instead of `indexer.getLocalIdentifier(index:)`.
- Use `doc.score` instead of tuple element.

#### `CLIP.swift`, `Faces.swift` — **No changes**
- These generate embeddings and are not affected by the storage layer change.

### Migration from BFES + SQLite

On first launch after updating to Zvec:

```swift
func migrateToZvec() throws {
    // 1. Check if Zvec collections already exist
    if FileManager.default.fileExists(atPath: imagesPath) {
        return  // Already migrated
    }

    // 2. Create collections with schemas (as shown above)
    let images = try Collection.createAndOpen(path: imagesPath, schema: imageSchema)
    let faces = try Collection.createAndOpen(path: facesPath, schema: faceSchema)

    // 3. Read existing photo embeddings from SQLite
    let photoRows = dbHelper.getAllPhotoEmbeddings()  // [(localIdentifier, embedding, metadata)]
    var batch: [Doc] = []
    for row in photoRows {
        let doc = try Doc(pk: row.localIdentifier)
            .set("embedding", vector: row.embedding)
            .set("date_taken", string: row.dateTaken ?? "")
            .set("is_favorite", bool: row.isFavorite)
        // ... add other metadata fields
        batch.append(doc)
        if batch.count >= 500 {
            try images.upsert(batch)
            batch.removeAll()
        }
    }
    if !batch.isEmpty { try images.upsert(batch) }
    try images.flush()

    // 4. Read existing face embeddings from SQLite
    let faceRows = dbHelper.getAllFaceEmbeddings()
    batch.removeAll()
    for row in faceRows {
        let doc = try Doc(pk: "\(row.localIdentifier) \(row.faceNum)")
            .set("local_identifier", string: row.localIdentifier)
            .set("x", float: row.x)
            .set("y", float: row.y)
            .set("width", float: row.width)
            .set("height", float: row.height)
            .set("embedding", vector: row.embedding)
        batch.append(doc)
        if batch.count >= 500 {
            try faces.upsert(batch)
            batch.removeAll()
        }
    }
    if !batch.isEmpty { try faces.upsert(batch) }
    try faces.flush()

    // 5. Build indexes
    try images.createHnswIndex(fieldName: "embedding", metric: .cosine)
    try faces.createHnswIndex(fieldName: "embedding", metric: .cosine)

    // 6. Drop old SQLite tables (photo_index, face_index, metadata_index)
    dbHelper.dropLegacyTables()
}
```

### Important Notes

- **Flush after writes:** Always call `try collection.flush()` after batch inserts/upserts/deletes. Without this, data is not persisted to disk.
- **Cosine metric:** Use `.cosine` for CLIP embeddings. RememberWhen currently computes cosine similarity manually in BFES — Zvec handles this natively.
- **Collection path:** Store collections in the app's Documents directory so they persist across launches.
- **Startup performance:** Unlike BFES which loads all embeddings into memory on startup, Zvec opens a persistent on-disk collection instantly. This eliminates the startup delay that grows with library size.
- **No "list all documents" API:** There is no method to enumerate all documents. Use `fetch(pks:)` if you know the PKs, or maintain a separate list of PKs if enumeration is needed.
- **Collection lifecycle:** Hold a strong reference to `Collection` objects (e.g., as a property on your manager class). The collection is closed when the object is deallocated.

