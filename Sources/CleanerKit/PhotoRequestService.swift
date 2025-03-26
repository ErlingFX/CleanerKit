//
//  PhotoRequestService.swift
//

import Foundation
import Photos
import UIKit

class PhotoRequestService {
    
    static let shared = PhotoRequestService()
    
    private init() {}
    
    func getAssets(of type: PHAssetMediaType, indexes: [Int]? = nil) async -> [PHAsset] {
        return await withCheckedContinuation { cont in
            self.getAssets(of: type, indexes: indexes) { assets in
                cont.resume(returning: assets)
            }
        }
    }
    func getAssets(
        of type: PHAssetMediaType,
        indexes: [Int]? = nil,
        queryCallback: @escaping (([PHAsset]) -> Void)
    ) {
        PHPhotoLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                DispatchQueue.global().async {
                    let fetchResult = PHAsset.fetchAssets(with: type, options: nil)
                    
                    var assets: [PHAsset] = []
                    
                    guard let indexes = indexes else {
                        fetchResult.enumerateObjects { currentAsset, _, _ in
                            assets.append(currentAsset)
                        }
                    
                        DispatchQueue.main.async {
                            queryCallback(assets)
                        }
                        
                        return
                    }
                    
                    indexes.forEach { index in
                        assets.append(fetchResult[index])
                    }
                    
                    DispatchQueue.main.async {
                        queryCallback(assets)
                    }
                }
            default:
                return
            }
        }
    }
    
}
