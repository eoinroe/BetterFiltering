//
//  Renderer.swift
//  ComputeNormals
//
//  Created by Eoin Roe on 11/02/2021.
//

import Foundation
import MetalKit

class Renderer: NSObject {
    var device: MTLDevice
    var renderDestination: RenderDestinationProvider
    
    var commandQueue: MTLCommandQueue!
    
    var computePipeline: MTLComputePipelineState!
    
    var renderPipeline: MTLRenderPipelineState!
    
    var pipelines: [String: MTLComputePipelineState]
    
    // The current viewport size.
    var viewportSize: CGSize = CGSize()
    
    // Flag for viewport size changes.
    var viewportSizeDidChange: Bool = false
    
    // Procedurally generated render texture
    var filteredTexture: MTLTexture!
    
    // Image sourced from https://freepbr.com/materials/cavern-deposits-pbr/
    var sourceImage: MTLTexture!
    
    var startTime: Double!
    var currentTime: Double = 0
    
    // Initialize a renderer by setting up the GPU, and screen backing-store.
    init(device: MTLDevice, renderDestination: RenderDestinationProvider) {
        self.device = device
        self.renderDestination = renderDestination
        
        pipelines = MetalUtils.buildComputePipelinesWithDevice(device: device, names: "better_filtering")
        // pipelines = MetalUtils.buildComputePipelinesWithDevice(device: device, names: "better_filtering", "color_conversion")
        
        super.init()
        
        loadMetal()
        startTime = Date().timeIntervalSince1970
    }
    
    // Schedule a draw to happen at a new size.
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }
    
    func update() {
        // Create a new command buffer for each renderpass to the current drawable.
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            updateAppState()
            
            if let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() {
            
                // Set a label to identify this compute pass in a captured Metal frame.
                computeCommandEncoder.label = "MyComputeEncoder"
            
                doComputePass(computeEncoder: computeCommandEncoder)
            
                // Finish encoding commands.
                computeCommandEncoder.endEncoding()
            }
        
            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let drawable = renderDestination.currentDrawable {
                
                if let renderCommandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                    
                    // Set a label to identify this render pass in a captured Metal frame.
                    renderCommandEncoder.label = "MyRenderEncoder"
                    
                    doRenderPass(renderEncoder: renderCommandEncoder)
                    
                    // Finish encoding commands.
                    renderCommandEncoder.endEncoding()
                }
                    
                // Schedule a present once the framebuffer is complete using the current drawable.
                commandBuffer.present(drawable)
            }
                
            // Finalize rendering here & push the command buffer to the GPU.
            commandBuffer.commit()  
        }
    }
    
    
    // MARK: - Private
    
    // Create and load our basic Metal state objects.
    func loadMetal() {
        // Load all the shader files with a metal file extension in the project.
        let defaultLibrary = device.makeDefaultLibrary()!
        
        // Create the kernel function.
        guard let kernelFunction = defaultLibrary.makeFunction(name: "better_filtering") else {
            fatalError("The shader function couldn't be created.")
        }
        
        do {
            try computePipeline = device.makeComputePipelineState(function: kernelFunction)
        } catch let error {
            print("Failed to create the compute pipeline, error: ", error)
        }
        
        // Create the vertex function.
        guard let vertexFunction = defaultLibrary.makeFunction(name: "base_vertex") else {
            fatalError("Couldn't create the vertex function.")
        }
        
        // Create the fragment function.
        guard let fragmentFunction = defaultLibrary.makeFunction(name: "base_fragment") else {
            fatalError("Couldn't create the fragment function.")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        
        do {
            try renderPipeline = device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            print("Failed to create the render pipeline state \(error)")
        }
        
        setupTextures()
        
        // Create the command queue for one frame of rendering work.
        commandQueue = device.makeCommandQueue()
    }
    
    func setupTextures() {
        let textureLoader = MTKTextureLoader.init(device: device)
        
        do {
            try sourceImage = textureLoader.newTexture(name: "RGBA_Noise", scaleFactor: 1.0, bundle: Bundle.main, options: [:])
        } catch let error {
            print("Failed to create the texture, error: ", error)
        }
        
        // Hardcoding values for now
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 640, height: 360, mipmapped: false)
        // let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float, width: 500, height: 500, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        filteredTexture = device.makeTexture(descriptor: descriptor)
    }
    
    // Updates any app state.
    func updateAppState() {
        // Update the destination-rendering vertex info if the size of the screen changed.
        if viewportSizeDidChange {
            viewportSizeDidChange = false
        }
        
        currentTime = Date().timeIntervalSince1970 - startTime
    }

    func doComputePass(computeEncoder: MTLComputeCommandEncoder) {
        // Push a debug group that enables you to identify this compute pass in a Metal frame capture.
        computeEncoder.pushDebugGroup("ComputePass")
        
        // Set compute command encoder state.
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setTexture(sourceImage, index: 0)
        computeEncoder.setTexture(filteredTexture, index: 1)
        
        var resolution = SIMD2<Float>(Float(filteredTexture.width),
                                      Float(filteredTexture.height))
        
        computeEncoder.setBytes(&resolution, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
        
        var time = Float(currentTime)
        computeEncoder.setBytes(&time, length: MemoryLayout<Float>.size, index: 1)
        
        // Calculate Threads per Threadgroup.
        let w = computePipeline.threadExecutionWidth
        let h = computePipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        
        let threadsPerGrid = MTLSize(width:  filteredTexture.width,
                                     height: filteredTexture.height,
                                     depth: 1)
         
        // Metal is able to calculate how the grid (in this case, an image or texture)
        // can be optimally divided into nonuniform, arbitrarily sized threadgroups.
        computeEncoder.dispatchThreads(threadsPerGrid,
                                       threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    func doRenderPass(renderEncoder: MTLRenderCommandEncoder) {
        // Push a debug group that enables you to identify this render pass in a Metal frame capture.
        renderEncoder.pushDebugGroup("RenderPass")
        
        // Set render command encoder state.
        renderEncoder.setRenderPipelineState(renderPipeline)
        
        // Setup textures for the fragment shader.
        renderEncoder.setFragmentTexture(filteredTexture, index: 0)
        
        var time = Float(currentTime)
        renderEncoder.setFragmentBytes(&time, length: MemoryLayout<Float>.size, index: 1)
        
        // Draw a quad which fills the screen.
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}
