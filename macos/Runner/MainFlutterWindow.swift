import Cocoa
import FlutterMacOS
import MetalKit

class MainFlutterWindow: NSWindow {
    var textureController : RenderToTextureControllerMacOS!
    
    override func awakeFromNib() {
        // Initialize the main flutter view controller.
        let flutterViewController = FlutterViewController.init()
        
        // Get window frame size.
        let windowFrame = self.frame
        
        // contentViewController
        // Owned by UIWindow rootViewController
        // Contains view controllers, with associated views.
        self.contentViewController = flutterViewController
        
        // Set the origin and size of the frame (=viewport size).
        self.setFrame(windowFrame, display: true)
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        // Create instance of textureController.
        self.textureController = RenderToTextureControllerMacOS.init(flutterViewController: flutterViewController)
        
        super.awakeFromNib()
    }
}
