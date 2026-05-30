import XCTest
@testable import USCISChecker

final class ModelTests: XCTestCase {
    func testCaseStatusCodableRoundTrip() throws {
        let status = CaseStatus(title: "Case Was Received", description: "We received your form.")
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(CaseStatus.self, from: data)
        XCTAssertEqual(decoded, status)
    }

    func testCaseRecordDefaults() {
        let record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "My I-485")
        XCTAssertNil(record.lastStatus)
        XCTAssertNil(record.lastChecked)
        XCTAssertNil(record.errorMessage)
        XCTAssertEqual(record.displayName, "My I-485")
    }

    func testCaseRecordDisplayNameFallsBackToReceiptNumber() {
        let record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "")
        XCTAssertEqual(record.displayName, "IOE1234567890")
    }

    func testCaseRecordCodableRoundTrip() throws {
        var record = CaseRecord(receiptNumber: "IOE1234567890", nickname: "Test")
        record.lastStatus = CaseStatus(title: "Case Was Received", description: "Some text.")
        record.lastChecked = Date(timeIntervalSince1970: 1000)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(CaseRecord.self, from: data)
        XCTAssertEqual(decoded.receiptNumber, record.receiptNumber)
        XCTAssertEqual(decoded.lastStatus?.title, "Case Was Received")
        XCTAssertEqual(decoded.lastChecked?.timeIntervalSince1970, 1000)
    }
}
