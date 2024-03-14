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
    var renderTargetTexture: MTLTexture? {
        didSet {
            // Update render pass texture target to created texture.
            self.renderPassDesc.colorAttachments[0].texture = renderTargetTexture
        }
    }
    
    // Defines the graphics state, including vertex and fragment shader functions.
    // Created early in the app startup and re-used through its lifetime.
    var pipelineState: MTLRenderPipelineState
    
    // For creating command buffers, and submitting command buffers to run on the Metal device (GPU).
    var commandQueue: MTLCommandQueue
    
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
    
    init(metalDevice: MTLDevice) {
        self.device = metalDevice
        
        let aspectRatio = Float(self.viewportSize.x / self.viewportSize.y)
  
        // Initialize rendering pipeline.
        initializeRenderPipelineState();

        // Clear the target texture before rendering to it.
        self.renderPassDesc.colorAttachments[0].loadAction = .clear
        self.renderPassDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        
        guard let pipelineState = try? self.device.makeRenderPipelineState(descriptor: renderPipelineDesc)
        else {
            fatalError("Failed to create metal render pipeline state")
        }
        self.pipelineState = pipelineState
        
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
                 var texture = texture,
                 let device = device,
                 let commandBuffer = commandQueue?.makeCommandBuffer()
             else {
                 _ = semaphore.signal()
                 fatalError("Could not create command buffer")
                 return
             }
             // Create command encoder for this frame.
             guard
             let renderPipelineState = renderPipelineState,
             let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
                else {
                    semaphore.signal()
                    fatalError("Could not create command encoder")
                    return
                }
                
                encoder.pushDebugGroup("RenderFrame")
                encoder.setRenderPipelineState(renderPipelineState)

                // Draw the texture to the screen.
                encoder.setFragmentTexture(texture, index: 0)
                encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: 1)
                
                // End encoding rendering commands for this frame.
                encoder.popDebugGroup()
                encoder.endEncoding()
                
                commandBuffer.addScheduledHandler { [weak self] (buffer) in
                    guard let unwrappedSelf = self else { return }
                    
                    unwrappedSelf.didRenderTexture(texture, withCommandBuffer: buffer, device: device)
                    unwrappedSelf.semaphore.signal()
                }
                commandBuffer.present(currentDrawable)
                // Commit the command buffer to the GPU.
                commandBuffer.commit()
            }
    }

    /**
      initializes render pipeline state with a default vertex function mapping texture to the view's frame and a simple fragment function returning texture pixel's value.
      */
     fileprivate func initializeRenderPipelineState() {
         guard
             let device = device,
             let library = device.makeDefaultLibrary()
         else { return }
        
         let pipelineDescriptor = MTLRenderPipelineDescriptor()
         pipelineDescriptor.label = "TextureRenderPipeline"
         pipelineDescriptor.sampleCount = 1
         pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
         pipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
         /**
          *  Vertex function to map the texture to the view controller's view
          */
         pipelineDescriptor.vertexFunction = library.makeFunction(name: "mapTexture")
         /**
          *  Fragment function to display texture's pixels in the area bounded by vertices of `mapTexture` shader
          */
         pipelineDescriptor.fragmentFunction = library.makeFunction(name: "displayTexture")
        
         do {
             try renderPipelineState = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
         }
         catch {
             assertionFailure("Failed creating a render state pipeline. Can't render the texture without one.")
             return
         }
     }
}
