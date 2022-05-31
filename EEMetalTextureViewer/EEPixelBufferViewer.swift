//
//  EEPixelBufferViewer.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 10/26/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

import UIKit
import Foundation
import Metal
import CoreGraphics

struct PVPlaneDescriptor {
    var data : UnsafeMutableRawPointer
    var size : CGSize
    var rowBytes : Int
    
    static func ==(lhs: PVPlaneDescriptor, rhs: PVPlaneDescriptor) -> Bool {
        var sizesEqual = false
        
        if (lhs.size.width == rhs.size.width && lhs.size.height == rhs.size.height) {
            sizesEqual = true
        } else {
            sizesEqual = false
        }
        if lhs.data == rhs.data &&
            sizesEqual &&
            lhs.rowBytes == rhs.rowBytes {
            return true
        }
        else {
            return false
        }
    }
}

private struct PVInternalPlaneParameters {
    var planeDescriptor : PVPlaneDescriptor
    var metalPixelFormat : MTLPixelFormat
}

public class EEPixelBufferViewer : EETextureViewer {
    //    private var planeCount : Int = 0
    
    private var planeParameters : [PVInternalPlaneParameters] = []
    
    var planeDescriptors : [PVPlaneDescriptor] = [] {
        didSet {
            
            if planeDescriptors.count == 0 {
                return
            }
            
            if sourceImageSize == nil || pixelFormat == nil {
                print ("EEPixelViewer ERROR: Cannot set planeDescriptors. pixelFormat and sourceImageSize must initialized first.")
                return
            }
            
            lockQueue.sync {
                
                planeParameters = []
                
                switch (pixelFormat!) {
                case kCVPixelFormatType_420YpCbCr8Planar:           /* Planar Component Y'CbCr 8-bit 4:2:0. */
                    planeCount = 3
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[1], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[2], metalPixelFormat: .r8Unorm))
                    
                case kCVPixelFormatType_420YpCbCr8PlanarFullRange:  /* Planar Component Y'CbCr 8-bit 4:2:0, full range.*/
                    planeCount = 3
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[1], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[2], metalPixelFormat: .r8Unorm))
                    
                case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:    /* Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[1], metalPixelFormat: .rg8Unorm))
                    planeCount = 2;
                case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:   /*  Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .r8Unorm))
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[1], metalPixelFormat: .rg8Unorm))
                    planeCount = 2;
                case kCVPixelFormatType_4444YpCbCrA8,   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered Cb Y' Cr A */
                kCVPixelFormatType_4444AYpCbCr8:   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered A Y' Cb Cr, full range alpha, video range Y'CbCr. */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .rgba8Unorm))
                    planeCount = 1;
                case kCVPixelFormatType_422YpCbCr8:   /* Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1 */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .bgrg422))
                    planeCount = 1;
                case kCVPixelFormatType_32ARGB,     /* 32 bit ARGB */
                kCVPixelFormatType_32BGRA,     /* 32 bit BGRA */
                kCVPixelFormatType_32ABGR,     /* 32 bit ABGR */
                kCVPixelFormatType_32RGBA:     /* 32 bit RGBA */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .rgba8Unorm))
                    planeCount = 1;
                case kCVPixelFormatType_24RGB,      /* 24 bit RGB */
                kCVPixelFormatType_24BGR:   /* 24 bit BGR */
                    var newDescriptor = planeDescriptors[0]
                    newDescriptor.size.width *= 3
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: newDescriptor, metalPixelFormat: .r8Unorm))
                    planeCount = 1;
                    //                     Convert here!
                    
                case kCVPixelFormatType_16LE555:      /* 16 bit BE RGB 555 */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .a1bgr5Unorm))
                    planeCount = 1;
                case kCVPixelFormatType_16LE5551:     /* 16 bit LE RGB 5551 */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .a1bgr5Unorm))
                    planeCount = 1;
                case kCVPixelFormatType_16LE565:      /* 16 bit BE RGB 565 */
                    planeParameters.append(PVInternalPlaneParameters(planeDescriptor: planeDescriptors[0], metalPixelFormat: .b5g6r5Unorm))
                    planeCount = 1;
                default:
                    print ("EEPixelViewer.setPlaneDescriptors(): Unsupported pixel format " + String(pixelFormat!))
                    return
                }
                
                //
                
                assert(planeDescriptors.count == planeCount, "EEPixelViewer.setPlaneDescriptors(): Mismatched plane count. Expected " + String(planeCount!) + " got " + String(planeDescriptors.count))
                
                var tempString : String = ""
                for (planeIndex, plane) in planeParameters.enumerated() {
                    if  textures[planeIndex] != nil &&
                        compareTextureObjectWithPlaneDescriptor(texture: textures[planeIndex], planeDescriptor: plane.planeDescriptor) == true {

                        }
                    else {
                        textures[planeIndex] = makeTextureFromPlaneDescriptor(plane)
                    }
                    //                    }
                    //                    let tempPtr : UnsafeMutablePointer<Int> = UnsafeMutablePointer<Int>(bitPattern:Int(bitPattern:plane.planeDescriptor.data))!
                    //
                    //
                    //
                    //                    tempString += "Plane \(planeIndex) = " + String(format: "%x, ", tempPtr[0])
                }
                print (tempString)
            }
        }
    }
    
    func compareTextureObjectWithPlaneDescriptor(texture : MTLTexture!, planeDescriptor : PVPlaneDescriptor) -> Bool {
        //        if lastBufferUnaligned == false &&
        //            oldValue.count == planeParameters.count &&
        //            oldValue[planeIndex] == plane.planeDescriptor &&
        if let buffer = texture.buffer {
            
            if texture.width != Int(planeDescriptor.size.width) ||
                texture.height != Int(planeDescriptor.size.height) {
                return false
            }
            
            let calculatedBufferAddress = (Int(bitPattern: buffer.contents()) + texture.bufferOffset) >> 14
            
            let lastBufferAddress = (Int(bitPattern: planeDescriptor.data) >> 14)
            
            print (String(format: "texture uses address %x, descriptor has %x %@",
                          calculatedBufferAddress,
                          Int(bitPattern: planeDescriptor.data),
                          calculatedBufferAddress == Int(bitPattern: planeDescriptor.data) ? "" : "MISMATCH"))
            
            
            
            print (String(format: "address1 %x, address2 %x",
                          calculatedBufferAddress,
                          lastBufferAddress))

            
            if (calculatedBufferAddress == lastBufferAddress) {
                return true
            }
        }
            
        else {
            // If it's not a buffer-backed texture, there's no point as we need to create a new texture anyways:
            return false
        }
        
        return false
    }
    
    fileprivate func makeTextureFromPlaneDescriptor(_ plane : PVInternalPlaneParameters) -> MTLTexture
    {
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: plane.metalPixelFormat,
                                                               width: Int(plane.planeDescriptor.size.width),
                                                               height: Int(plane.planeDescriptor.size.height),
                                                               mipmapped: false)
        
        let bufferLength = UInt(plane.planeDescriptor.size.height) * UInt(plane.planeDescriptor.rowBytes)
        
        // There are three distinct cases for loading textures from memory buffers:
        
        // For page aligned buffers that use supported, non-compressed pixel formats, we can setup a shared memory buffer and
        // Metal will just read straight from the user buffer, which provides ideal performance.
        
        // For non page-aligned buffers, we can still use a buffer object, but we must use makeBuffer(bytes: ...) to copy the
        // memory to the buffer -- shared memory isn't supported. CPU usage is far greater because memory must be copied.
        
        // Lastly, for completely unaligned buffers or for compressed pixel formats, we cannot use buffer-backed textures
        // and must use MTLTexture.replace() to load pixels into the texture.
        
        var texture : MTLTexture? = nil
        
        switch plane.metalPixelFormat {
        case .gbgr422:
            break
        default:
            texture = device!.makeTextureFromUnalignedBuffer(textureDescriptor: texDesc,
                                                             bufferPtr: plane.planeDescriptor.data,
                                                             bufferLength: bufferLength,
                                                             bytesPerRow: plane.planeDescriptor.rowBytes)
        }
        
        if texture != nil {
            lastBufferUnaligned = false
            return texture!
        } else {
            // This is either a compressed texture format, or rowBytes are unaligned, so we must create a texture object
            // and copy pixels to it without using a buffer. This is a far less efficient approach.
            texture = device.makeTexture(descriptor: texDesc)
            
            let region = MTLRegionMake2D(0, 0, Int(plane.planeDescriptor.size.width), Int(plane.planeDescriptor.size.height))
            texture!.replace(region: region, mipmapLevel: 0, withBytes: plane.planeDescriptor.data, bytesPerRow: plane.planeDescriptor.rowBytes)
            
            if lastBufferUnaligned == false {
                print ("WARNING: Unaligned buffer -- pixel buffer must be copied for each frame.")
                lastBufferUnaligned = true
            }
            
            return texture!
        }
    }
}


