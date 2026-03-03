import XCTest
@testable import Zvec

final class ZvecTests: XCTestCase {

    static var tempDir: String = ""

    override class func setUp() {
        super.setUp()
        // Initialize zvec once for all tests
        do {
            try Zvec.initialize()
        } catch {
            // May already be initialized, that's OK
        }
        tempDir = NSTemporaryDirectory() + "zvec_test_\(ProcessInfo.processInfo.processIdentifier)"
    }

    override class func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDir)
        super.tearDown()
    }

    override func setUp() {
        super.setUp()
        // Clean up before each test
        try? FileManager.default.removeItem(atPath: Self.tempDir)
        try? FileManager.default.createDirectory(atPath: Self.tempDir,
                                                   withIntermediateDirectories: true)
    }

    func testSchemaCreation() throws {
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)
        // If we get here without throwing, schema creation works
    }

    func testCreateAndOpenCollection() throws {
        let path = Self.tempDir + "/test_collection"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)
        let count = try collection.docCount()
        XCTAssertEqual(count, 0)
    }

    func testInsertAndFetch() throws {
        let path = Self.tempDir + "/test_insert"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Insert a document
        let doc = Doc(pk: "doc1")
        try doc.set("title", string: "Hello World")
        try doc.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])
        try collection.insert([doc])

        // Flush to ensure data is persisted
        try collection.flush()

        // Check count
        let count = try collection.docCount()
        XCTAssertEqual(count, 1)

        // Fetch by primary key
        let fetched = try collection.fetch(pks: ["doc1"])
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].pk, "doc1")

        let title = try fetched[0].getString("title")
        XCTAssertEqual(title, "Hello World")
    }

    func testInsertAndQuery() throws {
        let path = Self.tempDir + "/test_query"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Insert multiple documents
        let doc1 = Doc(pk: "doc1")
        try doc1.set("title", string: "First")
        try doc1.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])

        let doc2 = Doc(pk: "doc2")
        try doc2.set("title", string: "Second")
        try doc2.set("embedding", vector: [0.0, 1.0, 0.0, 0.0])

        let doc3 = Doc(pk: "doc3")
        try doc3.set("title", string: "Third")
        try doc3.set("embedding", vector: [0.5, 0.1, 0.0, 0.0])

        try collection.insert([doc1, doc2, doc3])
        try collection.flush()

        // Query for vectors similar to [1, 0, 0, 0]
        let results = try collection.query(
            fieldName: "embedding",
            vector: [1.0, 0.0, 0.0, 0.0],
            topk: 2
        )

        XCTAssertEqual(results.count, 2)
        // doc1 should be the closest match
        XCTAssertEqual(results[0].pk, "doc1")
    }

    func testDeleteDocument() throws {
        let path = Self.tempDir + "/test_delete"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)

        let doc = Doc(pk: "doc1")
        try doc.set("title", string: "To Delete")
        try doc.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])
        try collection.insert([doc])
        try collection.flush()

        XCTAssertEqual(try collection.docCount(), 1)

        try collection.delete(pks: ["doc1"])
        try collection.flush()

        XCTAssertEqual(try collection.docCount(), 0)
    }

    func testReopenCollection() throws {
        let path = Self.tempDir + "/test_reopen"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        // Create and insert
        do {
            let collection = try Collection.createAndOpen(path: path, schema: schema)
            let doc = Doc(pk: "persistent")
            try doc.set("title", string: "Persisted")
            try doc.set("embedding", vector: [0.5, 0.5, 0.0, 0.0])
            try collection.insert([doc])
            try collection.flush()
        }

        // Reopen and verify
        let collection = try Collection.open(path: path)
        let count = try collection.docCount()
        XCTAssertEqual(count, 1)

        let fetched = try collection.fetch(pks: ["persistent"])
        XCTAssertEqual(fetched.count, 1)
        let title = try fetched[0].getString("title")
        XCTAssertEqual(title, "Persisted")
    }

    // MARK: - Fetch non-existent PK tests

    func testFetchNonExistentPK() throws {
        let path = Self.tempDir + "/test_fetch_nonexistent"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Insert one document
        let doc = Doc(pk: "exists")
        try doc.set("title", string: "I exist")
        try doc.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])
        try collection.insert([doc])
        try collection.flush()

        // Fetch a PK that was never inserted — should return empty, NOT crash
        let fetched = try collection.fetch(pks: ["nonexistent"])
        XCTAssertEqual(fetched.count, 0, "Fetching a non-existent PK should return empty array")
    }

    func testFetchMixedExistentAndNonExistent() throws {
        let path = Self.tempDir + "/test_fetch_mixed"
        let schema = CollectionSchema(name: "test")
        try schema.addField("title", dataType: .string)
        try schema.addVectorField("embedding", dataType: .vectorFP32, dimension: 4)

        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Insert docs with pks "a", "b", "c"
        for pk in ["a", "b", "c"] {
            let doc = Doc(pk: pk)
            try doc.set("title", string: "Doc \(pk)")
            try doc.set("embedding", vector: [1.0, 0.0, 0.0, 0.0])
            try collection.insert([doc])
        }
        try collection.flush()

        // Fetch a mix of existing and non-existing PKs
        let fetched = try collection.fetch(pks: ["a", "missing", "c"])
        XCTAssertEqual(fetched.count, 2, "Should return only the 2 existing docs (a and c)")

        let fetchedPKs = Set(fetched.map { $0.pk })
        XCTAssertTrue(fetchedPKs.contains("a"), "Should contain doc 'a'")
        XCTAssertTrue(fetchedPKs.contains("c"), "Should contain doc 'c'")
        XCTAssertFalse(fetchedPKs.contains("missing"), "Should NOT contain 'missing'")
    }

    // MARK: - Crash Reproduction Helpers

    func randomVector(dim: Int) -> [Float] {
        (0..<dim).map { _ in Float.random(in: -1...1) }
    }

    func makeRememberWhenSchema() throws -> CollectionSchema {
        let schema = CollectionSchema(name: "crash_repro")
        try schema
            .addVectorField("embedding", dataType: .vectorFP32, dimension: 512, metric: .cosine)
            .addField("date_taken", dataType: .string)
            .addField("is_favorite", dataType: .int64)
            .addField("nsfw", dataType: .float64)
        return schema
    }

    func makeDoc(index i: Int, randomVec: [Float]) throws -> Doc {
        let doc = Doc(pk: "doc-\(i)")
        try doc.set("embedding", vector: randomVec)
        try doc.set("date_taken", string: "2024-01-\(String(format: "%02d", (i % 28) + 1))")
        try doc.set("is_favorite", int64: Int64(i % 2))
        try doc.set("nsfw", double: Double.random(in: 0...1))
        return doc
    }

    // MARK: - Test 1: Fetch without flush

    func testFetchWithoutFlush() throws {
        let path = Self.tempDir + "/crash_fetch_no_flush"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<100 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])
        }

        // Fetch one doc WITHOUT flushing first
        let fetched = try collection.fetch(pks: ["doc-50"])
        XCTAssertEqual(fetched.count, 1, "Should fetch 1 doc")
        XCTAssertEqual(fetched[0].pk, "doc-50")

        let _ = try fetched[0].getString("date_taken")
        let _ = try fetched[0].getInt64("is_favorite")
        let _ = try fetched[0].getDouble("nsfw")
        let _ = try fetched[0].getVectorFloat("embedding")
    }

    // MARK: - Test 2: Query without flush

    func testQueryWithoutFlush() throws {
        let path = Self.tempDir + "/crash_query_no_flush"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<100 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])
        }

        let results = try collection.query(
            fieldName: "embedding",
            vector: randomVector(dim: 512),
            topk: 10
        )
        XCTAssertGreaterThan(results.count, 0, "Should get some results")

        for doc in results {
            let _ = try doc.getString("date_taken")
            let _ = try doc.getInt64("is_favorite")
            let _ = try doc.getDouble("nsfw")
        }
    }

    // MARK: - Test 3: Interleaved upsert and fetch

    func testInterleavedUpsertAndFetch() throws {
        let path = Self.tempDir + "/crash_interleave_fetch"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<1000 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])

            if i > 0 {
                let fetchIdx = Int.random(in: 0..<i)
                let fetched = try collection.fetch(pks: ["doc-\(fetchIdx)"])
                XCTAssertEqual(fetched.count, 1, "Fetch doc-\(fetchIdx) at iteration \(i)")
                let _ = try fetched[0].getString("date_taken")
                let _ = try fetched[0].getInt64("is_favorite")
                let _ = try fetched[0].getDouble("nsfw")
                let _ = try fetched[0].getVectorFloat("embedding")
            }
        }
    }

    // MARK: - Test 4: Interleaved upsert and query

    func testInterleavedUpsertAndQuery() throws {
        let path = Self.tempDir + "/crash_interleave_query"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<1000 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])

            if i > 0 {
                let results = try collection.query(
                    fieldName: "embedding",
                    vector: randomVector(dim: 512),
                    topk: 5
                )
                for doc in results {
                    let _ = try doc.getString("date_taken")
                    let _ = try doc.getInt64("is_favorite")
                    let _ = try doc.getDouble("nsfw")
                }
            }
        }
    }


    // MARK: - Test 5: Flush then fetch (baseline)

    func testFlushThenFetch() throws {
        let path = Self.tempDir + "/crash_flush_fetch"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<100 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])
        }
        try collection.flush()

        let fetched = try collection.fetch(pks: ["doc-42"])
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].pk, "doc-42")

        let _ = try fetched[0].getString("date_taken")
        let _ = try fetched[0].getInt64("is_favorite")
        let _ = try fetched[0].getDouble("nsfw")
        let _ = try fetched[0].getVectorFloat("embedding")
    }

    // MARK: - Test 6: High volume upsert then query

    func testHighVolumeUpsertThenQuery() throws {
        let path = Self.tempDir + "/crash_high_volume"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<5000 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])
        }
        try collection.flush()

        let results = try collection.query(
            fieldName: "embedding",
            vector: randomVector(dim: 512),
            topk: 10
        )
        XCTAssertEqual(results.count, 10, "Should return 10 results from 5000 docs")

        for doc in results {
            let _ = try doc.getString("date_taken")
            let _ = try doc.getInt64("is_favorite")
            let _ = try doc.getDouble("nsfw")
        }
    }

    // MARK: - Test 7: Interleaved with periodic flush (RememberWhen pattern)

    func testInterleavedWithPeriodicFlush() throws {
        let path = Self.tempDir + "/crash_periodic_flush"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<1000 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])

            // Every 50 upserts, flush
            if (i + 1) % 50 == 0 {
                try collection.flush()
            }

            // Every 10 upserts, fetch a random previously-inserted PK
            if i > 0 && (i + 1) % 10 == 0 {
                let fetchIdx = Int.random(in: 0...i)
                let fetched = try collection.fetch(pks: ["doc-\(fetchIdx)"])
                XCTAssertEqual(fetched.count, 1, "Fetch doc-\(fetchIdx) at iteration \(i)")
                let _ = try fetched[0].getString("date_taken")
                let _ = try fetched[0].getInt64("is_favorite")
                let _ = try fetched[0].getDouble("nsfw")
                let _ = try fetched[0].getVectorFloat("embedding")
            }
        }
    }

    // MARK: - Test 8: High dimension fetch (2048-dim — face embeddings)

    func testHighDimensionFetch() throws {
        let path = Self.tempDir + "/crash_high_dim_fetch"
        let schema = CollectionSchema(name: "face_embedding")
        try schema
            .addVectorField("face_embedding", dataType: .vectorFP32, dimension: 2048, metric: .cosine)
            .addField("identifier", dataType: .string)
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Upsert 100 docs with random 2048-dim vectors
        for i in 0..<100 {
            let doc = Doc(pk: "face-\(i)")
            try doc.set("face_embedding", vector: randomVector(dim: 2048))
            try doc.set("identifier", string: "person-\(i)")
            try collection.upsert([doc])
        }
        try collection.flush()

        // Fetch each doc by PK and read the identifier field
        for i in 0..<100 {
            let fetched = try collection.fetch(pks: ["face-\(i)"])
            XCTAssertEqual(fetched.count, 1, "Should fetch face-\(i)")
            let identifier = try fetched[0].getString("identifier")
            XCTAssertEqual(identifier, "person-\(i)")
        }

        // Upsert 100 more WITHOUT flushing, then fetch
        for i in 100..<200 {
            let doc = Doc(pk: "face-\(i)")
            try doc.set("face_embedding", vector: randomVector(dim: 2048))
            try doc.set("identifier", string: "person-\(i)")
            try collection.upsert([doc])
        }

        // Fetch without flush
        for i in 100..<200 {
            let fetched = try collection.fetch(pks: ["face-\(i)"])
            XCTAssertEqual(fetched.count, 1, "Should fetch unflushed face-\(i)")
            let identifier = try fetched[0].getString("identifier")
            XCTAssertEqual(identifier, "person-\(i)")
        }
    }

    // MARK: - Test 9: High dimension interleaved upsert and fetch (2048-dim)

    func testHighDimensionInterleavedUpsertAndFetch() throws {
        let path = Self.tempDir + "/crash_high_dim_interleave"
        let schema = CollectionSchema(name: "face_embedding")
        try schema
            .addVectorField("face_embedding", dataType: .vectorFP32, dimension: 2048, metric: .cosine)
            .addField("identifier", dataType: .string)
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Loop 500 iterations: upsert 1 doc, immediately fetch a random previously-inserted PK
        for i in 0..<500 {
            let doc = Doc(pk: "face-\(i)")
            try doc.set("face_embedding", vector: randomVector(dim: 2048))
            try doc.set("identifier", string: "person-\(i)")
            try collection.upsert([doc])

            if i > 0 {
                let fetchIdx = Int.random(in: 0..<i)
                let fetched = try collection.fetch(pks: ["face-\(fetchIdx)"])
                XCTAssertEqual(fetched.count, 1, "Fetch face-\(fetchIdx) at iteration \(i)")
                let identifier = try fetched[0].getString("identifier")
                XCTAssertEqual(identifier, "person-\(fetchIdx)")
                let _ = try fetched[0].getVectorFloat("face_embedding")
            }
        }
    }

    // MARK: - Test 10: Two collections simultaneously

    func testTwoCollectionsSimultaneously() throws {
        let imagesPath = Self.tempDir + "/crash_dual_images"
        let facesPath = Self.tempDir + "/crash_dual_faces"

        // Images collection: 512-dim
        let imagesSchema = CollectionSchema(name: "images")
        try imagesSchema
            .addVectorField("embedding", dataType: .vectorFP32, dimension: 512, metric: .cosine)
            .addField("date_taken", dataType: .string)
            .addField("is_favorite", dataType: .int64)
            .addField("nsfw", dataType: .float64)
        let images = try Collection.createAndOpen(path: imagesPath, schema: imagesSchema)

        // Faces collection: 2048-dim
        let facesSchema = CollectionSchema(name: "faces")
        try facesSchema
            .addVectorField("face_embedding", dataType: .vectorFP32, dimension: 2048, metric: .cosine)
            .addField("identifier", dataType: .string)
        let faces = try Collection.createAndOpen(path: facesPath, schema: facesSchema)

        // Interleave operations on both collections
        for i in 0..<500 {
            // Upsert to images
            let imgDoc = Doc(pk: "img-\(i)")
            try imgDoc.set("embedding", vector: randomVector(dim: 512))
            try imgDoc.set("date_taken", string: "2024-01-\(String(format: "%02d", (i % 28) + 1))")
            try imgDoc.set("is_favorite", int64: Int64(i % 2))
            try imgDoc.set("nsfw", double: Double.random(in: 0...1))
            try images.upsert([imgDoc])

            // Upsert to faces
            let faceDoc = Doc(pk: "face-\(i)")
            try faceDoc.set("face_embedding", vector: randomVector(dim: 2048))
            try faceDoc.set("identifier", string: "person-\(i)")
            try faces.upsert([faceDoc])

            // Periodic flush every 50
            if (i + 1) % 50 == 0 {
                try images.flush()
                try faces.flush()
            }

            // Fetch from both collections
            if i > 0 {
                let imgIdx = Int.random(in: 0..<i)
                let fetchedImg = try images.fetch(pks: ["img-\(imgIdx)"])
                XCTAssertEqual(fetchedImg.count, 1, "Fetch img-\(imgIdx) at iteration \(i)")
                let _ = try fetchedImg[0].getString("date_taken")

                let faceIdx = Int.random(in: 0..<i)
                let fetchedFace = try faces.fetch(pks: ["face-\(faceIdx)"])
                XCTAssertEqual(fetchedFace.count, 1, "Fetch face-\(faceIdx) at iteration \(i)")
                let _ = try fetchedFace[0].getString("identifier")
            }
        }
    }

    // MARK: - Test 11: Reopen and fetch

    func testReopenAndFetch() throws {
        let path = Self.tempDir + "/crash_reopen_fetch"
        let schema = try makeRememberWhenSchema()

        // Create collection, insert 500 docs, flush, destroy
        do {
            let collection = try Collection.createAndOpen(path: path, schema: schema)
            for i in 0..<500 {
                let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
                try collection.upsert([doc])
            }
            try collection.flush()
        }

        // Reopen same collection
        let collection = try Collection.open(path: path)

        // Fetch all 500 docs by PK and verify fields
        for i in 0..<500 {
            let fetched = try collection.fetch(pks: ["doc-\(i)"])
            XCTAssertEqual(fetched.count, 1, "Should fetch doc-\(i) after reopen")
            let _ = try fetched[0].getString("date_taken")
            let _ = try fetched[0].getInt64("is_favorite")
            let _ = try fetched[0].getDouble("nsfw")
            let _ = try fetched[0].getVectorFloat("embedding")
        }

        // Upsert 100 more docs into the reopened collection
        for i in 500..<600 {
            let doc = try makeDoc(index: i, randomVec: randomVector(dim: 512))
            try collection.upsert([doc])
        }

        // Fetch the new docs without flushing first
        for i in 500..<600 {
            let fetched = try collection.fetch(pks: ["doc-\(i)"])
            XCTAssertEqual(fetched.count, 1, "Should fetch unflushed doc-\(i) after reopen")
            let _ = try fetched[0].getString("date_taken")
            let _ = try fetched[0].getInt64("is_favorite")
            let _ = try fetched[0].getDouble("nsfw")
        }
    }

    // MARK: - Test 12: Concurrent upsert and fetch

    func testConcurrentUpsertAndFetch() throws {
        let path = Self.tempDir + "/crash_concurrent"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        let group = DispatchGroup()
        var upsertError: Error?
        var fetchError: Error?

        // Thread 1: upserts 500 docs one at a time
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = try self.makeDoc(index: i, randomVec: self.randomVector(dim: 512))
                    try collection.upsert([doc])
                }
            } catch {
                upsertError = error
            }
        }

        // Thread 2: repeatedly fetches random PKs
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for _ in 0..<500 {
                    let idx = Int.random(in: 0..<500)
                    let fetched = try collection.fetch(pks: ["doc-\(idx)"])
                    // May or may not find the doc depending on timing
                    if let doc = fetched.first {
                        let _ = try doc.getString("date_taken")
                        let _ = try doc.getInt64("is_favorite")
                        let _ = try doc.getDouble("nsfw")
                    }
                }
            } catch {
                fetchError = error
            }
        }

        group.wait()

        if let err = upsertError { XCTFail("Upsert thread error: \(err)") }
        if let err = fetchError { XCTFail("Fetch thread error: \(err)") }
    }

    // MARK: - Test 13: Concurrent two collections

    func testConcurrentTwoCollections() throws {
        let imagesPath = Self.tempDir + "/crash_conc_images"
        let facesPath = Self.tempDir + "/crash_conc_faces"

        // Images collection: 512-dim
        let imagesSchema = CollectionSchema(name: "images")
        try imagesSchema
            .addVectorField("embedding", dataType: .vectorFP32, dimension: 512, metric: .cosine)
            .addField("date_taken", dataType: .string)
            .addField("is_favorite", dataType: .int64)
            .addField("nsfw", dataType: .float64)
        let images = try Collection.createAndOpen(path: imagesPath, schema: imagesSchema)

        // Faces collection: 2048-dim
        let facesSchema = CollectionSchema(name: "faces")
        try facesSchema
            .addVectorField("face_embedding", dataType: .vectorFP32, dimension: 2048, metric: .cosine)
            .addField("identifier", dataType: .string)
        let faces = try Collection.createAndOpen(path: facesPath, schema: facesSchema)

        let group = DispatchGroup()
        var errors: [String: Error] = [:]
        let errorLock = NSLock()

        // Thread 1: upserts to images collection
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = Doc(pk: "img-\(i)")
                    try doc.set("embedding", vector: self.randomVector(dim: 512))
                    try doc.set("date_taken", string: "2024-01-01")
                    try doc.set("is_favorite", int64: 0)
                    try doc.set("nsfw", double: 0.0)
                    try images.upsert([doc])
                }
            } catch {
                errorLock.lock()
                errors["images_upsert"] = error
                errorLock.unlock()
            }
        }

        // Thread 2: upserts to faces collection
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = Doc(pk: "face-\(i)")
                    try doc.set("face_embedding", vector: self.randomVector(dim: 2048))
                    try doc.set("identifier", string: "person-\(i)")
                    try faces.upsert([doc])
                }
            } catch {
                errorLock.lock()
                errors["faces_upsert"] = error
                errorLock.unlock()
            }
        }

        // Thread 3: fetches from images
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for _ in 0..<500 {
                    let idx = Int.random(in: 0..<500)
                    let fetched = try images.fetch(pks: ["img-\(idx)"])
                    if let doc = fetched.first {
                        let _ = try doc.getString("date_taken")
                    }
                }
            } catch {
                errorLock.lock()
                errors["images_fetch"] = error
                errorLock.unlock()
            }
        }

        // Thread 4: fetches from faces
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for _ in 0..<500 {
                    let idx = Int.random(in: 0..<500)
                    let fetched = try faces.fetch(pks: ["face-\(idx)"])
                    if let doc = fetched.first {
                        let _ = try doc.getString("identifier")
                    }
                }
            } catch {
                errorLock.lock()
                errors["faces_fetch"] = error
                errorLock.unlock()
            }
        }

        group.wait()

        for (thread, err) in errors {
            XCTFail("\(thread) thread error: \(err)")
        }
    }

    // MARK: - Test 12b: Concurrent upsert and fetch (serialized)

    func testConcurrentUpsertAndFetchSerialized() throws {
        let path = Self.tempDir + "/crash_concurrent_serialized"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Quick sanity: single upsert on main thread
        let testDoc = try makeDoc(index: 9999, randomVec: randomVector(dim: 512))
        try collection.upsert([testDoc])

        let group = DispatchGroup()
        var upsertError: Error?
        var fetchError: Error?
        let queue = DispatchQueue(label: "com.zvec.test.serialized")

        // Thread 1: upserts 500 docs one at a time, serialized through queue
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = try self.makeDoc(index: i, randomVec: self.randomVector(dim: 512))
                    queue.sync {
                        do {
                            try collection.upsert([doc])
                        } catch {
                            upsertError = error
                        }
                    }
                    if upsertError != nil { return }
                }
            } catch {
                upsertError = error
            }
        }

        // Thread 2: repeatedly fetches random PKs, serialized through same queue
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            defer { group.leave() }
            for _ in 0..<500 {
                let idx = Int.random(in: 0..<500)
                queue.sync {
                    do {
                        let fetched = try collection.fetch(pks: ["doc-\(idx)"])
                        // May or may not find the doc depending on timing
                        if let doc = fetched.first {
                            let _ = try doc.getString("date_taken")
                            let _ = try doc.getInt64("is_favorite")
                            let _ = try doc.getDouble("nsfw")
                        }
                    } catch {
                        fetchError = error
                    }
                }
                if fetchError != nil { return }
            }
        }

        group.wait()

        if let err = upsertError { XCTFail("Upsert thread error: \(err)") }
        if let err = fetchError { XCTFail("Fetch thread error: \(err)") }
    }

    // MARK: - Test 13b: Concurrent two collections (serialized)

    func testConcurrentTwoCollectionsSerialized() throws {
        let imagesPath = Self.tempDir + "/crash_conc_images_serialized"
        let facesPath = Self.tempDir + "/crash_conc_faces_serialized"

        // Images collection: 512-dim
        let imagesSchema = CollectionSchema(name: "images")
        try imagesSchema
            .addVectorField("embedding", dataType: .vectorFP32, dimension: 512, metric: .cosine)
            .addField("date_taken", dataType: .string)
            .addField("is_favorite", dataType: .int64)
            .addField("nsfw", dataType: .float64)
        let images = try Collection.createAndOpen(path: imagesPath, schema: imagesSchema)

        // Faces collection: 2048-dim
        let facesSchema = CollectionSchema(name: "faces")
        try facesSchema
            .addVectorField("face_embedding", dataType: .vectorFP32, dimension: 2048, metric: .cosine)
            .addField("identifier", dataType: .string)
        let faces = try Collection.createAndOpen(path: facesPath, schema: facesSchema)

        let group = DispatchGroup()
        var errors: [String: Error] = [:]
        let errorLock = NSLock()
        let imagesLock = NSLock()
        let facesLock = NSLock()

        // Thread 1: upserts to images collection
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = Doc(pk: "img-\(i)")
                    try doc.set("embedding", vector: self.randomVector(dim: 512))
                    try doc.set("date_taken", string: "2024-01-01")
                    try doc.set("is_favorite", int64: 0)
                    try doc.set("nsfw", double: 0.0)
                    imagesLock.lock()
                    do {
                        try images.upsert([doc])
                        imagesLock.unlock()
                    } catch {
                        imagesLock.unlock()
                        throw error
                    }
                }
            } catch {
                errorLock.lock()
                errors["images_upsert"] = error
                errorLock.unlock()
            }
        }

        // Thread 2: upserts to faces collection
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for i in 0..<500 {
                    let doc = Doc(pk: "face-\(i)")
                    try doc.set("face_embedding", vector: self.randomVector(dim: 2048))
                    try doc.set("identifier", string: "person-\(i)")
                    facesLock.lock()
                    do {
                        try faces.upsert([doc])
                        facesLock.unlock()
                    } catch {
                        facesLock.unlock()
                        throw error
                    }
                }
            } catch {
                errorLock.lock()
                errors["faces_upsert"] = error
                errorLock.unlock()
            }
        }

        // Thread 3: fetches from images
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for _ in 0..<500 {
                    let idx = Int.random(in: 0..<500)
                    imagesLock.lock()
                    do {
                        let fetched = try images.fetch(pks: ["img-\(idx)"])
                        if let doc = fetched.first {
                            let _ = try doc.getString("date_taken")
                        }
                        imagesLock.unlock()
                    } catch {
                        imagesLock.unlock()
                        throw error
                    }
                }
            } catch {
                errorLock.lock()
                errors["images_fetch"] = error
                errorLock.unlock()
            }
        }

        // Thread 4: fetches from faces
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            defer { group.leave() }
            do {
                for _ in 0..<500 {
                    let idx = Int.random(in: 0..<500)
                    facesLock.lock()
                    do {
                        let fetched = try faces.fetch(pks: ["face-\(idx)"])
                        if let doc = fetched.first {
                            let _ = try doc.getString("identifier")
                        }
                        facesLock.unlock()
                    } catch {
                        facesLock.unlock()
                        throw error
                    }
                }
            } catch {
                errorLock.lock()
                errors["faces_fetch"] = error
                errorLock.unlock()
            }
        }

        group.wait()

        for (thread, err) in errors {
            XCTFail("\(thread) thread error: \(err)")
        }
    }

    // MARK: - Test 14: Upsert same key repeatedly

    func testUpsertSameKeyRepeatedly() throws {
        let path = Self.tempDir + "/crash_same_key"
        let schema = try makeRememberWhenSchema()
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        for i in 0..<1000 {
            let doc = Doc(pk: "same-key")
            try doc.set("embedding", vector: randomVector(dim: 512))
            try doc.set("date_taken", string: "2024-01-\(String(format: "%02d", (i % 28) + 1))")
            try doc.set("is_favorite", int64: Int64(i % 2))
            try doc.set("nsfw", double: Double(i) / 1000.0)
            try collection.upsert([doc])

            // After every 10 upserts, fetch that PK and verify it returns a doc
            if (i + 1) % 10 == 0 {
                let fetched = try collection.fetch(pks: ["same-key"])
                XCTAssertEqual(fetched.count, 1, "Should fetch same-key at iteration \(i)")
                let _ = try fetched[0].getString("date_taken")
                let _ = try fetched[0].getInt64("is_favorite")
                let _ = try fetched[0].getDouble("nsfw")
                let _ = try fetched[0].getVectorFloat("embedding")
            }
        }
    }

    // MARK: - Test 15: Drop and rebuild HNSW index with progress callback

    func testDropAndRebuildHnswIndexWithProgress() throws {
        let path = Self.tempDir + "/test_drop_rebuild_hnsw"
        let schema = CollectionSchema(name: "test_rebuild")
        try schema
            .addVectorField("embedding", dataType: .vectorFP32, dimension: 512, metric: .cosine)
            .addField("title", dataType: .string)
        let collection = try Collection.createAndOpen(path: path, schema: schema)

        // Insert enough docs to make progress meaningful
        let docCount = 500
        for i in 0..<docCount {
            let doc = Doc(pk: "doc-\(i)")
            try doc.set("embedding", vector: randomVector(dim: 512))
            try doc.set("title", string: "Document \(i)")
            try collection.upsert([doc])
        }
        try collection.flush()

        // Build initial HNSW index (no progress)
        try collection.createHnswIndex(fieldName: "embedding", metric: .cosine)

        // Verify search works with the index
        let results1 = try collection.query(fieldName: "embedding", vector: randomVector(dim: 512), topk: 5)
        XCTAssertEqual(results1.count, 5, "Should get 5 results with initial index")

        // Drop the index
        try collection.dropIndex(fieldName: "embedding")

        // Rebuild with progress callback
        var progressCalls: [(UInt32, UInt32)] = []
        let progressLock = NSLock()

        try collection.createHnswIndex(fieldName: "embedding", metric: .cosine) { current, total in
            progressLock.lock()
            progressCalls.append((current, total))
            progressLock.unlock()
        }

        // Verify progress was actually reported
        XCTAssertGreaterThan(progressCalls.count, 0, "Progress callback should have been called at least once")

        // Verify total matches doc count
        if let lastCall = progressCalls.last {
            XCTAssertEqual(lastCall.0, lastCall.1, "Final progress should show current == total")
            XCTAssertEqual(Int(lastCall.1), docCount, "Total should match document count")
        }

        // Verify search still works after rebuild
        let results2 = try collection.query(fieldName: "embedding", vector: randomVector(dim: 512), topk: 5)
        XCTAssertEqual(results2.count, 5, "Should get 5 results after rebuild")

        print("Progress callback was called \(progressCalls.count) times")
        if let first = progressCalls.first, let last = progressCalls.last {
            print("First: \(first.0)/\(first.1), Last: \(last.0)/\(last.1)")
        }
    }
}