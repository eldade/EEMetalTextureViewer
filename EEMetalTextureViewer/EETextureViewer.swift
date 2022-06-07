//
//  MTPixelViewer.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 9/21/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

import UIKit
import MetalKit
import MetalPerformanceShaders

public class EETextureViewer: MTKView {
    
//    #if DEBUG
    
        fileprivate  let pixelFormatNames : [Int : String] = [
            24 : "24RGB",
            842285639 : "24BGR",
            32: "32ARGB",
            1111970369 : "32BGRA",
            1094862674 : "32ABGR",
            1380401729 : "32RGBA",
            1983131704 : "4444YpCbCrA8",
            2033463352 : "4444AYpCbCr8",
            1983066168 : "444YpCbCr8",
            2033463856 : "420YpCbCr8Planar",
            1278555445 : "16LE555",
            892679473 : "16LE5551",
            1278555701 : "16LE565",
            875704438 :"420YpCbCr8BiPlanarVideoRange",
            875704422 : "420YpCbCr8BiPlanarFullRange",
            846624121 : "422YpCbCr8",
            1714696752 : "420YpCbCr8PlanarFullRange",
            ]
        fileprivate let statsView = UITextView(frame: CGRect())
    
        fileprivate let strokeTextAttributes = [
            convertFromNSAttributedStringKey(NSAttributedString.Key.strokeColor) : UIColor.black,
            convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor) : UIColor.white,
            convertFromNSAttributedStringKey(NSAttributedString.Key.strokeWidth) : -3.0,
            convertFromNSAttributedStringKey(NSAttributedString.Key.font) : UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
            ] as [String : Any]
    
        fileprivate let framesPerStatusUpdate = 30
        fileprivate var framesSinceLastUpdate = 0
    
        var fpsCounterLastTimestamp = Date.init()
    
    var lastBufferUnaligned : Bool = false