extension MTLDevice {
    func makeTextureFromUnalignedBuffer(textureDescriptor : MTLTextureDescriptor,
                                        bufferPtr : UnsafeMutableRawPointer,
                                        bufferLength : UInt,
                                        bytesPerRow : Int) -> MTLTexture? {
        
        var calculatedBufferLength = bufferLength
        let pageSize = UInt(getpagesize())
        let pageSizeBitmask = UInt(getpagesize()) - 1
        
        let alignedBufferAddr = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: bufferPtr) & ~pageSizeBitmask)
        let offset = UInt(0)//UInt(bitPattern: bufferPtr) & pageSizeBitmask
        
        //        assert(bytesPerRow % 64 == 0 && offset % 64 == 0, "Supplied bufferPtr and bytesPerRow must be aligned on a 64-byte boundary!")
        
        if bytesPerRow % 64 != 0 ||
            offset % 64 != 0 {
            return nil
        }
        
        // Essentially this function can enlarge the buffer provided to Metal so that it spans one or more full page.
        // This means that the pointer will be moved back (so that it points at the beginning of the page), and the
        // length will be increased to span the entire page. We feed makeTexture an offset parameter telling it to
        // start reading the pixels from that offset (which is the distance from the start of the page to where the
        // first pixel actually resides).
        calculatedBufferLength += offset
        
        if (calculatedBufferLength & pageSizeBitmask) != 0 {
            // WARNING: I BELIEVE this is safe to do. Metal wants a fully page aligned buffer length consisting of a
            // page aligned pointer and a page-aligned length. If the length is not page aligned, I round it up to the
            // next page size here. I figure it would't actually read those extra bytes. Then again why is this
            // requirement there in the first place?
            calculatedBufferLength &= ~(pageSize - 1)
            calculatedBufferLength += pageSize
        }
        
        if let buffer = self.makeBuffer(bytesNoCopy: alignedBufferAddr!,
                                     length: Int(calculatedBufferLength),
                                     options: .storageModeShared, deallocator: nil) {
            return buffer.makeTexture(descriptor: textureDescriptor, offset: Int(offset), bytesPerRow: bytesPerRow)
        }
        else {
            return nil
        }
    }
}
