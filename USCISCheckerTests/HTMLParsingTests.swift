import XCTest
@testable import USCISChecker

final class HTMLParsingTests: XCTestCase {
    let client = USCISClient()

    func testParsesStatusAndDescription() throws {
        let html = """
        <html><body>
        <h1>Case Was Received</h1>
        <p>On July 1, 2024, we received your Form I-485.</p>
        </body></html>
        """
        let status = try client.parseHTML(html)
        XCTAssertEqual(status.title, "Case Was Received")
        XCTAssertEqual(status.description, "On July 1, 2024, we received your Form I-485.")
    }

    func testThrowsWhenNoH1() {
        let html = "<html><body><p>Some text</p></body></html>"
        XCTAssertThrowsError(try client.parseHTML(html))
    }

    func testReturnsEmptyDescriptionWhenNoParagraph() throws {
        let html = "<html><body><h1>Case Was Received</h1></body></html>"
        let status = try client.parseHTML(html)
        XCTAssertEqual(status.title, "Case Was Received")
        XCTAssertEqual(status.description, "")
    }

    func testStripsInnerTagsFromTitle() throws {
        let html = """
        <html><body>
        <h1>Case Was <strong>Approved</strong></h1>
        <p>Your case was approved.</p>
        </body></html>
        """
        let status = try client.parseHTML(html)
        XCTAssertEqual(status.title, "Case Was Approved")
    }

    func testStripsInnerTagsFromDescription() throws {
        let html = """
        <html><body>
        <h1>Case Was Received</h1>
        <p>We received your <a href="#">Form I-485</a>.</p>
        </body></html>
        """
        let status = try client.parseHTML(html)
        XCTAssertEqual(status.description, "We received your Form I-485.")
    }

    func testHandlesH1WithAttributes() throws {
        let html = """
        <html><body>
        <h1 class="status-title">Case Was Received</h1>
        <p>We received your form.</p>
        </body></html>
        """
        let status = try client.parseHTML(html)
        XCTAssertEqual(status.title, "Case Was Received")
    }

    func testThrowsWhenH1IsEmpty() {
        let html = "<html><body><h1></h1><p>Some text.</p></body></html>"
        XCTAssertThrowsError(try client.parseHTML(html))
    }
}
