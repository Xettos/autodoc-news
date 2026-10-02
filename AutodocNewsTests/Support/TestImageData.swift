import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

enum TestImageData {
    private static let bitsPerComponent = 8
    private static let singleImageCount = 1

    static func jpeg(width: Int, height: Int, orientation: CGImagePropertyOrientation = .up) throws -> Data {
        let image = try solidImage(width: width, height: height)
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, singleImageCount, nil)
        )
        let properties = [kCGImagePropertyOrientation: orientation.rawValue] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        try #require(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private static func solidImage(width: Int, height: Int) throws -> CGImage {
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try #require(context.makeImage())
    }
}
