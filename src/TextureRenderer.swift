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
    
    // For creating command buffers, and submitting command buffers to run on the GPU.
    var commandQueue: MTLCommandQueue
    
    // Current viewport size.
    // This is the default size if none provided from the caller.
    var viewportSize:SIMD2<UInt32> = SIMD2(UInt32(DEF_VIEWPORT_SIZE),
                                           UInt32(DEF_VIEWPORT_SIZE));
    
    // Vertex shader buffer indexes.
    enum VertexInputIndex : Int {
        case vertices = 0
        case uniforms = 1
    }
    
    // Shader vertex.
    struct Vertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
    }
    
    // Vertex data.
    var vertices: [Vertex]!
    
    // Shader uniforms passed to the vertex shader.
    struct Uniforms {
        var modelMatrix: simd_float4x4
        var projectionMatrix: simd_float4x4
        var viewMatrix: simd_float4x4
    }
    
    var uniforms = Uniforms(
        modelMatrix: matrix_identity_float4x4,
        projectionMatrix: matrix_identity_float4x4,
        viewMatrix: matrix_identity_float4x4
    )
   
    // // Cube transformation properties.
    // var translation:SIMD3<Float> = [
    //     0, 0.0, 0.0,
    // ]
    
    // var rotation:Float = 0
    // var rotationPhase:Float = 0.0;
    // var rotationVelocity:Float = 1.0;
    
    // var scaling:SIMD3<Float> = [
    //     0.8, 0.8, 0.8
    // ]
    
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
        
        // TODO: Set up connection to MetalCamera texture callback
        // self.uniforms.projectionMatrix = makePerspectiveProjectionMatrix(fov: 75.0,
        //                                                                      aspectRatio: aspectRatio,
        //                                                                      nearPlane: 1, farPlane: 10)
        
        // self.uniforms.viewMatrix = makeTranslationMatrix(tx: 0.0, ty: 0.0, tz: -6.0)
        
        // // Make a cube.
        // let c1:SIMD4<Float> = [0.15, 0.25, 0.7, 1.0]
        // let c2:SIMD4<Float> = [0.9, 0.2, 0.2, 1.0]
        
        // let A = Vertex(position: [-1.0, 1.0, 1.0], color: c2)
        // let B = Vertex(position: [-1.0,-1.0, 1.0], color: c1)
        // let C = Vertex(position: [ 1.0,-1.0, 1.0], color: c1)
        // let D = Vertex(position: [ 1.0, 1.0, 1.0], color: c2)
        
        // let Q = Vertex(position: [-1.0, 1.0,-1.0], color: c2)
        // let R = Vertex(position: [ 1.0, 1.0,-1.0], color: c2)
        // let S = Vertex(position: [-1.0,-1.0,-1.0], color: c1)
        // let T = Vertex(position: [ 1.0,-1.0,-1.0], color: c1)
        
        // self.vertices = [
        //   A,B,C ,A,C,D,   // Front.
        //   R,T,S ,Q,R,S,   // Back.
          
        //   Q,S,B ,Q,B,A,   // Left.
        //   D,C,T ,D,T,R,   // Right.
          
        //   Q,A,D ,Q,D,R,   // Top.
        //   B,S,T ,B,T,C    // Bot.
        // ]
        
        // Get the default shader library.
        let shaderLib = self.device.makeDefaultLibrary()
        
        // Initialize rendering pipeline.
        let renderPipelineDesc = MTLRenderPipelineDescriptor()
        renderPipelineDesc.label = "Cube pipeline"
        renderPipelineDesc.vertexFunction = shaderLib?.makeFunction(name: "vertexShader")
        renderPipelineDesc.fragmentFunction = shaderLib?.makeFunction(name: "fragmentShader")
        renderPipelineDesc.colorAttachments[0].pixelFormat = .bgra8Unorm
        
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
    
    // Renders the given render target texture to a quad.
    func draw() {
        // Initially the texture does not exist, as it is created
        // from the flutter side callback. If we don't have the texture, don't draw.
        if !self.running || self.renderTargetTexture == nil {
            if (self.renderTargetTexture == nil) {
                NSLog("draw: renderTargetTexture == nil, returning")
            }
            
            return
        }
        
        let timeNow = self.clock.now
        let frameDuration = self.lastInstant.duration(to: timeNow)
        let frameTimeUs = frameDuration.components.attoseconds / 1_000_000_000_000
        let fps:Float = Float(1_000_000 / frameTimeUs)
        
        print("frametime = \(frameTimeUs) fps = \(fps)")
        
        // Create the command buffer for this frame.
        guard let commandBuf = self.commandQueue.makeCommandBuffer() else {
            fatalError("Could not create command buffer")
        }
        
        // Create command encoder for this frame.
        guard let encoder = commandBuf.makeRenderCommandEncoder(descriptor: self.renderPassDesc) else {
            fatalError("Could not create command encoder")
        }
        
        encoder.setCullMode(MTLCullMode.front)
        encoder.setRenderPipelineState(pipelineState)
        
        encoder.setViewport(MTLViewport(originX: 0, originY: 0,
                                        width: Double(self.viewportSize.x),
                                        height: Double(self.viewportSize.y),
                                        znear: 0.0, zfar: 1.0))
        
        // TODO: Run the MetalCamera texture here
        // // Run animation logic.
        // let phaseDelta = self.rotationVelocity  / fps;
        // self.rotationPhase += phaseDelta;
        
        // let tau = Float.pi * 2;
        // if (self.rotationPhase >= tau) {
        //     self.rotationPhase = 0.0
        // } else if (self.rotationPhase < 0.0) {
        //     self.rotationPhase = tau
        // }
        
        // self.rotation = self.rotationPhase
        
        // //xself.scaling.x = 0.5 * cos(self.rotationPhase)
        
        // let scaleMat = makeScaleMatrix(xs: self.scaling.x,
        //                                ys: self.scaling.y,
        //                                zs: self.scaling.z);
        
        // let rotationMat = makeRotationMatrix(angle: self.rotation)
        
        // let translationMat = makeTranslationMatrix(tx: self.translation.x,
        //                                            ty: self.translation.y,
        //                                            tz: self.translation.z)
        
        // self.uniforms.modelMatrix = scaleMat * rotationMat * translationMat;
        // self.uniforms.viewMatrix = makeTranslationMatrix(tx: 0,
        //                                                  ty: 1.2 * sin(self.rotationPhase),
        //                                                  tz: -6)
        
        // // Set vertices.
        // // Under 4kb so can set without a buffer.
        // encoder.setVertexBytes(self.vertices,
        //                        length: MemoryLayout<Vertex>.stride * self.vertices.count,
        //                        index: VertexInputIndex.vertices.rawValue)
        
        // // Set uniforms.
        // encoder.setVertexBytes(&self.uniforms,
        //                        length: MemoryLayout<Uniforms>.size,
        //                        index: VertexInputIndex.uniforms.rawValue)
        
        // // Draw the cube.
        // encoder.drawPrimitives(type: .triangle,
        //                        vertexStart: 0,
        //                        vertexCount: self.vertices.count)
        
        // End encoding rendering commands for this frame.
        encoder.endEncoding()
        
        // Commit the command buffer to the GPU.
        commandBuf.commit()
        
        self.elapsedFrames += 1;
        self.lastInstant = timeNow
    }
}
