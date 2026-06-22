//
//  ViewController.swift
//  AVSessionTest
//
//  Created by Ben Edelstein on 7/2/20.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    var previewLayer: AVCaptureVideoPreviewLayer?
    var bufferSize: CGSize = .zero // size of the video buffer
    let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput() // provides access to frames for processing

    let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem) // queue for processing video data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupAVCapture()
    }
    
    // configures the app to process video frames
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // first look for cameras to get input from (should find your phone's default camera)
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
            print("could not find wide angle camera device")
            return
        }
        // try to create a device input with this camera device
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("could not create video device input: \(error.localizedDescription)")
            return
        }
        
        session.beginConfiguration() // declare start of atomic session config changes
        
        // set resolution based on minimum amount greater than ml model needs
        if videoDevice.supportsSessionPreset(.hd1920x1080) {
            session.sessionPreset = .hd1920x1080
        } else {
            session.sessionPreset = .high
        }
//        session.sessionPreset = .vga640x480
        
        guard session.canAddInput(deviceInput) else {
            print("could not add video device input to session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [
                String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            ] // output compression settings
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue) // set delegate to self for receiving buffer frames
        } else {
            print("couldn't add video data output to session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video) // connection between input and output objects, automatically added to session
        captureConnection?.isEnabled = true
        do {
            try videoDevice.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(videoDevice.activeFormat.formatDescription)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice.unlockForConfiguration()
        } catch {
            print("\(error.localizedDescription)")
        }
        session.commitConfiguration()
        let preview = AVCaptureVideoPreviewLayer(session: session) // displays video as it's captured
        preview.videoGravity = AVLayerVideoGravity.resizeAspectFill // video will fill the layer
        preview.frame = view.bounds // fill the whole view
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func startCaptureSession() {
        videoDataOutputQueue.async { [weak self] in
            self?.session.startRunning() // begins the flow of data from camera inputs to outputs
        }
    }
    
}

// MARK: - video capture output delegate
extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    // override this in a child class
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // process frames
//        outputDelegate?.cameraViewController(self, didReceiveBuffer: sampleBuffer, orientation: .up)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("frame dropped")
    }

}

// delegate receives camera frames and processes them
// this delegate will be set to different VCs based on different tasks that need to be done (pose detection, object detection, etc)
protocol CameraViewControllerOutputDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

