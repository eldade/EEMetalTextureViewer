//
//  CVPixelFormatInfo.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 10/29/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

import Foundation
import UIKit

enum CVPixelFormatStructure {
    case planar
    case packed
}

enum CVPixelFormatComponentRange {
    case none
    case video
    case full
    case wide
}

class CVPixelFormatPlaneInfo {
    private var planeDictionary : [String:Any]
    fileprivate init?(_ planeDictionary : [String:Any]?) {
        if let confirmedDictionary = planeDictionary {
            self.planeDictionary = confirmedDictionary
        }
        else {
            return nil
        }
    }
}

struct CVPixelFormatContents : OptionSet {
    let rawValue: Int
    
    static let containsAlpha  = CVPixelFormatContents(rawValue: 1 << 0)
    static let containsRGB = CVPixelFormatContents(rawValue: 1 << 1)
    static let containsYCbCr  = CVPixelFormatContents(rawValue: 1 << 2)
}

struct CVPixelFormatInfo {
    private var formatDescription : [String:Any]
//    private var planeDictionaries : [Dictionary<String, Any>]?
    
    var planes : [CVPixelFormatPlaneInfo] = [CVPixelFormatPlaneInfo]()

    init?(_ pixelFormat : OSType) {
        let cfDictionary = CVPixelFormatDescriptionCreateWithPixelFormatType(kCFAllocatorDefault, pixelFormat)
            
        if let confirmedDictionary = cfDictionary {
            formatDescription = confirmedDictionary as! [String:Any]
            
            if let planeDictionaries = formatDescription[kCVPixelFormatPlanes as String] as! [Dictionary<String, Any>]? {
                for plane in planeDictionaries {
                    planes.append(CVPixelFormatPlaneInfo(plane)!)
                }
            }
        }
        else {
            print ("\(type(of: self)).init(): Requested unregistered CoreVideo pixel format (\(pixelFormat))")
            return nil
        }
    }
    
    private var plane : CVPixelFormatPlaneInfo? {
        return CVPixelFormatPlaneInfo(formatDescription[kCVPixelFormatPlanes as String] as! [String : Any]?)
    }
    
    var structure : CVPixelFormatStructure {
        if planes.count != 0 {
            return .planar
        } else {
            return .packed
        }
    }
    
    var planeCount : Int {
        if planes.count != 0 {
            return planes.count
        } else {
            return 1
        }
    }
    
    private var containsAlpha : Bool {
        return formatDescription[kCVPixelFormatContainsAlpha as String] as! Bool
    }
    
    private var containsRGB : Bool {
        return formatDescription[kCVPixelFormatContainsRGB as String] as! Bool
    }

    private var containsYCbCr : Bool {
        return formatDescription[kCVPixelFormatContainsYCbCr as String] as! Bool
    }
    
    var contents : CVPixelFormatContents {
        var contents : CVPixelFormatContents = []
        if containsAlpha {
            contents.insert(.containsAlpha)
        }

        if containsRGB {
            contents.insert(.containsRGB)
        }
        
        if containsYCbCr {
            contents.insert(.containsYCbCr)
        }
        
        return contents
    }
    
    var componentRange : CVPixelFormatComponentRange {
        if let rangeString = formatDescription[kCVPixelFormatComponentRange as String] as! String? {
            if rangeString == kCVPixelFormatComponentRange_FullRange as String {
                return .full
            }
            if rangeString == kCVPixelFormatComponentRange_VideoRange as String {
                return .video
            }
            if rangeString == kCVPixelFormatComponentRange_WideRange as String {
                return .wide
            }
            return .none
        }
        else {
            return .none
        }
    }
    
    var cgBitmapContextCompatible : Bool {
        //public let kCVPixelBufferCGBitmapContextCompatibilityKey: CFString // CFBoolean
        if let test = formatDescription[kCVPixelBufferCGBitmapContextCompatibilityKey as String] {
            return test as! Bool
        }

        return false
    }

    var cgImageCompatible : Bool {
        if let test = formatDescription[kCVPixelBufferCGImageCompatibilityKey as String] {
            return test as! Bool
        }
        
        return false
    }

    var openGLCompatible : Bool {
        if let test = formatDescription[kCVPixelBufferOpenGLCompatibilityKey as String] {
            return test as! Bool
        }
        
        return false
    }
    
    var openGLESCompatible : Bool {
        if let test = formatDescription[kCVPixelBufferOpenGLESCompatibilityKey as String] {
            return test as! Bool
        }
        
        return false
    }
    
    var metalCompatible : Bool {
        if let test = formatDescription[kCVPixelBufferMetalCompatibilityKey as String] {
            return test as! Bool
        }
        
        return false
    }

}
