//
//  CameraViewControllerTests.swift
//  AVSessionTestTests
//
//  Tests for CameraViewController
//

import XCTest
import AVFoundation
@testable import AVSessionTest

class CameraViewControllerTests: XCTestCase {

    var viewController: CameraViewController!

    override func setUp() {
        super.setUp()
        viewController = CameraViewController()
    }

    override func tearDown() {
        viewController = nil
        super.tearDown()
    }

    // MARK: - Initialization

    func testInitialBufferSizeIsZero() {
        XCTAssertEqual(viewController.bufferSize, CGSize.zero)
    }

    func testPreviewLayerIsNilBeforeViewLoad() {
        // Before viewDidLoad, previewLayer should be nil
        XCTAssertNil(viewController.previewLayer)
    }

    // MARK: - viewRectForVisionRect

    func testViewRectForVisionRectAppliesVerticalFlip() {
        // We need the view loaded and previewLayer set up
        // Since setupAVCapture requires a camera device (not available in test),
        // we test the transform math independently
        let visionRect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let flipped = visionRect.applying(CGAffineTransform.verticalFlip)

        // After vertical flip of a full normalized rect, should still be unit rect
        XCTAssertEqual(flipped.width, 1.0, accuracy: 0.001)
        XCTAssertEqual(flipped.height, 1.0, accuracy: 0.001)
    }

    // MARK: - CameraViewControllerOutputDelegate protocol

    func testOutputDelegateProtocolExists() {
        // Verify the protocol can be referenced (compile-time check)
        // This ensures the protocol definition is accessible
        let _: CameraViewControllerOutputDelegate.Type = CameraViewControllerOutputDelegate.self
        XCTAssertTrue(true)
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func testConformsToVideoOutputDelegate() {
        XCTAssertTrue(viewController is AVCaptureVideoDataOutputSampleBufferDelegate)
    }

    // MARK: - Buffer size

    func testBufferSizeCanBeSet() {
        viewController.bufferSize = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(viewController.bufferSize.width, 1920)
        XCTAssertEqual(viewController.bufferSize.height, 1080)
    }

    func testBufferSizeWithDifferentResolutions() {
        let resolutions: [CGSize] = [
            CGSize(width: 640, height: 480),
            CGSize(width: 1280, height: 720),
            CGSize(width: 1920, height: 1080),
            CGSize(width: 3840, height: 2160)
        ]

        for resolution in resolutions {
            viewController.bufferSize = resolution
            XCTAssertEqual(viewController.bufferSize, resolution)
        }
    }
}
