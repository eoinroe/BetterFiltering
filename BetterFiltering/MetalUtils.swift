import MetalKit

// Using enum as namespace
enum MetalUtils {}

extension MetalUtils {    
    /// Creates the cloth simulation compute pipeline.
    /// - Parameter device: Metal device needed to create pipeline state object.
    /// - Parameter library: Compile Metal code hosting the kernel function driving the compute pipeline.
    static func setupComputePipeline(device: MTLDevice, library: MTLLibrary, name: String) -> MTLComputePipelineState {
        guard let kernelFunction = library.makeFunction(name: name) else {
            fatalError("The kernel function \(name) could not be created.")
        }
        
        guard let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            fatalError("The compute pipeline could not be created.")
        }
        
        return pipeline
    }

    static func buildComputePipelinesWithDevice(device: MTLDevice, names: String...) -> [String: MTLComputePipelineState] {
        // Load all the shader files with a metal file extension in the project.
        let library = device.makeDefaultLibrary()!
        
        let kernelFunctions: [MTLFunction] = names.map({
            guard let function = library.makeFunction(name: $0) else {
                fatalError("The kernel function \($0) could not be created.")
            }
            return function
        })
        
        let pipelines: [MTLComputePipelineState] = kernelFunctions.map({
            guard let pipeline = try? device.makeComputePipelineState(function: $0) else {
                fatalError("The compute pipeline could not be created.")
            }
            return pipeline
        })
        
        return Dictionary(uniqueKeysWithValues: zip(names, pipelines))
    }
    
}
