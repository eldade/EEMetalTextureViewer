//
//  CameraSource.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 10/2/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import Accelerate

class StillImageSource : NSObject, PixelSource {
    
    fileprivate let permuteMap_kCVPixelFormatType_32ARGB : [UInt8] = [ 3, 0, 1, 2 ] // kCVPixelFormatType_32ARGB
    fileprivate let permuteMap_kCVPixelFormatType_32BGRA : [UInt8] = [ 2, 1, 0, 3 ] // kCVPixelFormatType_32BGRA
    fileprivate let permuteMap_kCVPixelFormatType_32ABGR : [UInt8] = [ 3, 2, 1, 0 ] // kCVPixelFormatType_32ABGR
    fileprivate let permuteMap_kCVPixelFormatType_32RGBA : [UInt8] = [ 0, 1, 2, 3 ] // kCVPixelFormatType_32RGBA
    
    fileprivate let pixelRangeFull = vImage_YpCbCrPixelRange(Yp_bias: 0, CbCr_bias: 128, YpRangeMax: 255, CbCrRangeMax: 255, YpMax: 255, YpMin: 1, CbCrMax: 255, CbCrMin: 0)       // full range 8-bit, clamped to full range
    fileprivate let pixelRangeVideoUnclamped = vImage_YpCbCrPixelRange( Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 255, YpMin: 0, CbCrMax: 255, CbCrMin: 1 )      // video range 8-bit, unclamped
    fileprivate let pixelRangeVideoClamped = vImage_YpCbCrPixelRange( Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 235, YpMin: 16, CbCrMax: 240, CbCrMin: 16 )    // video range 8-bit, clamped to video range

    
    fileprivate var originalBuffer : vImage_Buffer = vImage_Buffer()
    
    var timer : Timer? = nil
    
    var pixelFormat : OSType = kCVPixelFormatType_32BGRA {
        didSet {
            generateSampleImage()
        }
    }
    
    var currentImage : String = "iPad Screen.png" {
        didSet {
            generateSampleImage()
        }
    }
    
    var planes : [vImage_Buffer] = [vImage_Buffer](repeating: vImage_Buffer(), count: 3)
    var planeCount = 0
    
    var supportedImages : [String]  = [
        "iPhone5.png",
        "iPad Screen.png",
        "iPhones.png",
        "yuv.png"
    ]
    
    var supportedPixelFormats : [String : OSType] = [
        "24RGB" : 24,
        "24BGR" : 842285639,
        "32ARGB" : 32,
        "32BGRA" : 1111970369,
        "32ABGR" : 1094862674,
        "32RGBA" : 1380401729,
        "4444YpCbCrA8" : 1983131704,
        "4444AYpCbCr8" : 2033463352,
        "444YpCbCr8" : 1983066168,
        "420YpCbCr8Planar" : 2033463856,
        "16LE555" : 1278555445,
        "16LE5551" : 892679473,
        "16LE565" : 1278555701,
        "420YpCbCr8BiPlanarVideoRange" : 875704438,
        "420YpCbCr8BiPlanarFullRange" : 875704422,
        "422YpCbCr8" : 846624121,
        "420YpCbCr8PlanarFullRange" : 1714696752
    ]
    
    var supportedPixelFormatNames: [String] {
        let allKeys = supportedPixelFormats.keys
        let pixFormatNamesSortedList : [String] = allKeys.sorted {
            $0 < $1
        }
        
        return pixFormatNamesSortedList
    }
    
    internal var delegate: PixelSourceDelegate! = nil {
        didSet {
//            setupCaptureSession()
        }
    }
    
    let imageStreamingQueue : DispatchQueue = DispatchQueue(label: "imageStreamingQueue")
    
    override init() {
        super.init()
        
    }
    
