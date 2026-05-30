import XCTest
@testable import USCISChecker

@MainActor
final class CaseStoreTests: XCTestCase {
    var store: CaseStore!
    var suiteName: String!

    override func setUp() async throws {
        suiteName = "test-\(UUID().uuidString)"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let client = USCISClient(session: session)
        let defaults = UserDefaults(suiteName: suiteName)!
        store = CaseStore(client: client, defaults: defaults)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    func testAddCase() {
        let record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "My I-485")
        store.add(record)
        XCTAssertEqual(store.cases.count, 1)
        XCTAssertEqual(store.cases[0].receiptNumber, "IOE1234567890")
    }

    func testDeleteCase() {
        let record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "")
        store.add(record)
        store.delete(record)
        XCTAssertEqual(store.cases.count, 0)
    }

    func testPersistenceRoundTrip() throws {
        let record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "My I-485")
        store.add(record)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let reloaded = CaseStore(
            client: USCISClient(session: URLSession(configuration: config)),
            defaults: UserDefaults(suiteName: suiteName)!
        )
        XCTAssertEqual(reloaded.cases.count, 1)
        XCTAssertEqual(reloaded.cases[0].receiptNumber, "IOE1234567890")
    }

    func testRefreshUpdatesStatus() async {
        MockURLProtocol.responseHTML = """
        <html><body>
        <h1>Case Was Received</h1>
        <p>On July 1, 2024, we received your Form I-485.</p>
        </body></html>
        """
        store.add(CaseRecord(receiptNumber: "IOE1234567890", nickname: "Test"))
        await store.refresh(store.cases[0])

        XCTAssertEqual(store.cases[0].lastStatus?.title, "Case Was Received")
        XCTAssertNotNil(store.cases[0].lastChecked)
        XCTAssertNil(store.cases[0].errorMessage)
    }

    func testRefreshRetainsLastStatusOnBadResponse() async {
        MockURLProtocol.responseHTML = """
        <html><body><h1>Case Was Received</h1><p>Initial status.</p></body></html>
        """
        store.add(CaseRecord(receiptNumber: "IOE1234567890", nickname: "Test"))
        await store.refresh(store.cases[0])
        XCTAssertEqual(store.cases[0].lastStatus?.title, "Case Was Received")

        MockURLProtocol.responseHTML = "garbage html with no status"
        await store.refresh(store.cases[0])

        XCTAssertEqual(store.cases[0].lastStatus?.title, "Case Was Received")
        XCTAssertNotNil(store.cases[0].errorMessage)
    }
}
