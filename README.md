#  EEMetalPixelViewer

This is a set of Swift classes for iOS that are used for *efficient presentation of pixel buffers on the screen*, using Metal. This includes support for a myriad of pixel formats, including both planar and packed image data, as well as support for efficiently presenting Core Video `CVImageBuffer` images.

The base class, `EETextureViewer`, is a `UIView`, deriving from MTKView, which makes it super easy to get going and requires absolutely no dealing with Metal, writing shaders, etc. 

## Key Features

* Easy to use, `MTKView`-based UIView object
* Flexible support for a massive set of pixel formats, including both RGB and YUV, as well as planar and packed formats
* Support for the `UIView` `UIContentMode` settings for easy control of scaling and positioining of your pixel data within the `UIView`
* Support for `CVImageBuffer` images as an input, for working with video, camera sources, etc.
* Optimized implementation with little to no CPU usage, no copied buffers, etc. All format conversions and such are done in the GPU.

## Supported Pixel Formats

| Pixel Format | Supported    | BPP | Planes |
| :----------- |:------------:|:---:|:------:|
| kCVPixelFormatType_420YpCbCr8Planar|✅|16|3|
| kCVPixelFormatType_420YpCbCr8PlanarFullRange|✅|16|3|
| kCVPixelFormatType_422YpCbCr8|✅|16|1|
| kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange|✅|16|2|
| kCVPixelFormatType_420YpCbCr8BiPlanarFullRange|✅|16|2|
| kCVPixelFormatType_444YpCbCr8|✅|24|1|
| kCVPixelFormatType_4444YpCbCrA8|✅|32|1|
| kCVPixelFormatType_4444AYpCbCr8|✅|32|1|
| kCVPixelFormatType_24RGB|✅|24|1|
| kCVPixelFormatType_24BGR|✅|24|1|
| kCVPixelFormatType_32ARGB|✅|32|1|
| kCVPixelFormatType_32BGRA|✅|32|1|
| kCVPixelFormatType_32ABGR|✅|32|1|
| kCVPixelFormatType_32RGBA|✅|32|1|
| kCVPixelFormatType_16LE555|✅|16|1|
| kCVPixelFormatType_16LE5551|✅|16|1|
| kCVPixelFormatType_16LE565|✅|16|1|
