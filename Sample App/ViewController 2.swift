//
//  ViewController.swift
//  eldade_metal_tests
//
//  Created by Eldad Eilam on 9/21/16.
//  Copyright © 2016 Eldad Eilam. All rights reserved.
//

//import UIKit
import Metal
import MetalKit
import Accelerate

protocol PixelSource {
    var pixelFormat : OSType { get set }
    var supportedImages : [String] { get }
    var supportedPixelFormats : [String : OSType] { get }
    var supportedPixelFormatNames : [String] { get }
    var currentImage : String { get set }
    var delegate : PixelSourceDelegate! { get set }
    
    func startStreaming()
    func stopStreaming()
}

protocol PixelSourceDelegate {
    var imageSize : CGSize { set get }
    var planeDescriptors : [PVPlaneDescriptor] { get set }
    func render()
    func renderCVImageBuffer(_ imageBuffer: CVImageBuffer)
}


class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, PixelSourceDelegate {

    internal var imageSize: CGSize = CGSize() {
        didSet {
            metalView!.sourceImageSize = imageSize
        }
    }

    
    
    var cameraPixelSource : CameraSource! = nil
    var stillImagePixelSource : StillImageSource! = nil
    var activePixelSource : PixelSource! = nil
    
    var contentModesDict : [String : Int] = [:]
    
    var contentModes : [String] {
        let allKeys = contentModesDict.keys
        let contentModesSortedList : [String] = allKeys.sorted {
            $0 < $1
        }
        
        return contentModesSortedList
    }
        
    @IBOutlet var pickerView : UIPickerView! = nil
    
    var metalView : EECVImageBufferViewer? = nil
    
    let pickerComponent1Items = [ "Camera Feed", "Still Images" ]
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let pixelFormatDescriptionsArray =
            CVPixelFormatDescriptionArrayCreateWithAllPixelFormatTypes(kCFAllocatorDefault)
        
        let test = pixelFormatDescriptionsArray as! [Any]

        
        if let info = CVPixelFormatInfo(kCVPixelFormatType_24BGR) {
            info.cgBitmapContextCompatible
            let count = info.planeCount
            let range = info.componentRange
        }
        
        if let info = CVPixelFormatInfo(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange) {
            info.cgBitmapContextCompatible
            let count = info.planeCount
            let range = info.componentRange
            let cgImage = info.cgImageCompatible
            let cgBitmapContext = info.cgBitmapContextCompatible
            let openGL = info.openGLCompatible
            let openGLES = info.openGLESCompatible
            let metal = info.metalCompatible
        }
        
        if let info = CVPixelFormatInfo(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            let count = info.planeCount
            let range = info.componentRange
        }
        
        if let info = CVPixelFormatInfo(kCVPixelFormatType_30RGBLEPackedWideGamut) {
            let count = info.planeCount
            let range = info.componentRange
        }



        // Do any additional setup after loading the view, typically from a nib.

        
//            {
//                CFArrayRef pixelFormatDescriptionsArray = NULL;
//                CFIndex i;
        
        
        
//        for currentFormat in pixelFormatDescriptionsArray {
//            let formatDescription = CVPixelFormatDescriptionCreateWithPixelFormatType(kCFAllocatorDefault, currentFormat)
//            print(formatDescription.debugDescription)
//        }
        
//                printf("Core Video Supported Pixel Format Types:\n\n");
//                
//                for (i = 0; i < CFArrayGetCount(pixelFormatDescriptionsArray); i++) {
//                    CFStringRef pixelFormat = NULL;
//                    
//                    CFNumberRef pixelFormatFourCC = (CFNumberRef)CFArrayGetValueAtIndex(pixelFormatDescriptionsArray, i);
//                    
//                    if (pixelFormatFourCC != NULL) {
//                        UInt32 value;
//                        
//                        CFNumberGetValue(pixelFormatFourCC, kCFNumberSInt32Type, &value);
//                        
//                        if (value <= 0x28) {
//                            pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
//                                                                   CFSTR("Core Video Pixel Format Type: %d\n"), value);
//                        } else {
//                            pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
//                                                                   CFSTR("Core Video Pixel Format Type (FourCC):
//                                                                    %c%c%c%c\n"), (char)(value >> 24), (char)(value >> 16),
//                                                                    (char)(value >> 8), (char)value);
//                        }
//                        
//                        CFShow(pixelFormat);
//                        CFRelease(pixelFormat);
//                    }
//                }
//        }

        
        
        
        let plistPath = Bundle.main.path(forResource: "ContentModes", ofType: "plist")
        contentModesDict = NSDictionary.init(contentsOfFile: plistPath!) as! [String : Int]
        
        let image = UIImage.init(named: "iPad Screen.png")!
        
        metalView = self.view as! EECVImageBufferViewer!
        
        metalView!.device = MTLCreateSystemDefaultDevice()
//        metalView.depthStencilPixelFormat = .MTLPixelFormatInvalid
                
        pickerView.delegate = self
        pickerView.dataSource = self
        pickerView.showsSelectionIndicator = true
        
        metalView!.sourceImageSize = image.size
        
        metalView!.contentMode = .left
        
        stillImagePixelSource = StillImageSource.init()
        stillImagePixelSource.delegate = self
        
