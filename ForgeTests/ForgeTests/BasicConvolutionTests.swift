import Foundation
import MetalPerformanceShaders
import Forge

class BasicConvolutionTests {
  func runTest(kernelWidth: Int,
               kernelHeight: Int,
               inputChannels: Int,
               outputChannels: Int,
               stride: Int,
               filter: MPSCNNNeuron?) {
    print("  kernel: \(kernelWidth)x\(kernelHeight), channels: in \(inputChannels) out \(outputChannels), stride: \(stride)")

    let imageWidth = 480
    let imageHeight = 360

    let count = outputChannels * kernelWidth * kernelHeight * inputChannels
    var weights = [Float](repeating: 0, count: count)
    Random.uniformRandom(&weights, count: count, scale: 0.1, seed: time(nil))

    var biases = [Float](repeating: 0, count: outputChannels)
    Random.uniformRandom(&biases, count: outputChannels, scale: 0.3, seed: time(nil))

    let inputImage = randomImage(device: device, width: imageWidth,
                                 height: imageHeight, featureChannels: inputChannels,
                                 seed: time(nil))

    let outputImageDesc = MPSImageDescriptor(channelFormat: .float16,
                                             width: imageWidth,
                                             height: imageHeight,
                                             featureChannels: outputChannels)

    let outputImage1 = MPSImage(device: device, imageDescriptor: outputImageDesc)
    let outputImage2 = MPSImage(device: device, imageDescriptor: outputImageDesc)

    let conv1 = BasicConvolutionKernel(device: device,
                                       kernelWidth: kernelWidth,
                                       kernelHeight: kernelHeight,
                                       inputFeatureChannels: inputChannels,
                                       outputFeatureChannels: outputChannels,
                                       strideInPixelsX: stride,
                                       strideInPixelsY: stride,
                                       neuronFilter: filter,
                                       kernelWeights: weights,
                                       biasTerms: biases)
    conv1.edgeMode = .zero

    let desc = MPSCNNConvolutionDescriptor(kernelWidth: kernelWidth,
                                           kernelHeight: kernelHeight,
                                           inputFeatureChannels: inputChannels,
                                           outputFeatureChannels: outputChannels,
                                           neuronFilter: filter)
    desc.strideInPixelsX = stride
    desc.strideInPixelsY = stride

    let conv2 = MPSCNNConvolution(device: device,
                                  convolutionDescriptor: desc,
                                  kernelWeights: weights,
                                  biasTerms: biases,
                                  flags: .none)
    conv2.edgeMode = .zero

    let commandBuffer = commandQueue.makeCommandBuffer()

    conv1.encode(commandBuffer: commandBuffer,
                 sourceImage: inputImage,
                 destinationImage: outputImage1)

    conv2.encode(commandBuffer: commandBuffer,
                 sourceImage: inputImage,
                 destinationImage: outputImage2)

    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()

    let output1 = outputImage1.toFloatArray()
    let output2 = outputImage2.toFloatArray()

    assertEqual(output1, output2, tolerance: 1e-3)
  }

  func testCorrectness() {
    print("\(self)")

    var filter: MPSCNNNeuron?
    filter = MPSCNNNeuronReLU(device: device, a: 0.1)
//    filter = MPSCNNNeuronLinear(device: device, a: 0.5, b: -2)
//    filter = MPSCNNNeuronSigmoid(device: device)
//    filter = MPSCNNNeuronTanH(device: device, a: 0.5, b: -2)
//    filter = MPSCNNNeuronAbsolute(device: device)

    runTest(kernelWidth: 3, kernelHeight: 3, inputChannels: 2, outputChannels: 4, stride: 1, filter: filter)
    runTest(kernelWidth: 3, kernelHeight: 3, inputChannels: 8, outputChannels: 8, stride: 1, filter: filter)
  }
}
