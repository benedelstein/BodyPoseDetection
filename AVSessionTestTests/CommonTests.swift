//
//  CommonTests.swift
//  AVSessionTestTests
//
//  Tests for Common.swift utility functions
//

import XCTest
import Vision
@testable import AVSessionTest

class CommonTests: XCTestCase {

    // MARK: - jointsOfInterest

    func testJointsOfInterestContainsExpectedJoints() {
        let expected: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .rightElbow,
            .rightShoulder,
            .rightHip,
            .rightKnee,
            .rightAnkle
        ]
        XCTAssertEqual(jointsOfInterest, expected)
    }

    func testJointsOfInterestCount() {
        XCTAssertEqual(jointsOfInterest.count, 6)
    }

    // MARK: - CGAffineTransform.verticalFlip

    func testVerticalFlipTransformFlipsYAxis() {
        let transform = CGAffineTransform.verticalFlip

        // A point at (0.5, 0.0) in normalized coords should flip to (0.5, 1.0)
        let point = CGPoint(x: 0.5, y: 0.0)
        let flipped = point.applying(transform)
        XCTAssertEqual(flipped.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(flipped.y, 1.0, accuracy: 0.001)
    }

    func testVerticalFlipTransformFlipsTopToBottom() {
        let transform = CGAffineTransform.verticalFlip

        // A point at (0.5, 1.0) should flip to (0.5, 0.0)
        let point = CGPoint(x: 0.5, y: 1.0)
        let flipped = point.applying(transform)
        XCTAssertEqual(flipped.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(flipped.y, 0.0, accuracy: 0.001)
    }

    func testVerticalFlipPreservesMidpoint() {
        let transform = CGAffineTransform.verticalFlip

        let point = CGPoint(x: 0.5, y: 0.5)
        let flipped = point.applying(transform)
        XCTAssertEqual(flipped.x, 0.5, accuracy: 0.001)
        XCTAssertEqual(flipped.y, 0.5, accuracy: 0.001)
    }

    func testVerticalFlipPreservesXCoordinate() {
        let transform = CGAffineTransform.verticalFlip

        let point = CGPoint(x: 0.75, y: 0.3)
        let flipped = point.applying(transform)
        XCTAssertEqual(flipped.x, 0.75, accuracy: 0.001)
    }

    func testVerticalFlipIsOwnInverse() {
        // Applying verticalFlip twice should return to the original point
        let transform = CGAffineTransform.verticalFlip
        let point = CGPoint(x: 0.3, y: 0.7)
        let doubleFlipped = point.applying(transform).applying(transform)
        XCTAssertEqual(doubleFlipped.x, point.x, accuracy: 0.001)
        XCTAssertEqual(doubleFlipped.y, point.y, accuracy: 0.001)
    }

    func testVerticalFlipOnNormalizedRect() {
        let transform = CGAffineTransform.verticalFlip
        let rect = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let flipped = rect.applying(transform)

        XCTAssertEqual(flipped.origin.x, 0.1, accuracy: 0.001)
        // After flipping: y origin = -(0.2 + 0.4) + 1 = 0.4, but CGRect adjusts for negative height
        XCTAssertEqual(flipped.width, 0.3, accuracy: 0.001)
        XCTAssertEqual(flipped.size.height, 0.4, accuracy: 0.001)
    }
}
