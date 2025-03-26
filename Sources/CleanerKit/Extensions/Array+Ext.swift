//
//  Array+.swift
//  Cleaner
//

import Foundation
import Photos
import UIKit

public extension Array {
    func withoutDuplicates<T: Hashable>(transform: (Element) -> T?) -> [Element] {
        var seen: Set<T> = []
        return self.compactMap { element in
            guard let transformed = transform(element), !seen.contains(transformed) else {
                return nil
            }
            seen.insert(transformed)
            return element
        }
    }
}


public extension Array where Element == String {
    func duplicates() -> [String] {
        var counts: [String: Int] = [:]
        for item in self {
            counts[item, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.map { $0.key }
    }
}

public extension Array where Element: Equatable {
    func allIndices(of value: Element) -> [Index] {
        indices.filter { self[$0] == value }
    }
}

public extension Array where Element == [PHAsset] {
    
    func totalImagesMegabytes() async -> Double {
        
        var totalMegabytes: Double = 0.0
        
        await withTaskGroup(of: Double.self) { group in
            for assets in self {
                totalMegabytes += await assets.getTotalImageMegabytes()
            }
        }
        
        return totalMegabytes
    }
    
    func totalVideosMegabytes() async -> Double {
        
        var totalMegabytes: Double = 0.0
        
        await withTaskGroup(of: Double.self) { group in
            for assets in self {
                totalMegabytes += await assets.getTotalVideoMegabytes()
            }
        }
        
        return totalMegabytes
    }

}

public extension Array where Element == PHAsset {

    func getAllImages() async -> [UIImage] {
        
        return await withTaskGroup(of: UIImage?.self) { group in
            
            var array: [UIImage?] = []
            
            for asset in self {
                group.addTask {
                    return await asset.loadImage()
                }
            }
            for await image in group {
                array.append(image)
            }
            return array.compactMap { $0 }
        }
    }
    
    public func getTotalImageMegabytes() async -> Double {
        var totalMegabytes: Double = 0.0
        
        await withTaskGroup(of: Double.self) { group in
            for asset in self {
                group.addTask {
                    if let image = await asset.loadImage() {
                        return image.megabytes() ?? 0.0
                    }
                    return 0.0
                }
            }
            
            for await megabytes in group {
                totalMegabytes += megabytes
            }
        }
        return totalMegabytes
    }
    
    public func getTotalVideoMegabytes() async -> Double {
        var totalMegabytes: Double = 0.0
        
        await withTaskGroup(of: Double.self) { group in
            for asset in self {
                group.addTask {
                    await asset.getVideoSize()
                }
            }
            
            for await megabytes in group {
                totalMegabytes += megabytes
            }
        }
        return totalMegabytes
    }
}

public extension PHAsset {
    
    func getVideoAssetFilename() async -> String? {
        let resources = PHAssetResource.assetResources(for: self)
        
        // Find the original video resource
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else {
            return nil
        }
        
        return resource.originalFilename
    }

    func getVideoSize() async -> Double {
        let resources = PHAssetResource.assetResources(for: self)
        
        // Get the original resource (usually the first one)
        guard let resource = resources.first else {
            return .zero
        }
        
        // Get the file size in bytes
        let sizeInBytes = await withCheckedContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: resource, options: nil) { data in
                // This gives us chunks of data, but we just want the total size
            } completionHandler: { error in
                // We'll use the expected content length instead
                let size = resource.value(forKey: "fileSize") as? Int64 ?? 0
                continuation.resume(returning: size)
            }
        }
        
        // Convert bytes to megabytes
        let sizeInMB = Double(sizeInBytes) / (1024 * 1024)
        return sizeInMB
    }
}
