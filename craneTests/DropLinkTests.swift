//
//  DropLinkTests.swift
//  craneTests
//

import XCTest
@testable import crane

final class DropLinkTests: XCTestCase {

    func testNormalizesSchemelessURL() {
        XCTAssertEqual(Drop.normalizedLinkText("example.com"), "https://example.com")
    }

    func testValidatesHTTPS() {
        XCTAssertTrue(Drop.isValidLinkText("https://example.com/path"))
        XCTAssertFalse(Drop.isValidLinkText("not a url"))
        XCTAssertFalse(Drop.isValidLinkText("javascript:alert(1)"))
    }

    func testLinkURLForLegacyRow() {
        XCTAssertNotNil(Drop.linkURL(for: "example.com"))
        XCTAssertEqual(Drop.linkURL(for: "example.com")?.host, "example.com")
    }
}
