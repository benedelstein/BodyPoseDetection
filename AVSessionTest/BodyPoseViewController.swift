//
//  BodyPoseViewController.swift
//  AVSessionTest
//
//  Created by Ben Edelstein on 7/4/20.
//

import UIKit
import AVFoundation
import Vision

@available(iOS 14.0, *)
class BodyPoseViewController: CameraViewController {

    private var poseOverlay: CALayer! = nil
    private var requests = [VNRequest]()
    private let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
    private let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1 // why is this so low?
    
    func setupVision() {
        let poseRequest = VNDetectHumanBodyPoseRequest { (request, error) in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            DispatchQueue.main.async {
                if let results = request.results {
                    self.handleVisionResults(results)
                }
            }

        }
        // setting a region of interest gives better results
        // but we would need to update this every frame, not just at setup, bc person can move in frame
        self.requests = [poseRequest]
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLayers()
        setupVision() // register detect body pose request
        startCaptureSession()
    }
    
    func setupLayers() {
        poseOverlay = CALayer() // container layer that has all the renderings of the observations
        poseOverlay.name = "PoseOverlay"
        print(bufferSize)
        poseOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        poseOverlay.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)
        previewLayer.addSublayer(poseOverlay) // previewLayer inherited from the superclass
    }
    
    func humanBoundingBox(for observation: VNRecognizedPointsObservation) -> CGRect {
        var box = CGRect.zero
        var normalizedBoundingBox = CGRect.null
        // Process body points only if the confidence is high.
        guard observation.confidence > bodyPoseDetectionMinConfidence, var points = try? observation.recognizedPoints(forGroupKey: .all) else {
            return box
        }
        points = points.filter { (key, point) in
            point.confidence > bodyPoseRecognizedPointMinConfidence
        }
        // Only use point if human pose joint was detected reliably.
        // points is a dictionary of key-values
        for (_, point) in points {
            normalizedBoundingBox = normalizedBoundingBox.union(CGRect(origin: point.location, size: .zero)) // create a box that barely encloses all the points
        }
        if !normalizedBoundingBox.isNull {
            box = normalizedBoundingBox
        }
        return box // returns a normalized bounding box of the body
    }
    
    func handleVisionResults(_ results: [Any]) {
        guard let observations = results as? [VNRecognizedPointsObservation] else {return}
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        poseOverlay.sublayers = nil // remove all the old recognized objects
        
        // 1 observation = 1 body
        for observation in observations {
            let boundingBox = humanBoundingBox(for: observation)
//            let viewRect1 = self.viewRectForVisionRect(boundingBox).insetBy(dx: -20.0, dy: -20.0) // convert to UIKit coords.
            let viewRect = VNImageRectForNormalizedRect(boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let boxLayer = self.drawBoundingBox(viewRect.insetBy(dx: -20, dy: -50))
            let joints = getBodyJointsFor(observation: observation)
            let jointsLayer = self.drawJoints(joints)
            poseOverlay.addSublayer(boxLayer)
            poseOverlay.addSublayer(jointsLayer)
        }
        
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func updateLayerGeometry() {
        let bounds = previewLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer 90 degrees into screen orientation and scale and mirror
        poseOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        poseOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    /// creates a CALayer bounding box from a CGRect enclosing a person
    func drawBoundingBox(_ bounds: CGRect) -> CALayer {
        let boxLayer = CALayer()
        boxLayer.bounds = bounds
        boxLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        boxLayer.backgroundColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 0.3566727312)
        boxLayer.cornerRadius = 10
        return boxLayer
    }
    
    /// returns a CAShapeLayer with dots for every joint on the recognized body
    func drawJoints(_ joints: [String: CGPoint]) ->CAShapeLayer {
        var imagePoints: [CGPoint] = []
        let jointsOfInterest: [VNRecognizedPointKey] = [
            .bodyLandmarkKeyNose,
            .bodyLandmarkKeyRightElbow,
            .bodyLandmarkKeyLeftElbow,
            .bodyLandmarkKeyLeftWrist,
            .bodyLandmarkKeyRightWrist,
            .bodyLandmarkKeyRoot,
        ]
        for (joint, location) in joints {
//            print("\(joint): \(location.x), \(location.y)")
            if jointsOfInterest.contains(VNRecognizedPointKey(rawValue: joint)) {
                let imagePoint = VNImagePointForNormalizedPoint(location, Int(bufferSize.width), Int(bufferSize.height))
                imagePoints.append(imagePoint)
            }
        }
        let jointPath = UIBezierPath()
        let jointsLayer = CAShapeLayer()
        jointsLayer.fillColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        for point in imagePoints {
            let nextJointPath = UIBezierPath(arcCenter: point, radius: 10, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            jointPath.append(nextJointPath)
        }
        jointsLayer.path = jointPath.cgPath
        return jointsLayer
    }
    
    // MARK: - Video buffer
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        }
        catch {
            print(error.localizedDescription)
        }
    }
}
