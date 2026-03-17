//
//  Common.swift
//  AVSessionTest
//
//  Created by Ben Edelstein on 7/5/20.
//
import UIKit
import Vision

// change these to draw points for whatever body parts you want
let jointsOfInterest: [VNHumanBodyPoseObservation.JointName] = [
    .nose,
    .rightElbow,
    .rightShoulder,
    .rightHip,
    .rightKnee,
    .rightAnkle
]

// takes an observation of joints with location and confidence
// returns a dict of points with just their location
@available(iOS 14.0, *)
func getBodyJointsFor(observation: VNHumanBodyPoseObservation) -> ([String: CGPoint]) {
    var joints = [String: CGPoint]()
    guard let identifiedPoints = try? observation.recognizedPoints(.all) else {
        return joints
    }
    for (key, point) in identifiedPoints {
        guard point.confidence > 0.1 else { continue } // filter out low confidence
        joints[key.rawValue.rawValue] = point.location
    }
    return joints
}
