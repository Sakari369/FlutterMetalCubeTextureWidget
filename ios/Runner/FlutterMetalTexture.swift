// Copyright (c) 2023 Sumo Apps.

import Foundation
import CoreVideo
import Metal
import Flutter

// Metal texture that extends FlutterTexture.
// Provides a way to copy the metal texture contents to the flutter texture.
class FlutterMetalTexture: NSObject, FlutterTexture {
    // Source image data buffer for generating the texture.
    var sourceImageBuf: CVMetalTexture?
    
    // Render target texture object.
    // Holds the rendered image data, is passed to shaders when drawing.
    var metalTexture: MTLTexture?
    
    // Core video pixel buffer object.
    // Pixel buffer stores an image in main memory.
    var pixelBuf: Unmanaged<CVPixelBuffer>?
    
    // Unique texture id received from FlutterTextureRegistry.
    var flutterTextureId: Int64 = 0
    
    // Initialize texture.
    init(device: MTLDevice, textureCache: CVMetalTextureCache!, width: Int, height: Int) {
        // FlutterTexture init.
        super.init()
        
        // Provides a framebuffer object suitable for sharing across process boundaries.
        // The underlying surface for the created metal texture source pixel buffer.
        guard let ioSurface = IOSurfaceCreate( [
            kIOSurfaceWidth: width,
            kIOSurfaceHeight: height,
            kIOSurfaceBytesPerElement: 4,
            kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA
        ] as CFDictionary)
        else {
            fatalError("Failed to create IOSurface buffer for sharing framebuffer and texture data across multiple processes.")
        }
        
        // Create the metal texture source pixel buffer.
        guard CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            ioSurface,
            [ kCVPixelBufferMetalCompatibilityKey: true ] as CFDictionary,
            &self.pixelBuf ) == kCVReturnSuccess
        else {
            fatalError("Failed to create CVPixelBuffer")
        }
        
        // Create the result Metal texture with the associated source pixel buffer linked to it.
        guard CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            // Creates a live binding between the image buffer and the created MTLTexture object.
            self.pixelBuf!.takeUnretainedValue(),
            nil, .bgra8Unorm,
            width, height, 0,
            &self.sourceImageBuf ) == kCVReturnSuccess
        else {
            fatalError("Failed to bind CVPixelBuffer to metal texture")
        }
        
        // Get the metal texture object.
        // This is the texture passed to the shaders when rendering.
        self.metalTexture = CVMetalTextureGetTexture(self.sourceImageBuf!)
    }
    
    // Copies the pixel buffer contents to the flutter texture.
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        NSLog(self.pixelBuf.debugDescription)
        if let pixelBuf = self.pixelBuf?.takeUnretainedValue() {
            return Unmanaged.passRetained(pixelBuf)
        } else {
            return nil
        }
    }
}
