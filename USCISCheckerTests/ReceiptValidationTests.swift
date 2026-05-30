import XCTest
@testable import USCISChecker

final class ReceiptValidationTests: XCTestCase {
    func testValidPrefixes() {
        for prefix in ["IOE", "MSC", "EAC", "WAC", "LIN", "SRC", "NBC"] {
            XCTAssertTrue(ReceiptValidator.isValid("\(prefix)1234567890"), "\(prefix) should be valid")
        }
    }

    func testInvalidPrefix() {
        XCTAssertFalse(ReceiptValidator.isValid("ABC1234567890"))
        XCTAssertFalse(ReceiptValidator.isValid("XYZ0000000000"))
    }

    func testTooShort() {
        XCTAssertFalse(ReceiptValidator.isValid("IOE123456789"))
    }

    func testTooLong() {
        XCTAssertFalse(ReceiptValidator.isValid("IOE12345678901"))
    }

    func testNonDigitSuffix() {
        XCTAssertFalse(ReceiptValidator.isValid("IOE123456789A"))
    }

    func testEmpty() {
        XCTAssertFalse(ReceiptValidator.isValid(""))
    }

    func testLowercaseRejected() {
        // isValid expects already-uppercased input; callers normalize before calling
        XCTAssertFalse(ReceiptValidator.isValid("ioe1234567890"))
    }
}
