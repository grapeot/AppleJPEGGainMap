import CoreImage
import CoreGraphics
import Foundation
import AppKit
import CoreServices
import ImageIO

func extractGainMap(inputFilePath: String, outputFilePath: String?) -> (CGImageMetadata?, [String: Any]?) {
    let imageURL = URL(fileURLWithPath: inputFilePath)
    
    guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
        print("Error creating image source.")
        return (nil, nil)
    }
    let gainmap = CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap)
    let gainDict = NSDictionary(dictionary: gainmap ?? [:])
    let gainData = gainDict[kCGImageAuxiliaryDataInfoData] as! Data
    let gainDescription = gainDict[kCGImageAuxiliaryDataInfoDataDescription] as! [String: Any]
    let gainMeta = gainDict[kCGImageAuxiliaryDataInfoMetadata] as! CGImageMetadata
    let xmpMetadata = String(data: CGImageMetadataCreateXMPData(gainMeta, [:] as CFDictionary)! as Data, encoding: .utf8)
    
    print("XMP Metadata from kCGImageAuxiliaryDataInfoMetadata: \(xmpMetadata!)")
    
    if (outputFilePath != nil) {
        let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(gainDescription["Width"] as! Int32),
            pixelsHigh: Int(gainDescription["Height"] as! Int32),
            bitsPerSample: 8,
            samplesPerPixel: 1,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceWhite,
            bytesPerRow: Int(gainDescription["BytesPerRow"] as! Int32),
            bitsPerPixel: 8
        )
        
        gainData.copyBytes(to: bitmapRep!.bitmapData!, count: gainData.count)
        
        if let pngData = bitmapRep!.representation(using: .png, properties: [:]) {
            do {
                try pngData.write(to: URL(fileURLWithPath: outputFilePath!))
                print("Image saved to \(outputFilePath!)")
            } catch {
                print("Error saving image: \(error)")
            }
        } else {
            print("Failed to create PNG data.")
        }
    }
    
    return (gainMeta, gainDescription)
}

func imageDataFromCGImage(cgImage: CGImage) -> Data? {
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bytesPerPixel = 1
    let bytesPerRow = bytesPerPixel * width
    let bitsPerComponent = 8

    var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
    guard let context = CGContext(data: &rawData,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    return Data(rawData)
}


func writeAuxiliaryDataToImage(inputImagePath: String, gainMapPath: String, gainMeta: CGImageMetadata, gainDescription: [String: Any], outputImagePath: String) {
    // Load the target image
    let inputImageURL = URL(fileURLWithPath: inputImagePath)
    guard let source = CGImageSourceCreateWithURL(inputImageURL as CFURL, nil) else {
        print("Error creating image source.")
        return
    }

    var imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
    var makerApple = imageProperties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]
    makerApple["33"] = 0.8
    makerApple["48"] = 0.0
    imageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerApple
    
    // Load the gain map image
    let gainMapURL = URL(fileURLWithPath: gainMapPath)
    guard let gainMapSource = CGImageSourceCreateWithURL(gainMapURL as CFURL, nil),
          let gainMapImage = CGImageSourceCreateImageAtIndex(gainMapSource, 0, nil) else {
        print("Error loading gain map image.")
        return
    }

    // Prepare the auxiliary data
    var mutableGainDescription = gainDescription
    mutableGainDescription["Width"] = gainMapImage.width
    mutableGainDescription["Height"] = gainMapImage.height
    mutableGainDescription["BytesPerRow"] = gainMapImage.bytesPerRow
    let gainMapImageData = imageDataFromCGImage(cgImage: gainMapImage)!
    let auxDataInfo: [String: Any] = [
        kCGImageAuxiliaryDataInfoData as String: gainMapImageData,
        kCGImageAuxiliaryDataInfoDataDescription as String: mutableGainDescription,
        kCGImageAuxiliaryDataInfoMetadata as String: gainMeta
    ]

    // Create a new image destination
    let outputImageURL = URL(fileURLWithPath: outputImagePath)
    guard let destination = CGImageDestinationCreateWithURL(outputImageURL as CFURL, CGImageSourceGetType(source)!, 1, nil) else {
        print("Error creating image destination.")
        return
    }

    // Add the image and auxiliary data
    CGImageDestinationAddImageFromSource(destination, source, 0, imageProperties as CFDictionary)
    CGImageDestinationAddAuxiliaryDataInfo(destination, kCGImageAuxiliaryDataTypeHDRGainMap, auxDataInfo as CFDictionary)

    // Finalize and save the image
    if !CGImageDestinationFinalize(destination) {
        print("Failed to write image to disk.")
    } else {
        print("Image successfully saved to \(outputImagePath)")
    }
}

// This script uses a reference photo from iPhone to construct data structures
let referenceImagePath = "reference.heic"
// The SDR image
let sdrImagePath = "white.jpg"
let gainMapImagePath = "gain_map.png"
let outputHDRImagePath = "HDR.jpg"

// Extract data structures from a reference image
let (gainMeta, gainDescription) = extractGainMap(inputFilePath: referenceImagePath, outputFilePath: nil)

if let gainMeta = gainMeta, let gainDescription = gainDescription {
    // Call the writeAuxiliaryDataToImage function
    writeAuxiliaryDataToImage(
        inputImagePath: sdrImagePath,
        gainMapPath: gainMapImagePath,
        gainMeta: gainMeta,
        gainDescription: gainDescription,
        outputImagePath: outputHDRImagePath
    )
} else {
    print("Failed to extract gain map metadata or description.")
}
