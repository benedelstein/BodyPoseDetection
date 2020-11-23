//
//  ViewController.swift
//  AVSessionTest
//
//  Created by Ben Edelstein on 7/2/20.
//

import UIKit
import AVFoundation
import Vision

// delegate receives camera frames and processes them
// this delegate will be set to different VCs based on different tasks that need to be done (pose detection, object detection, etc)
protocol CameraViewControllerOutputDelegate: class {
    func cameraViewController(_ controller: CameraViewController, didReceiveBuffer buffer: CMSampleBuffer, orientation: CGImagePropertyOrientation)
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var outputDelegate: CameraViewControllerOutputDelegate?
    
    @IBOutlet weak var previewView: UIView!
    var previewLayer: AVCaptureVideoPreviewLayer! = nil // displays the camera output frames on the view
    var bufferSize: CGSize = .zero
    private let session = AVCaptureSession()
    private let videoDataOutput = AVCaptureVideoDataOutput() // provides access to frames for processing
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem) // queue for processing video data
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupAVCapture()
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        guard let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first else {
            print("could not find wide angle camera device")
            return
        }
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("could not create video device input: \(error.localizedDescription)")
            return
        }
        
        session.beginConfiguration()
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
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
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
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    // MARK: - COORDINATE CONVERSION
    
    /// converts normalized coords. vision rect to UIKit rect coordinates
    func viewRectForVisionRect(_ visionRect: CGRect) -> CGRect {
        let flippedRect = visionRect.applying(CGAffineTransform.verticalFlip)
        let viewRect: CGRect
        viewRect = previewLayer.layerRectConverted(fromMetadataOutputRect: flippedRect)
        return viewRect
    }
    
    // MARK: - video capture output delegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // process frames
        outputDelegate?.cameraViewController(self, didReceiveBuffer: sampleBuffer, orientation: .up)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        print("frame dropped")
    }

}