    func generateSampleImage()
    {
        let image = UIImage.init(named: currentImage)!
        var originalBuffer = vImage_Buffer( data: imageDataFromUIImage(image: image),
                                            height: UInt(image.size.height),
                                            width: UInt(image.size.width),
                                            rowBytes: Int(image.size.width) * 4)
        
        var err = kvImageNoError
        switch (pixelFormat)
        {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            err = RGBA32to2PlanarYpCbCr(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_420YpCbCr8Planar, kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            err = RGBA32to3PlanarYpCbCr(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_422YpCbCr8:
            err = RGBA32toInterleaved422YpCbCr(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_444YpCbCr8:
            err = RGBA32toInterleaved444YpCbCr(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_4444AYpCbCr8:
            err = RGBA32toInterleaved444AYpCbCr8(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_4444YpCbCrA8:
            err = RGBA32toInterleaved444YpCbCrA8(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_16LE565,
             kCVPixelFormatType_16LE555,
             kCVPixelFormatType_16LE5551:
            err = RGBA32to16bpp(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_24BGR,
             kCVPixelFormatType_24RGB:
            RGBA32to24bpp(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        case kCVPixelFormatType_32ARGB,
             kCVPixelFormatType_32BGRA,
             kCVPixelFormatType_32ABGR,
             kCVPixelFormatType_32RGBA:
            RGBA32to32bppRGBA(sourceBuffer: &originalBuffer, pixelFormat: pixelFormat)
        default:
            break
        }
        
        free(originalBuffer.data)
        
        delegate.imageSize = image.size
        
        var planeDescriptors: [PVPlaneDescriptor] = []
        
        let planeBaseAddresses = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: planeCount)
        let planeWidths = UnsafeMutablePointer<Int>.allocate(capacity: planeCount)
        let planeHeights = UnsafeMutablePointer<Int>.allocate(capacity: planeCount)
        let planeBytesPerRow = UnsafeMutablePointer<Int>.allocate(capacity: planeCount)
        
        for planeIndex in 0...planeCount-1 {
            
            planeBaseAddresses[planeIndex] = planes[planeIndex].data
            planeWidths[planeIndex] = Int(planes[planeIndex].width)
            planeHeights[planeIndex] = Int(planes[planeIndex].height)
            planeBytesPerRow[planeIndex] = Int(planes[planeIndex].rowBytes)
        }
        
        var pixelBuffer : CVPixelBuffer?
        
        
        //UnsafeMutablePointer<UnsafeMutableRawPointer>.null()
        
        
        for planeIndex in 0...planeCount-1 {
            
            planeDescriptors.append(PVPlaneDescriptor(data: (planes[planeIndex].data),
                                                      size: CGSize(width: CGFloat(planes[planeIndex].width), height: CGFloat(planes[planeIndex].height)),
                                                      rowBytes: planes[planeIndex].rowBytes))
        }
        
        
        delegate.planeDescriptors = planeDescriptors
}
    
    @objc func timerCallback(timer : Timer) {
        
        if planeCount == 0 {
            return
        }
        
//        generateSampleImage()
        
        let plane = planes[0]
        
        
//        memset(planes[0].data, 0, test)
        
//        var planeBaseAddresses = [UnsafeMutableRawPointer]()
//        var planeWidths = [Int]()
//        var planeHeights = [Int]()
//        var planeBytesPerRow = [Int]()
        

        delegate.render()
        
//        delegate.renderCVImageBuffer(pixelBuffer!)
        
    }

    
    func startStreaming() {
        timer = Timer.scheduledTimer(timeInterval: 1/60, target: self, selector: #selector(timerCallback), userInfo: nil, repeats: true)
    }
    
    func stopStreaming() {
        timer?.invalidate()
        timer = nil
        
        for plane in planes {
            if plane.data != nil {
                free(plane.data)
            }
        }
        
        planes = [vImage_Buffer](repeating: vImage_Buffer(), count: 3)
    }
    
    func imageDataFromUIImage(image: UIImage!) -> UnsafeMutableRawPointer
    {
        let imageRef = image.cgImage!
        let width = imageRef.width
        let height = imageRef.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let rawData = calloc(height * width * 4, 1)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let context = CGContext(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        
        context.draw(imageRef, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return rawData!
    }
    
    // Convert to kCVPixelFormatType_32ARGB, kCVPixelFormatType_32BGRA, kCVPixelFormatType_32ABGR, or kCVPixelFormatType_32RGBA:
    func RGBA32to32bppRGBA(sourceBuffer : inout vImage_Buffer, pixelFormat: OSType)
    {
        var permuteMap : [UInt8]
    
        var dest32bpp = vImage_Buffer( data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 4), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 4)
        
        switch (pixelFormat)
        {
            case kCVPixelFormatType_32ARGB:
                permuteMap = permuteMap_kCVPixelFormatType_32ARGB
            case kCVPixelFormatType_32BGRA:
                permuteMap = permuteMap_kCVPixelFormatType_32BGRA
            case kCVPixelFormatType_32ABGR:
                permuteMap = permuteMap_kCVPixelFormatType_32ABGR
            case kCVPixelFormatType_32RGBA:
                permuteMap = permuteMap_kCVPixelFormatType_32RGBA
            default:
                return
        }
        
        vImagePermuteChannels_ARGB8888(&sourceBuffer, &dest32bpp, permuteMap, vImage_Flags(kvImageNoFlags))
        planes[0] = dest32bpp
        planeCount = 1
    }
    
    // Convert to kCVPixelFormatType_16LE555, kCVPixelFormatType_16LE5551 or kCVPixelFormatType_16LE565:
    func RGBA32to16bpp( sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var dest16bpp = vImage_Buffer( data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 2), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 2)
    
        let err = vImageConvert_RGBA8888toRGB565(&sourceBuffer, &dest16bpp, vImage_Flags(kvImageNoFlags))
    
        if pixelFormat == kCVPixelFormatType_16LE5551 || pixelFormat == kCVPixelFormatType_16LE555 {
            vImageConvert_RGB565toRGBA5551(&dest16bpp, &dest16bpp, Int32(kvImageConvert_DitherNone), vImage_Flags(kvImageNoFlags))
        }
        
        planes[0] = dest16bpp
        planeCount = 1
        
        return err
    }
    
    // Convert to kCVPixelFormatType_24RGB or kCVPixelFormatType_24BGR:
    func RGBA32to24bpp( sourceBuffer : inout vImage_Buffer, pixelFormat: OSType)
    {
        var dest24bpp = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 3), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 3)
        
        vImageConvert_RGBA8888toRGB888(&sourceBuffer, &dest24bpp, vImage_Flags(kvImageNoFlags));
        
        if pixelFormat == kCVPixelFormatType_24BGR {
            let permuteMap : [UInt8] = [2, 1, 0]
            vImagePermuteChannels_RGB888(&dest24bpp, &dest24bpp, permuteMap, vImage_Flags(kvImageNoFlags));
        }
        
        planes[0] = dest24bpp;
        planeCount = 1;
    }
    
    // Convert to kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange or kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
    func RGBA32to2PlanarYpCbCr(sourceBuffer: inout vImage_Buffer, pixelFormat: OSType) -> Int
    {
        var err : vImage_Error = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        if pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange {
            pixelRange = pixelRangeVideoClamped
        } else {
            pixelRange = pixelRangeFull
        }
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage420Yp8_CbCr8, flags);
        
        var destYp = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height)), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width))
        var destCbCr = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height)), height: sourceBuffer.height/2, width: sourceBuffer.width/2, rowBytes: Int(sourceBuffer.width))
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2] // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To420Yp8_CbCr8(&sourceBuffer,  &destYp, &destCbCr, &outInfo, permuteMap, flags)
        
        planes[0] = destYp
        planes[1] = destCbCr
        planeCount = 2
        
        return err
    }
    
    // Convert to kCVPixelFormatType_420YpCbCr8Planar or kCVPixelFormatType_420YpCbCr8PlanarFullRange
    func RGBA32to3PlanarYpCbCr( sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var err = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        if pixelFormat == kCVPixelFormatType_420YpCbCr8Planar {
            pixelRange = pixelRangeVideoClamped
        } else {
            pixelRange = pixelRangeFull
        }
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage420Yp8_Cb8_Cr8, flags);
        
        var destYp = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height)),
                                   height: sourceBuffer.height,
                                   width: sourceBuffer.width,
                                   rowBytes: Int(sourceBuffer.width))
        var destCb = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height)),
                                   height: sourceBuffer.height / 2,
                                   width: sourceBuffer.width / 2,
                                   rowBytes: Int(sourceBuffer.width / 2))
        
        var destCr = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height)),
                                   height: sourceBuffer.height / 2,
                                   width: sourceBuffer.width / 2,
                                   rowBytes: Int(sourceBuffer.width / 2))
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2] // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&sourceBuffer,  &destYp, &destCb, &destCr, &outInfo, permuteMap, flags);
        
        planes[0] = destYp
        planes[1] = destCb
        planes[2] = destCr
        planeCount = 3
        
        return err
    }
    
    // Convert to kCVPixelFormatType_444YpCbCr8:
    func RGBA32toInterleaved444YpCbCr(sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var err = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange = pixelRangeVideoClamped
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage444CrYpCb8, flags)
        
        var dest = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 3), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 3)
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2] // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To444CrYpCb8(&sourceBuffer, &dest, &outInfo, permuteMap, flags)
        
        // TO DO: still unclear on the actual byte ordering for kCVPixelFormatType_444YpCbCr8 aka 'v308'. Accelerate framework treats it as CrYpCb, but I haven't
        // found any other evidence that that's the actual ordering for that format. I've configured the pixel viewer to expect this ordering for now. If that's
        // wrong, the following PermuteChannels call correctly reverses the order to match the name of the format (YpCbCr).
        
        //    // The above produces an image in a format that's completely undefined in the CV pixel format definitions (where the Cr channel precedes Yp),
        //    // so we permute to a kCVPixelFormatType_444YpCbCr8 by flipping the first two channels. Note that the vImagePermuteChannels_RGB888 permute function
        //    // specifies RGB but it doesn't matter since it's just flipping bytes.
        //
        //    uint8_t YpCb_permuteMap[] = {1, 2, 0 };
        //
        //    vImagePermuteChannels_RGB888(&dest, &dest, YpCb_permuteMap, flags);
        
        planes[0] = dest
        planeCount = 1
        
        return err
    }
    
    // Convert to kCVPixelFormatType_422YpCbCr8
    func RGBA32toInterleaved422YpCbCr(sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var err = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange = pixelRangeVideoClamped
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage422CbYpCrYp8, flags)
        
        var dest = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 2), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 2)
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2] // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To422CbYpCrYp8(&sourceBuffer, &dest, &outInfo, permuteMap, flags)
        
        planes[0] = dest
        planeCount = 1
        
        return err
    }
    
    // Convert to kCVPixelFormatType_4444YpCbCrA8
    func RGBA32toInterleaved444YpCbCrA8(sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var err = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange = pixelRangeVideoClamped
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage444CbYpCrA8, flags);
        
        var dest = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 4), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 4)
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2]  // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To444CbYpCrA8(&sourceBuffer, &dest, &outInfo, permuteMap, flags);
        
        planes[0] = dest;
        planeCount = 1;
        
        return err
    }
    
    // Convert to kCVPixelFormatType_4444AYpCbCr8
    func RGBA32toInterleaved444AYpCbCr8(sourceBuffer : inout vImage_Buffer, pixelFormat : OSType) -> Int
    {
        var err = kvImageNoError
        let flags = vImage_Flags(kvImageNoFlags)
        var pixelRange : vImage_YpCbCrPixelRange = pixelRangeVideoClamped
        var outInfo : vImage_ARGBToYpCbCr = vImage_ARGBToYpCbCr()
        
        err = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &pixelRange, &outInfo, kvImageARGB8888, kvImage444AYpCbCr8, flags);
        
        var dest = vImage_Buffer(data: malloc(Int(sourceBuffer.width * sourceBuffer.height) * 4), height: sourceBuffer.height, width: sourceBuffer.width, rowBytes: Int(sourceBuffer.width) * 4)
        
        let permuteMap: [UInt8] = [ 3, 0, 1, 2] // The conversion func expects ARGB so we this tells it to expect RGBA which is our one and only source format:
        vImageConvert_ARGB8888To444AYpCbCr8(&sourceBuffer, &dest, &outInfo, permuteMap, flags);
        
        planeCount = 1;
        planes[0] = dest;
        
        return err
    }
    
}
