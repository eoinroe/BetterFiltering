//
//  ViewController.swift
//  ComputeNormals
//
//  Created by Eoin Roe on 11/02/2021.
//

import Cocoa
import MetalKit

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

extension MTKView: RenderDestinationProvider {}

class ViewController: NSViewController, MTKViewDelegate {
    var renderer: Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view to use the default device.
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.colorPixelFormat = .bgra8Unorm
            view.framebufferOnly = false
            view.delegate = self
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view.
            renderer = Renderer(device: view.device!, renderDestination: view)
            
            /**
             * - Important: Need to be careful with view.bounds.size
             *              being different from view.drawableSize.
             */
            
            // Schedule the screen to be drawn for the first time.
            renderer.drawRectResized(size: view.bounds.size)
        }
    }
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or size.
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Schedule the screen to be redrawn at the new size.
        renderer.drawRectResized(size: size)
    }
    
    // Implements the main rendering loop.
    func draw(in view: MTKView) {
        renderer.update()
    }
    
    
    // MARK: - Actions
    @IBAction func adjustNormalStrength(_ sender: NSSlider) {
        
    }
}