//    #endif

    private var commandQueue: MTLCommandQueue! = nil
    private var library: MTLLibrary! = nil
    private var pipelineDescriptor = MTLRenderPipelineDescriptor()
    private var pipelineState : MTLRenderPipelineState! = nil
    private var vertexBuffer : MTLBuffer! = nil
    private var texCoordBuffer : MTLBuffer! = nil

    internal var textures = [MTLTexture?](repeating: nil, count: 3)
    
    internal let lockQueue = DispatchQueue(label:"pixelViewerQueue")
    
    internal let lock : NSLock! = NSLock.init()
    private var lockedState : Bool = false
    
    private var permuteTableBuffer : MTLBuffer! = nil
    
    internal var planeCount : Int? = nil
    
    private var intermediateTexture : MTLTexture? = nil
    
    var YpCbCrMatrix_Full = matrix_float4x4(columns: (vector_float4(1.0,  0.0,  1.402, 0.0),
                                                      vector_float4(1.0,  -0.34414, -0.71414, 0.0),
                                                      vector_float4(1.0,  1.772,  0.0, 0.0),
                                                      vector_float4(0.0, 0.0, 0.0, 1.0)))
    
    
    var YpCbCrMatrix_Video = matrix_float4x4(columns: (vector_float4(1.1643,  0.0,  1.5958, 0.0),
                                                       vector_float4(1.1643,  -0.39173, -0.81290, 0.0),
                                                       vector_float4(1.1643,  2.017,  0.0, 0.0),
                                                       vector_float4(0.0, 0.0, 0.0, 1.0)))
    
    var YpCbCrOffsets_FullRange = float4([0.0, 0.5, 0.5, 0.0])
    var YpCbCrOffsets_VideoRange = float4([0.0625, 0.5, 0.5, 0.0])
    
    var YpCbCrMatrixFullRangeBuffer : MTLBuffer! = nil
    var YpCbCrMatrixVideoRangeBuffer : MTLBuffer! = nil
    
    var YpCbCrOffsets_FullRangeBuffer : MTLBuffer! = nil
    var YpCbCrOffsets_VideoRangeBuffer : MTLBuffer! = nil
    
    var activeColorTransformMatrixBuffer : MTLBuffer! = nil
    var activeYpCbCrOffsetsBuffer : MTLBuffer! = nil
    
    var blur : MPSImageGaussianBlur? = nil
    var edgeDetector : MPSImageSobel? = nil
    
    override init(frame frameRect: CGRect, device: MTLDevice?)
    {
        super.init(frame: frameRect, device: device)
        configureWithDevice(device!)
    }
    
    required init(coder: NSCoder)
    {
        super.init(coder: coder)
        configureWithDevice(MTLCreateSystemDefaultDevice()!)
    }
    
    private func configureWithDevice(_ device : MTLDevice) {
        self.clearColor = MTLClearColor.init(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.framebufferOnly = false
        self.colorPixelFormat = .bgra8Unorm
        
        self.preferredFramesPerSecond = 0
        
        self.addSubview(statsView)
        statsView.backgroundColor = UIColor.clear
        statsView.textColor = UIColor.white
        
        self.device = device
    }
    
    func reset() {
        lockQueue.sync {
            sourceImageSize = nil
            textures = [MTLTexture?](repeating: nil, count: 3)
            pixelFormat = nil
            vertexBuffer = nil
            
            framesSinceLastUpdate = 0
        }
    }
    
    private func calculateAspectFitFillRect() -> CGRect?
    {
        if let imageSize = sourceImageSize {
            var scale: CGFloat
            var scaledRect: CGRect = CGRect()
            if (contentMode == .scaleAspectFit)
            {
                scale = min( drawableSize.width / imageSize.width, drawableSize.height / imageSize.height)
            }
            else
            {
                scale = max( drawableSize.width / imageSize.width, drawableSize.height / imageSize.height)
            }
            
            scaledRect.origin.x = (drawableSize.width - imageSize.width * scale) / 2;
            scaledRect.origin.y = (drawableSize.height - imageSize.height * scale) / 2;
            
            scaledRect.size.width = imageSize.width * scale;
            scaledRect.size.height = imageSize.height * scale;
            
            return scaledRect;
        }
        else {
            return nil
        }
    }
    
    private func calculateTextureRect() -> CGRect?
    {
        if let imageSize = sourceImageSize {
            switch (self.contentMode) {
            case .topLeft:
                return CGRect(x: 0,
                              y: 0,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .top:
                return CGRect(x: (1 - imageSize.width / self.drawableSize.width) / 2,
                              y: 0,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .topRight:
                return CGRect(x: 1 - imageSize.width / self.drawableSize.width,
                              y: 0,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .left:
                return CGRect(x: 0,
                              y: (1 - imageSize.height / self.drawableSize.height) / 2,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .center:
                return CGRect(x: (1 - imageSize.width / self.drawableSize.width) / 2,
                              y: (1 - imageSize.height / self.drawableSize.height) / 2,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .right:
                return CGRect(x: 1 - imageSize.width / self.drawableSize.width,
                              y: (1 - imageSize.height / self.drawableSize.height) / 2,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .bottomLeft:
                return CGRect(x: 0,
                              y: 1 - imageSize.height / self.drawableSize.height,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .bottom:
                return CGRect(x: (1 - imageSize.width / self.drawableSize.width) / 2,
                              y: 1 - imageSize.height / self.drawableSize.height,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .bottomRight:
                return CGRect(x: 1 - imageSize.width / self.drawableSize.width,
                              y: 1 - imageSize.height / self.drawableSize.height,
                              width: imageSize.width / self.drawableSize.width,
                              height: imageSize.height / self.drawableSize.height)
            case .scaleAspectFit, .scaleAspectFill:
                let fittedRect = calculateAspectFitFillRect()
                
                return CGRect(x: fittedRect!.origin.x / drawableSize.width,
                              y:fittedRect!.origin.y / drawableSize.height,
                              width: fittedRect!.size.width / drawableSize.width,
                              height:fittedRect!.size.height / drawableSize.height)
            case .scaleToFill:
                return CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
            default:
                print("EEPixelViewer ERROR: Unsupported contentMode: ", contentMode.rawValue)
                return CGRect()
            }
        }
        else {
            return nil
        }

    }
    
    private func calculateVertexesForRect(rect: CGRect) -> [Float] {
        var calculatedVertexes : [Float] = []
        let tempRect = CGRect(x: rect.origin.x * 2 - 1,
                              y: 1 - rect.origin.y * 2,
                              width: rect.size.width * 2,
                              height: rect.size.height * 2)
        
        
        let top = Float(tempRect.origin.y - tempRect.size.height)
        let left = Float(tempRect.origin.x)
        let right = Float(tempRect.origin.x + tempRect.size.width)
        let bottom = Float(tempRect.origin.y)
        
        // bottomLeft:
        calculatedVertexes.append(left)
        calculatedVertexes.append(bottom)
        calculatedVertexes.append(Float(0.0))
        calculatedVertexes.append(Float(1.0))
        
        // bottomRight:
        calculatedVertexes.append(right)
        calculatedVertexes.append(bottom)
        calculatedVertexes.append(Float(0.0))
        calculatedVertexes.append(Float(1.0))

        // topLeft:
        calculatedVertexes.append(left)
        calculatedVertexes.append(top)
        calculatedVertexes.append(Float(0.0))
        calculatedVertexes.append(Float(1.0))
        
        // topRight:
        calculatedVertexes.append(right)
        calculatedVertexes.append(top)
        calculatedVertexes.append(Float(0.0))
        calculatedVertexes.append(Float(1.0))

        return calculatedVertexes
    }
    
  public override func layoutSubviews() {
        super.layoutSubviews()
        setupVertexBuffer()
        statsView.frame = CGRect(x: 0, y: 0, width: self.bounds.size.width, height: 50)
        
        let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                               width: Int(self.drawableSize.width),
                                                               height: Int(self.drawableSize.height),
                                                               mipmapped: false)
        
        intermediateTexture = device.makeTexture(descriptor: texDesc)
    }
    
  public override var contentMode: UIView.ContentMode {
        didSet {
            if (contentMode != oldValue) {
                setupVertexBuffer()
            }
        }
    }
    
    private func setupVertexBuffer()
    {
        let textureRect = calculateTextureRect()
        
        if textureRect == nil {
            return
        }
        
        let vertexes = calculateVertexesForRect(rect: textureRect!)
        let vertexDataSize = vertexes.count * MemoryLayout.size(ofValue: vertexes[0])
        self.vertexBuffer = (self.device?.makeBuffer(bytes: vertexes,
                                                     length: vertexDataSize,
                                                     options: .storageModeShared))
    }
    
    public var sourceImageSize : CGSize? = nil {
        didSet {
            if (sourceImageSize != oldValue)
            {
                setupVertexBuffer()
                
                do {
                    try pipelineState = device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
                }
                catch {
                    
                }
            }
        }
    }
    
    func generatePermuteTableBuffer(permuteTable: [UInt8]) -> MTLBuffer
    {
        return device!.makeBuffer(bytes: permuteTable,
                                  length: permuteTable.count * MemoryLayout.size(ofValue:permuteTable),
                                  options: .storageModeShared)!
    }

  public override var device: MTLDevice! {
        didSet {
            super.device = device
            commandQueue = (self.device?.makeCommandQueue())!

            let frameworkBundle = Bundle(for: type(of: self))
            library = try? device?.makeDefaultLibrary(bundle: frameworkBundle)
            pipelineDescriptor.vertexFunction = library?.makeFunction(name: "vertex_passthrough")
            pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "basic_fragment")
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            
            YpCbCrMatrixFullRangeBuffer = device!.makeBuffer(bytes: &YpCbCrMatrix_Full,
                                                             length: MemoryLayout<matrix_float4x4>.size,
                                                             options: .storageModeShared)
            YpCbCrMatrixVideoRangeBuffer = device!.makeBuffer(bytes: &YpCbCrMatrix_Video,
                                                              length: MemoryLayout<matrix_float4x4>.size,
                                                              options: .storageModeShared)
            
            YpCbCrOffsets_FullRangeBuffer = device!.makeBuffer(bytes: &YpCbCrOffsets_FullRange,
                                                               length: MemoryLayout<float4>.size,
                                                               options: .storageModeShared)
            YpCbCrOffsets_VideoRangeBuffer = device!.makeBuffer(bytes: &YpCbCrOffsets_VideoRange,
                                                                length: MemoryLayout<float4>.size,
                                                                options: .storageModeShared)
            
            blur = MPSImageGaussianBlur.init(device: device, sigma: 50.0)
            edgeDetector = MPSImageSobel.init(device: device)
            
            let texDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                   width: Int(self.bounds.size.width),
                                                                   height: Int(self.bounds.size.height),
                                                                   mipmapped: false)
            
            intermediateTexture = device.makeTexture(descriptor: texDesc)
        }
    }
    
    public var pixelFormat : OSType? = nil {
        didSet {
            
            if (pixelFormat == nil || pixelFormat == oldValue) {
                return
            }
            
            pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "rgba_fragment")
            permuteTableBuffer = generatePermuteTableBuffer(permuteTable: [0, 1, 2, 3])
            
            switch (pixelFormat!) {
            case kCVPixelFormatType_420YpCbCr8Planar:           /* Planar Component Y'CbCr 8-bit 4:2:0. */
                activeColorTransformMatrixBuffer = YpCbCrMatrixVideoRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_VideoRangeBuffer
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "YpCbCr_3P_fragment")
                planeCount = 3
            case kCVPixelFormatType_420YpCbCr8PlanarFullRange:  /* Planar Component Y'CbCr 8-bit 4:2:0, full range.*/
                activeColorTransformMatrixBuffer = YpCbCrMatrixFullRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_FullRangeBuffer
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "YpCbCr_3P_fragment")
                planeCount = 3
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:   /*  Bi-Planar Component Y'CbCr 8-bit 4:2:0, video-range */
                activeColorTransformMatrixBuffer = YpCbCrMatrixVideoRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_VideoRangeBuffer
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "YpCbCr_2P_fragment")
                planeCount = 2;
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:    /* Bi-Planar Component Y'CbCr 8-bit 4:2:0, full-range */
                activeColorTransformMatrixBuffer = YpCbCrMatrixFullRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_FullRangeBuffer
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "YpCbCr_2P_fragment")
                planeCount = 2;
            case kCVPixelFormatType_4444YpCbCrA8:   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered Cb Y' Cr A */
                activeColorTransformMatrixBuffer = YpCbCrMatrixFullRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_FullRangeBuffer
                planeCount = 1;
            case kCVPixelFormatType_4444AYpCbCr8:   /* Component Y'CbCrA 8-bit 4:4:4:4, ordered A Y' Cb Cr, full range alpha, video range Y'CbCr. */
                activeColorTransformMatrixBuffer = YpCbCrMatrixVideoRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_VideoRangeBuffer
                planeCount = 1;
            case kCVPixelFormatType_422YpCbCr8:   /* Component Y'CbCr 8-bit 4:2:2, ordered Cb Y'0 Cr Y'1 */
                activeColorTransformMatrixBuffer = YpCbCrMatrixVideoRangeBuffer
                activeYpCbCrOffsetsBuffer = YpCbCrOffsets_VideoRangeBuffer
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "YpCbCr_1P_fragment")
                planeCount = 1;
            case kCVPixelFormatType_32ARGB:     /* 32 bit ARGB */
                planeCount = 1;
                permuteTableBuffer = generatePermuteTableBuffer(permuteTable: [3, 2, 1, 0])
            case kCVPixelFormatType_32BGRA:     /* 32 bit BGRA */
                planeCount = 1;
                permuteTableBuffer = generatePermuteTableBuffer(permuteTable: [2, 1, 0, 3])
            case kCVPixelFormatType_32ABGR:     /* 32 bit ABGR */
                planeCount = 1;
                permuteTableBuffer = generatePermuteTableBuffer(permuteTable: [3, 2, 1, 0])
            case kCVPixelFormatType_24BGR, kCVPixelFormatType_24RGB:
                pipelineDescriptor.fragmentFunction = library?.makeFunction(name: "rgb24_fragment")
                planeCount = 1;
                permuteTableBuffer = generatePermuteTableBuffer(permuteTable: [3, 2, 1, 0])
            case kCVPixelFormatType_32RGBA:     /* 32 bit RGBA */
                planeCount = 1;
            case kCVPixelFormatType_16LE555:      /* 16 bit BE RGB 555 */
                planeCount = 1;
            case kCVPixelFormatType_16LE5551:     /* 16 bit LE RGB 5551 */
                planeCount = 1;
            case kCVPixelFormatType_16LE565:      /* 16 bit BE RGB 565 */
                planeCount = 1;
            default:
                print ("EEPixelViewer.setPlaneDescriptors(): Unsupported pixel format " + String(pixelFormat!))
                return
            }
            
            do {
                try pipelineState = device?.makeRenderPipelineState(descriptor: pipelineDescriptor)
            }
            catch {
                
            }
        }
    }

  public override func draw(_ rect: CGRect) {
        
        let commandBuffer = commandQueue!.makeCommandBuffer()
        
//        var renderPassDescriptor = MTLRenderPassDescriptor.init()
//        
//        renderPassDescriptor.colorAttachments[0].loadAction = .clear
//                renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 1, alpha: 1)
//        
//        renderPassDescriptor.colorAttachments[0].texture = intermediateTexture

        let renderPassDescriptor = self.currentRenderPassDescriptor!

        
//        let renderPassDescriptor = self.currentRenderPassDescriptor
        
//        if (renderPassDescriptor == nil) {
//            return
//        }
        
//        print ("current render target=\(renderPassDescriptor?.colorAttachments[0].texture.debugDescription)")
        
        if (textures[0] == nil || vertexBuffer == nil || sourceImageSize == nil) {
            print ("EEPixelViewer.draw() ERROR: Texture or vertex buffer haven't been generated. Please ensure" +
                " .sourceImageSize, .pixelFormat and .planeDescriptors are set with valid parameters.")
            return
        }
        
        DispatchQueue.main.async {
//        lockQueue.sync {
//            // We have to wait for the previous drawing call to complete:
//            DispatchQueue.main.async {
                self.framesSinceLastUpdate += 1
                if self.framesSinceLastUpdate >= self.framesPerStatusUpdate {
                    let timeElapsed = -self.fpsCounterLastTimestamp.timeIntervalSinceNow
                    let outputString = "FPS=\(lround(1/timeElapsed) * self.framesPerStatusUpdate)," +
                        "\(Int(self.sourceImageSize!.width))x\(Int(self.sourceImageSize!.height)), " +
                        "\(self.pixelFormatNames[Int(self.pixelFormat!)]!)" +
                        (self.lastBufferUnaligned ? ", UNALIGNED" : "")
                    
                    self.statsView.attributedText = NSAttributedString(string: outputString,
                                                                       attributes: convertToOptionalNSAttributedStringKeyDictionary(self.strokeTextAttributes))
                    
                    self.fpsCounterLastTimestamp = Date.init()
                    
                    self.framesSinceLastUpdate = 0
                }
            }
//        }
        
        if let renderEncoder = commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
            
            for plane in 0..<planeCount! {
                renderEncoder.setFragmentTexture(textures[plane], index: plane)
            }
            
            if (permuteTableBuffer != nil) {
                renderEncoder.setFragmentBuffer(permuteTableBuffer, offset: 0, index: 0)
            }
            
            if (activeColorTransformMatrixBuffer != nil) {
                renderEncoder.setFragmentBuffer(activeColorTransformMatrixBuffer, offset: 0, index: 1)
            }
            
            if (activeYpCbCrOffsetsBuffer != nil) {
                renderEncoder.setFragmentBuffer(activeYpCbCrOffsetsBuffer, offset: 0, index: 2)
            }
            
            renderEncoder.setRenderPipelineState(pipelineState)
            
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            
            renderEncoder.endEncoding()
        }
        
//        blur?.encode(commandBuffer: commandBuffer, sourceTexture: intermediateTexture!, destinationTexture: renderPassDescriptor.colorAttachments[0].texture!)
        //edgeDetector?.encode(commandBuffer: commandBuffer, sourceTexture: intermediateTexture!, destinationTexture: self.currentDrawable!.texture)

        commandBuffer!.present(self.currentDrawable!)
        commandBuffer!.commit()
        
//        lockQueue.async {
//            self.lock.lock()
//            let start = Date()
//            commandBuffer.commit()
//            commandBuffer.waitUntilCompleted()
//            let end = Date()
//            
//            let interval = end.timeIntervalSince(start)
////            print ("Frame time = \(interval)")
//            self.lock.unlock()
//        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}
