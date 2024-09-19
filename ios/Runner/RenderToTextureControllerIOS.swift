// Copyright (c) 2023 Sakari Lehtonen.

// Test case for rendering with Metal code to a native metal texture, and setting up
// display inside a Flutter Texture widget.

import Foundation
import Flutter
import CoreVideo
import Metal

// Default render target texture size.
let DEF_TEXTURE_SIZE = 720

// Name of the flutter plugin used to register this code to the flutter side.
let FLUTTER_PLUGIN_NAME = "Sumo_CubeRenderApp"

class RenderToTextureControllerIOS {
    // Reference to main flutter view controller.
    let flutterViewController: FlutterViewController
    
    // The renderer class used to render to a texture.
    var renderer: CubeRenderer
    
    // Metal device used to render with.
    var device: MTLDevice!
    
    // Reference to the Flutter texture registry.
    // Have to register the created texture with the flutter registry,
    // in order to display it inside a Flutter Texture Widget.
    var flutterTextureRegistry: FlutterTextureRegistry?
    
    // The texture cache used to create textures in.
    var textureCache: CVMetalTextureCache?
    
    // The render target flutter texture we are rendering to.
    var flutterTexture: FlutterMetalTexture? {
        didSet {
            // Update render pass texture target to created texture.
            self.renderer.renderTargetTexture = flutterTexture?.metalTexture
        }
    }
    
    // Link to the currently active display.
    var displayLink: CADisplayLink?
    
    // Draw the contents of the texture.
    @objc func draw(displayLink: CADisplayLink) {
        self.renderer.draw()
        
        // Notify that the texture was updated.
        if let textureId = self.flutterTexture?.flutterTextureId {
            self.flutterTextureRegistry!.textureFrameAvailable(textureId)
        }
    }
    
    // Sets up the Main render loop for rendering with the shaders to the target texture.
    func setupRenderLoopDisplayLink() -> CADisplayLink {
        let displayLink = CADisplayLink(target: self, selector: #selector(self.draw))
        displayLink.add(to: .main, forMode: .common)
        
        return displayLink
    }
    
    func methodCallHandler(call: FlutterMethodCall, result: FlutterResult) -> Void {
        // Get function call arguments.
        let args = call.arguments as? [String : Any]
        
        switch call.method {
        case "createFlutterTexture":
            // Create the Flutter texture.
            var width = DEF_TEXTURE_SIZE
            var height = DEF_TEXTURE_SIZE
            
            if (args != nil) {
                width = args?["width"] as! Int
                height = args?["height"] as! Int
            }
            
            // The texture contents are first rendered on the metal side, then copied to the flutter
            // texture widget for displaying.
            // This results in a extra copy phase, but I guess there is no way around it.
            let texture = FlutterMetalTexture(device: self.device,
                                              textureCache: self.textureCache,
                                              width: width, height: height)
            
            // The flutter texture needs to be registered to the flutter texture registry in order
            // to use it from the flutter side.
            guard let registeredTextureId = self.flutterTextureRegistry?.register(texture) else {
                fatalError("Failed registering texture to Flutter registry")
            }
            
            // Assign received texture id from flutter, this is passed to the flutter Texture widget for displaying.
            texture.flutterTextureId = registeredTextureId
            
            NSLog("createFlutterTexture :: Texture created with size \(width)*\(height), flutterTextureId = \(texture.flutterTextureId)")
            
            self.flutterTexture = texture
            
            // Return the flutter texture id of the generated flutter texture.
            result(texture.flutterTextureId)
            break
            
        case "setAnimationVelocity":
            if let velocity = args?["velocity"] as? NSNumber {
                let value = velocity.floatValue;
                self.renderer.rotationVelocity = value * 0.01
                NSLog("Set velocity to \(value)")
            }
            break
            
        case "getAnimationVelocity":
            result(self.renderer.rotationVelocity * 100);
            break
            
        default:
            result(FlutterMethodNotImplemented)
            break
        }
    }
    
    init(flutterViewController: FlutterViewController) {
        self.flutterViewController = flutterViewController
        
        // Get default Metal device.
        guard let device = MTLCreateSystemDefaultDevice()
        else {
            fatalError("Failed creating default metal device")
        }
        self.device = device
        
        // Create the texture cache.
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil,
                                        self.device, nil,
                                        &self.textureCache ) == kCVReturnSuccess
        else {
            fatalError("Failed to create texture cache")
        }
        
        // Register plugin and native method channel.
        let registrar = flutterViewController.registrar(forPlugin: FLUTTER_PLUGIN_NAME)
        let methodChannel = FlutterMethodChannel(
            name: FLUTTER_PLUGIN_NAME,
            binaryMessenger: self.flutterViewController.binaryMessenger
        )
        
        // Reference to Flutter texture registry.
        self.flutterTextureRegistry = registrar?.textures()
        guard self.flutterTextureRegistry != nil else {
            fatalError("Could not get flutter texture registry")
        }
        
        // Create the renderer.
        self.renderer = CubeRenderer(metalDevice: self.device)
        
        // Setup the rendering loop via display link callback.
        self.displayLink = setupRenderLoopDisplayLink()
        
        // Setup Flutter native channel method handler.
        methodChannel.setMethodCallHandler(self.methodCallHandler)
    }
}
