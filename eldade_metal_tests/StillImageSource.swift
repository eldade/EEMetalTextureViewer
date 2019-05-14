//
//  CameraSource.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 10/2/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

import Foundation
import AVFoundation

class CameraSource : NSObject, PixelSource, AVCaptureVideoDataOutputSampleBufferDelegate {

    let pickerCameraResolutionSettings = [
        "AVCaptureSessionPresetPhoto",
        "AVCaptureSessionPresetHigh",
        "AVCaptureSessionPresetMedium",
        "AVCaptureSessionPresetLow",
        "AVCaptureSessionPreset352x288",
        "AVCaptureSessionPreset640x480",
        "AVCaptureSessionPreset1280x720",
        "AVCaptureSessionPreset1920x1080",
        "AVCaptureSessionPreset3840x2160",
        ]
    
    var pixelFormat : OSType = kCVPixelFormatType_32BGRA {
        didSet {
            videoOutputQueue.sync {
                videoOut.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String! : NSNumber(value: Int(pixelFormat)) ]
            }
        }
    }
    var supportedImages : [String] {
        var availablePresets : [String] = []
        for currentPreset in pickerCameraResolutionSettings {
            if (captureSession.canSetSessionPreset(currentPreset)) {
                availablePresets.append(currentPreset)
            }
        }
        
        return availablePresets
    }
    
    var supportedPixelFormats : [String : OSType] = [
        "32BGRA" : 1111970369,
        "420YpCbCr8BiPlanarVideoRange" : 875704438,
        "420YpCbCr8BiPlanarFullRange" : 875704422]
    
    var supportedPixelFormatNames: [String] {
        let allKeys = supportedPixelFormats.keys
        let pixFormatNamesSortedList : [String] = allKeys.sorted {
            $0 < $1
        }
        
        return pixFormatNamesSortedList
    }
    
    var currentImage : String = "AVCaptureSessionPresetHigh" {
        didSet {
            videoOutputQueue.async {
                self.captureSession.sessionPreset = self.currentImage
            }
        }
    }
    
    internal var delegate: PixelSourceDelegate! = nil {
        didSet {
//            setupCaptureSession()
        }
    }
    
    var videoIn : AVCaptureDeviceInput? = AVCaptureDeviceInput()
    
    var captureSession : AVCaptureSession = AVCaptureSession()
    
    var videoConnection : AVCaptureConnection = AVCaptureConnection()
    
    let videoOutputQueue : DispatchQueue = DispatchQueue(label: "videoOutputQueue")
    
    let videoOut = AVCaptureVideoDataOutput.init()
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startedRunning),
            name: NSNotification.Name.AVCaptureSessionDidStartRunning,
            object: nil)

        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureError),
            name: NSNotification.Name.AVCaptureSessionRuntimeError,
            object: nil)
    }
    
    func startedRunning(notification: NSNotification) {
        
    }
    
    func captureError(notification: NSNotification) {
        
    }

    
    func setupCaptureSession()
    {
        let videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo) as AVCaptureDevice!
        
        do {
            videoIn = try AVCaptureDeviceInput.init(device: videoDevice)
        }
        catch {
            
        }
        
        if ( captureSession.canAddInput(videoIn) ) {
            captureSession.addInput(videoIn)
        }
        else {
            return;
        }
        
        videoOut.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String! : NSNumber(value: Int(pixelFormat)) ]
        
        videoOut.setSampleBufferDelegate(self, queue: videoOutputQueue)
        
        videoOut.alwaysDiscardsLateVideoFrames = true
        
        
        if ( captureSession.canAddOutput(videoOut)) {
            captureSession.addOutput(videoOut)
        }
        
        //        let videoConnection = videoOut.connection(withMediaType: AVMediaTypeVideo)
        
        var frameDuration = kCMTimeInvalid
        
        if (captureSession.canSetSessionPreset(currentImage)) {
            captureSession.sessionPreset = currentImage
        }
        
        do {
            if (( try videoDevice?.lockForConfiguration() ) != nil) {
                let frameRateRange = videoDevice?.activeFormat.videoSupportedFrameRateRanges
                let firstRange = frameRateRange?.first as! AVFrameRateRange
                
                frameDuration = CMTimeMake ( 1, Int32(firstRange.maxFrameRate) )
                
                videoDevice?.activeVideoMaxFrameDuration = frameDuration
                videoDevice?.activeVideoMinFrameDuration = frameDuration
                videoDevice?.unlockForConfiguration()
            }
            else {
                print ( "videoDevice lockForConfiguration returned error")
            }
        }
        catch {
            
        }
        
        
        return;
    }
        
    func startStreaming() {
        setupCaptureSession()
        captureSession.startRunning()
    }
    
    func stopStreaming() {
        captureSession.stopRunning()
        videoOutputQueue.sync {
        }
        captureSession.removeOutput(videoOut)
        captureSession.removeInput(videoIn)
        videoIn = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let formatDescription = CMSampleBufferGetFormatDescription( sampleBuffer )
        let sourcePixelBuffer = CMSampleBufferGetImageBuffer( sampleBuffer )
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription!)
        
        delegate.imageSize = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
        CVPixelBufferLockBaseAddress(sourcePixelBuffer!, CVPixelBufferLockFlags.readOnly)
        var planeDescriptors: [PVPlaneDescriptor] = []
        
        var planeCount = CVPixelBufferGetPlaneCount(sourcePixelBuffer!)
        if (planeCount == 0) {
            planeCount = 1
        }
        
        for plane in 0...planeCount - 1 {
            let size = CGSize(width: CVPixelBufferGetWidthOfPlane(sourcePixelBuffer!, plane), height: CVPixelBufferGetHeightOfPlane(sourcePixelBuffer!, plane))
            
            planeDescriptors.append(PVPlaneDescriptor(data: CVPixelBufferGetBaseAddressOfPlane(sourcePixelBuffer!, plane)!,
                                                      size: size,
                                                      rowBytes: CVPixelBufferGetBytesPerRowOfPlane(sourcePixelBuffer!, plane)))
        }
        
        
        delegate.planeDescriptors = planeDescriptors
        delegate.render()
        CVPixelBufferUnlockBaseAddress(sourcePixelBuffer!, CVPixelBufferLockFlags.readOnly)        
    }
    
    
}
