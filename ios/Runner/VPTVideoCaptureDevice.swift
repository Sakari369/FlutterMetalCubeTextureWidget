//
//  VPTVideoCaptureDevice.swift
//  VPTEngine
//
//  Modified and extended for use within VisualPT LLC by Charles Richardson since 3/7/24.
//
//  Created by Alex Staravoitau on 25/07/2016.
//  Original Copyright © 2016 Old Yellow Bricks.
//

import AVFoundation

/// A wrapper for the `AVFoundation`'s `AVCaptureDevice` that has instance methods instead of the class ones. This wrapper will make unit testing so much easier.
internal class VPTVideoCaptureDevice {
    /**
     Attempts to get a capture device with specified media type and position.

     - parameter for: Device media type
     - parameter with: Device position

     - returns: Capture device or `nil`.
     */
    internal func device(for mediaType: AVMediaType, with position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let session = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: mediaType, position: position);
        return session.devices.first
    }

    /**
     Requests access to capture device with specified media type.

     - parameter for: Device media type
     - parameter completionHandler: A block called with the result of requesting access
     */
    internal func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping ((Bool) -> Void)) {
        AVCaptureDevice.requestAccess(for: mediaType, completionHandler: handler)
    }
}
