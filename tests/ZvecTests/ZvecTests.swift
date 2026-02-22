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
}

