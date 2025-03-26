//
//  PHAsset+.swift
//  Cleaner
//

import Photos
import UIKit

public extension PHAsset {
    
    func loadImage() async -> UIImage? {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true

        return await withCheckedContinuation { cont in
            imageManager.requestImage(for: self, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: requestOptions) { (image, info) in
                cont.resume(returning: image)
            }
        }
    }
    
    func getAVAsset() async -> AVAsset? {
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: self,
                options: nil) { asset, _, _ in
                    continuation.resume(returning: asset)
                }
        }
    }
}

extension PHAsset {
      
    func getHashForVideoAsset() async -> String? {
        // Получение ресурса видео
        let options = PHVideoRequestOptions()
        options.deliveryMode = .mediumQualityFormat
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: self,
                options: options
            ) { (avAsset, _, _) in
                // Вычисление хэша для видео
                if let urlAsset = avAsset as? AVURLAsset {
                    if let videoData = try? Data(contentsOf: urlAsset.url) {
                        let hash = String(describing: videoData.hashValue)
                        continuation.resume(returning: hash)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func getHashForPhotoAsset() async -> String? {
        // Получение ресурса фото
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            PHImageManager.default()
                .requestImageDataAndOrientation(
                    for: self,
                    options: options,
                    resultHandler: { imageData, _, _, _ in
                        let hash = imageData?.sha256()
                        continuation.resume(returning: hash)
                    })
        }
    }
    
    func getKeyForAsset() -> String {
        return (self.creationDate?.timeIntervalSince1970 ?? Double.random(in: 0...Double.infinity)).description
    }

}