        cameraPixelSource = CameraSource.init()
        cameraPixelSource.delegate = self
        activePixelSource = cameraPixelSource
        
        activePixelSource.pixelFormat = kCVPixelFormatType_32BGRA
        metalView!.pixelFormat = kCVPixelFormatType_32BGRA
        
        activePixelSource.startStreaming()
        
//        let textureLoader = MTKTextureLoader.init(device: metalView.device!)
//        
//        do {
//            let texture = try textureLoader.newTexture(with: image!, options: nil)
//        }
//        catch {
//            
//        }
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let strokeTextAttributes = [
            NSStrokeColorAttributeName : UIColor.black,
            NSForegroundColorAttributeName : UIColor.white,
            NSStrokeWidthAttributeName : -3.0,
            NSFontAttributeName : UIFont.systemFont(ofSize: 20, weight: UIFontWeightBold)
            ] as [String : Any]
        
        var outputString : String
        
        switch (component) {
        case 0:
            outputString = pickerComponent1Items[row]
        case 1:
            outputString = activePixelSource.supportedImages[row]
        case 2:
            outputString = contentModes[row]
        case 3:
            outputString = activePixelSource.supportedPixelFormatNames[row]
        default:
            return view!
        }
        
        let attributedString = NSAttributedString(string: outputString, attributes: strokeTextAttributes)
        
        var newView = view as! UILabel?
        
        if newView == nil {
            newView = UILabel.init()
            newView!.lineBreakMode = .byTruncatingHead
            newView!.font = UIFont.systemFont(ofSize: 22, weight: UIFontWeightThin)
            newView!.textAlignment = .center
        }
        
        newView!.attributedText = attributedString
        
        return newView!
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let strokeTextAttributes = [
            NSStrokeColorAttributeName : UIColor.black,
            NSForegroundColorAttributeName : UIColor.white,
            NSStrokeWidthAttributeName : -3.0,
            NSFontAttributeName : UIFont.systemFont(ofSize: 14, weight: UIFontWeightLight)
            ] as [String : Any]
        
        var outputString : String
        
        switch (component) {
        case 0:
            outputString = pickerComponent1Items[row]
        case 1:
            outputString = activePixelSource.supportedImages[row]
        case 2:
            outputString = contentModes[row]
        case 3:
            outputString = activePixelSource.supportedPixelFormatNames[row]
        default:
            return nil
        }
        
        return NSAttributedString(string: outputString, attributes: strokeTextAttributes)
    }
    
    func pickerView(_ pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
        return pickerView.frame.size.width / 4.0
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            activePixelSource.stopStreaming()
            metalView!.reset()
            switch row {
            case 0:
                activePixelSource = cameraPixelSource
            case 1:
                activePixelSource = stillImagePixelSource
            default:
                break
            }
            pickerView.reloadAllComponents()
            let newContentMode = contentModesDict[contentModes[pickerView.selectedRow(inComponent: 2)]]
            metalView!.contentMode = UIViewContentMode(rawValue: newContentMode!)!
            
            let pixelFormat = activePixelSource.supportedPixelFormats[activePixelSource.supportedPixelFormatNames[pickerView.selectedRow(inComponent: 3)]]
            metalView?.pixelFormat = pixelFormat!
            activePixelSource.pixelFormat = pixelFormat!
            activePixelSource.currentImage = activePixelSource.supportedImages[pickerView.selectedRow(inComponent: 1)]

            activePixelSource.startStreaming()
        case 1:
            
            activePixelSource.stopStreaming()
            metalView!.reset()
            let newContentMode = contentModesDict[contentModes[pickerView.selectedRow(inComponent: 2)]]
            metalView!.contentMode = UIViewContentMode(rawValue: newContentMode!)!
            
            var pixelFormat = activePixelSource.supportedPixelFormats[activePixelSource.supportedPixelFormatNames[pickerView.selectedRow(inComponent: 3)]]
            metalView?.pixelFormat = pixelFormat!
            activePixelSource.currentImage = activePixelSource.supportedImages[row]
            
            activePixelSource.startStreaming()
            
        case 2:
            let newContentMode = contentModesDict[contentModes[row]]
            metalView?.contentMode = UIViewContentMode(rawValue: newContentMode!)!
        case 3:
            var pixelFormat = activePixelSource.supportedPixelFormats[activePixelSource.supportedPixelFormatNames[row]]
            activePixelSource.stopStreaming()
            metalView?.pixelFormat = pixelFormat!
            activePixelSource.pixelFormat = pixelFormat!
            activePixelSource.startStreaming()
        default:
            return
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch (component) {
        case 0:
            return pickerComponent1Items.count
        case 1:
            return activePixelSource.supportedImages.count
        case 2:
            return contentModes.count
        case 3:
            return activePixelSource.supportedPixelFormatNames.count
        default:
            return 0
            
        }
    }
    
    internal func render() {
        metalView?.draw()
    }
    
        internal var planeDescriptors: [PVPlaneDescriptor] = [] {
        didSet {
    //        metalView?.planeDescriptors = planeDescriptors
        }
     }
    
    func renderCVImageBuffer(_ imageBuffer: CVImageBuffer) {
        metalView?.presetCVImageBuffer(imageBuffer: imageBuffer)
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 4
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

