// Copyright (c) 2023 Sumo Apps.
//
// Renders an animated cube with Metal to a texture.

import Foundation
import Metal
import simd

let DEF_VIEWPORT_SIZE = 720

class TextureRenderer: NSObject {
    // Reference to the metal device.
    var device:MTLDevice
    
    // The target texture we are rendering to.
    open var renderTargetTexture: MTLTexture? {
        didSet {
            // Update render pass texture target to created texture.
            self.renderPassDesc.colorAttachments[0].texture = renderTargetTexture
        }
    }
    
    // Defines the graphics state, including vertex and fragment shader functions.
    // Created early in the app startup and re-used through its lifetime.
    var pipelineState: MTLRenderPipelineState?
    
    // For creating command buffers, and submitting command buffers to run on the Metal device (GPU).
    var commandQueue: MTLCommandQueue?
    
    //TODO: Current viewport size.
    // This is the default size if none provided from the caller.
    var viewportSize:SIMD2<UInt32> = SIMD2(UInt32(DEF_VIEWPORT_SIZE),
                                           UInt32(DEF_VIEWPORT_SIZE));
    
    // A semaphore we use to syncronize drawing code.
    fileprivate let semaphore = DispatchSemaphore(value: 1)
    
    // Number of rendered frames.
    var elapsedFrames:Float = 0
    
    // Cube rendering render pass descriptor.
    var renderPassDesc = MTLRenderPassDescriptor()
    
    // Continue running rendering ?
    var running = true
    
    var clock = ContinuousClock()
    var lastInstant:ContinuousClock.Instant = ContinuousClock.now
    
    init?(metalDevice: MTLDevice) {
        self.device = metalDevice
        self.pipelineState = nil // Make pipelineState optional in your class definition

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "TextureRenderPipeline"
        pipelineDescriptor.rasterSampleCount = 1
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        /**
         *  Vertex function to map the texture to the view controller's view
         */
        pipelineDescriptor.vertexFunction = device.makeDefaultLibrary()?.makeFunction(name: "mapTexture")
        
        /**
         *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
         */
        pipelineDescriptor.fragmentFunction = device.makeDefaultLibrary()?.makeFunction(name: "displayTexture")
        
        // Clear the target texture before rendering to it.
        self.renderPassDesc.colorAttachments[0].loadAction = .clear
        self.renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)

        do {
            self.pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            print("Failed creating a render state pipeline. Can't render the texture without one.")
            return nil // If the pipeline state creation fails, abort initialization
        }
        
        /**
          initializes render pipeline state with a default vertex function mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
          */
        guard
            let library = device.makeDefaultLibrary()
        else { return }
        
        

        guard let commandQueue = self.device.makeCommandQueue(maxCommandBufferCount: 10)
        else {
            fatalError("Failed to create metal command queue")
        }
        self.commandQueue = commandQueue
    }
    
    // Renders the given render target texture.
    func render() {
        // Initially the texture does not exist, as it is created
        // from the flutter side callback. If we don't have the texture, don't draw.
        if !self.running || self.renderTargetTexture == nil {
            if (self.renderTargetTexture == nil) {
                NSLog("render: renderTargetTexture == nil, returning")
            }
            
            return
        }
        
        let timeNow = self.clock.now
        let frameDuration = self.lastInstant.duration(to: timeNow)
        let frameTimeUs = frameDuration.components.attoseconds / 1_000_000_000_000
        let fps:Float = Float(1_000_000 / frameTimeUs)
        
        print("frametime = \(frameTimeUs) fps = \(fps)")
        
        // Create the command buffer for this frame.
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)


         autoreleasepool {
             guard
                 var texture = renderTargetTexture,
                 let commandBuffer = commandQueue?.makeCommandBuffer()
             else {
                 _ = semaphore.signal()
                 fatalError("Could not create command buffer")
             }
             // Create command encoder for this frame.
             guard
                let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc)
             else {
                _ = semaphore.signal()
                fatalError("Could not create command encoder")
            }
            
            encoder.pushDebugGroup("RenderFrame")
             guard let pipelineState = pipelineState
             else {
                 _ = semaphore.signal()
                 fatalError("Could not create pipeline state");
             }
            encoder.setRenderPipelineState(pipelineState)

            // Draw the texture to the screen.
            encoder.setFragmentTexture(texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
            
            // End encoding rendering commands for this frame.
            encoder.popDebugGroup()
            encoder.endEncoding()
            
            commandBuffer.addScheduledHandler { [weak self] (buffer) in
                guard 
                    let unwrappedSelf = self 
                else { return }
                    //TODO: unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
                unwrappedSelf.semaphore.signal()
            }
            // Commit the command buffer to the GPU.
            commandBuffer.commit()
            }
    }
}
