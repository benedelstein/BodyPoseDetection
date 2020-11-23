//
//  BodyPoseViewController.swift
//  AVSessionTest
//
//  Created by Ben Edelstein on 7/4/20.
//
/* flow of events
 1) frame comes in
 2) image request handler runs the detect pose request
 3) pose request calls handleVisionResults() when done
 4) get bounding box for each person, scale it, draw it
 5) draw points for each person
 6) update UI all at once, scaling and rotating to get the right orientation
 */

import UIKit
import AVFoundation
import Vision

@available(iOS 14.0, *)
class BodyPoseViewController: CameraViewController {

    private var poseOverlay: CALayer! = nil
    private var requests = [VNRequest]() // array of vision requests to process
    private let bodyPoseDetectionMinConfidence: VNConfidence = 0.6
    private let bodyPoseRecognizedPointMinConfidence: VNConfidence = 0.1 // why is this so low?
    
    override func viewDidLoad() {
        super.viewDidLoad() // sets up the AVSession
        setupLayers()
        setupVision() // register detect body pose request
        startCaptureSession()
    }
    
    /// setup method to be able to display body points later on
    func setupLayers() {
        poseOverlay = CALayer() // container layer that has all the renderings of the observations
        poseOverlay.name = "PoseOverlay"
        print(bufferSize)
        poseOverlay.bounds = CGRect(x: 0.0,
                                    y: 0.0,
                                    width: bufferSize.width,
                                    height: bufferSize.height) // set the layer to cover the whole video buffer size
//        poseOverlay.position = CGPoint(x: previewLayer.bounds.midX, y: previewLayer.bounds.midY)
        view.layer.insertSublayer(poseOverlay, above: previewLayer) // insert this on top of the camera layer
    }
    
    /// register detect body pose request
    func setupVision() {
        // declare the request with a callback when its done
        let poseRequest = VNDetectHumanBodyPoseRequest { (request, error) in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            DispatchQueue.main.async { // update UI on main thread
                if let results = request.results {
                    self.handleVisionResults(results) // parse out body parts
                }
            }

        }
        // poseRequest.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        // setting a normalized region of interest gives better results
        // BUT we would need to update this every frame, not just at setup, bc person can move in frame
        self.requests = [poseRequest]
    }
    
    /// processes the results from a body pose detection request
    func handleVisionResults(_ results: [Any]) {
        guard let observations = results as? [VNRecognizedPointsObservation] else {return}
        
        CATransaction.begin() // update UI atomically
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        poseOverlay.sublayers = nil // remove all the old recognized objects
        
        // 1 observation = 1 body. Process each body in the frame.
        for observation in observations {
            let boundingBox = self.humanBoundingBox(for: observation)
            let viewRect = VNImageRectForNormalizedRect(boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let boxLayer = self.drawBoundingBox(viewRect.insetBy(dx: -50, dy: -50)) // give some padding around the bounding box (x and y are reversed here)
            let joints = getBodyJointsFor(observation: observation)
            let jointsLayer = self.drawJoints(joints)
            poseOverlay.addSublayer(boxLayer)
            poseOverlay.addSublayer(jointsLayer)
        }
        
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    /// creates a normalized bounding box enclosing a person
    func humanBoundingBox(for observation: VNRecognizedPointsObservation) -> CGRect {
        var box = CGRect.zero
        var normalizedBoundingBox = CGRect.null
        // Process body points only if the confidence is high.
        guard observation.confidence > bodyPoseDetectionMinConfidence, var points = try? observation.recognizedPoints(forGroupKey: .all) else {
            return box
        }
        points = points.filter { (key, point) in
            point.confidence > bodyPoseRecognizedPointMinConfidence // only get high confidence points
        }
        // points is a dictionary of key-values
        // key = type of joint (elbow, nose, etc)
        // value = VNRecognizedPoint
        for (_, point) in points {
            normalizedBoundingBox = normalizedBoundingBox.union(CGRect(origin: point.location, size: .zero)) // create a box that barely encloses all the points
        }
        if !normalizedBoundingBox.isNull {
            box = normalizedBoundingBox
        }
        return box // returns a normalized bounding box of the body; if nothing was found then returns zero size
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
        // i'm not sure what this scaling does
        print(xScale,yScale)
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // we need to do some manipulation to get the UI to show up correctly
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
    
    /// returns a CAShapeLayer with dots for every joint of interest on the recognized body
    func drawJoints(_ joints: [String: CGPoint]) -> CAShapeLayer {
        var imagePoints: [CGPoint] = []
        for (joint, location) in joints {
            // only pick the joints of interest
            if jointsOfInterest.contains(VNHumanBodyPoseObservation.JointName(rawValue: VNRecognizedPointKey(rawValue: joint))) {
                let imagePoint = VNImagePointForNormalizedPoint(location, Int(bufferSize.width), Int(bufferSize.height)) // scale coordinate to image coordinate system
                imagePoints.append(imagePoint)
            }
        }
        let jointPath = UIBezierPath()
        let jointsLayer = CAShapeLayer()
        jointsLayer.fillColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        for point in imagePoints {
            // draw a little circle at each point
            let nextJointPath = UIBezierPath(arcCenter: point, radius: 10, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            jointPath.append(nextJointPath)
        }
        jointsLayer.path = jointPath.cgPath
        return jointsLayer
    }
    
    // MARK: - Video buffer
    /// this method is called any time a video frame is received (delegate method inherited from parent)
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]) // processes the requests
        do {
            try imageRequestHandler.perform(self.requests)
        }
        catch {
            print(error.localizedDescription)
        }
    }
}
