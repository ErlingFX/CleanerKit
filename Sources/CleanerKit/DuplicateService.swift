//
//  DuplicateService.swift
//

import CocoaImageHashing
import StorageManager
import CommonCrypto
import Photos
import Vision
import Combine
import MetalPerformanceShaders
import MetalKit
import SwifterSwift

class DuplicateService {
    
    static let shared = DuplicateService()
    
    public let processCounter = CurrentValueSubject<(Int, Int), Never>((0, 0))
    
    private let manager = PHImageManager.default()
    private let photoRequestOptions = PHImageRequestOptions()
    private let videoRequestOptions = PHVideoRequestOptions()
    
//    private lazy var storageManager: StorageManager? = {
//        let config = DiskStorage.Config(name: "codable")
//        return try? DiskStorage(config: config)
//    }()

    private init() {}
    
    public func findSimilarImage(assetList: [PHAsset]) async -> [[PHAsset]] {
        return await withCheckedContinuation { cont in
            findSimilarImage(assetList: assetList) { array in
                cont.resume(returning: array)
            }
        }
    }
        
    public func findSimilarImage(
        assetList: [PHAsset],
        queryCallback: @escaping (([[PHAsset]]) -> Void)
    ) {
        print("❇️ Start \(#function)")
        photoRequestOptions.isSynchronous = true
        photoRequestOptions.deliveryMode = .opportunistic
        photoRequestOptions.isNetworkAccessAllowed = true
        
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: 50.0 * scale, height: 50.0 * scale)
        let startDate = Date().timeIntervalSinceReferenceDate
        let lock = NSRecursiveLock()
        
        self.sendProcessCounter(0, assetList.count)
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            
            var uiImages = [UIImage?](repeating: nil, count: assetList.count)
            
            var similarImageIdsAsTuples: [OSTuple<NSString, NSString>] = []
            
//            if let storedHashes = try? storageManager?.value(forKey: "similar_images", as: [SimilarHashType<String, String>].self) {
//                
//                self.sendProcessCounter(assetList.count, assetList.count)
//                
//                similarImageIdsAsTuples = storedHashes.map { .init(first: $0.first?.nsString, andSecond: $0.second?.nsString) }
//            } else {
                
                DispatchQueue.concurrentPerform(iterations: uiImages.count) { iteration in
                    autoreleasepool {
                        self.manager.requestImage(
                            for: assetList[iteration],
                            targetSize: targetSize,
                            contentMode: .aspectFit,
                            options: self.photoRequestOptions,
                            resultHandler: { image, _ in
                                
                                lock.lock()
                                
                                uiImages[iteration] = image
                                
                                self.sendProcessCounter(iteration, assetList.count)

                                lock.unlock()
                            }
                        )
                        
                        return
                    }
                }
                
                let similarImageIds: [OSTuple<NSString, NSData>] = uiImages
                    .map { $0?.pngData() }
                    .withoutDuplicates(transform: { $0?.sha256()})
                    .compactMap { $0 }
                    .enumerated()
                    .compactMap { offset, data in
                        return OSTuple<NSString, NSData>(
                            first: NSString(string: "\(offset)"),
                            andSecond: data as NSData
                        )
                    }
                
                similarImageIdsAsTuples = OSImageHashing
                    .sharedInstance()
                    .similarImages(with: OSImageHashingQuality.medium, forImages: similarImageIds)
                
                let storeableHashes: [SimilarHashType<String, String>] = similarImageIdsAsTuples.map { typle in
                    return .init(
                        first: typle.first as? String,
                        second: typle.second as? String
                    )
                }
//                try? storageManager?.store(storeableHashes, forKey: "similar_images", expiration: .days(1))
//            }
            
            let arrayId: [[Int]] = similarImageIdsAsTuples.map { tuple in
                let id = [Int(tuple.first! as String), Int(tuple.second! as String)]
                return id.compactMap { $0 }
            }
            
            var resultArray = [[Int]]()
            
            for (indexArrayID, arrayI) in arrayId.enumerated() {
                if indexArrayID == 0 {
                    resultArray.append(arrayI)
                } else {
                    var isContains = false
                    for (indexResultArray, result) in resultArray.enumerated() {
                        if result.contains(arrayI[1]) && result.contains(arrayI.first!) {
                            isContains = true
                            break
                        } else if result.contains(arrayI.first!) {
                            var newdata = result
                            resultArray.remove(at: indexResultArray)
                            newdata.append(arrayI[1])
                            resultArray.insert(newdata, at: indexResultArray)
                            isContains = true
                            break
                        } else if result.contains(arrayI[1]) {
                            var newdata = result
                            resultArray.remove(at: indexResultArray)
                            newdata.append(arrayI.first!)
                            resultArray.insert(newdata, at: indexResultArray)
                            isContains = true
                            break
                        }
                    }
                    if !isContains {
                        resultArray.append(arrayI)
                    }
                }
            }
            
            let finishDate = Date().timeIntervalSinceReferenceDate
            print("\n⏰ similar - \(finishDate - startDate)")
            
            let dispatchGroup = DispatchGroup()
            var resultPHAssetArray: [[PHAsset]] = []
            
            resultArray.forEach { indexes in
                dispatchGroup.enter()
                
                PhotoRequestService
                    .shared
                    .getAssets(of: .image, indexes: indexes) { images in
                        resultPHAssetArray.append(images)
                        
                        dispatchGroup.leave()
                    }
            }
            
            dispatchGroup.notify(queue: .main) {
                
                DispatchQueue.main.async {
                    queryCallback(resultPHAssetArray)
                }
            }
        }
    }
    
    public func findDuplicatePhotos(assetsArray: [[PHAsset]]) async -> [[PHAsset]] {
        return await withCheckedContinuation { cont in
            findDuplicatePhotos(assetsArray: assetsArray) { array in
                cont.resume(returning: array)
            }
        }
    }
    
    public func findDuplicatePhotos(
        assetsArray: [[PHAsset]],
        queryCallback: @escaping (([[PHAsset]]) -> Void)
    ) {
        photoRequestOptions.isSynchronous = true
        
        print("❇️ Start \(#function)")
        let startDate = Date().timeIntervalSinceReferenceDate
        
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            
            var result = [[PHAsset]]()
            
            let outerLock = NSRecursiveLock()
            
            DispatchQueue.concurrentPerform(iterations: assetsArray.count) {  outerIteration in
                
                let images = assetsArray[outerIteration]
                
                self.sendProcessCounter(0, images.count)
                
                var hashes: [String?] = []
                
                /// if hashes array is stored - get from store
//                if let storedHashes = try? self.storageManager?.value(forKey: "duplicate_photos", as: [String?].self) {
//                    hashes = storedHashes
//                    
//                    self.sendProcessCounter(images.count, images.count)
//                    
//                } else {
                    hashes = Array(repeating: nil, count: images.count)
                    
                    let innerLock = NSRecursiveLock()
                    
                    DispatchQueue.concurrentPerform(iterations: images.count) { innerIteration in
                        autoreleasepool {
                            self.manager.requestImageDataAndOrientation(
                                for: images[innerIteration],
                                options: self.photoRequestOptions,
                                resultHandler: { imageData, _, _, _ in
                                    
                                    innerLock.lock()
                                    
                                    hashes[innerIteration] = imageData?.sha256()
                                    
                                    self.sendProcessCounter(innerIteration, images.count)
                                    
                                    innerLock.unlock()
                                }
                            )
                            return
                        }
                    }
//                    try? self.storageManager?.store(hashes, forKey: "duplicate_photos", expiration: .days(1))
//                }
                
                hashes
                    .compactMap { $0 }
                    .duplicates()
                    .forEach { duplicate in
                        let duplicateIndexes = hashes.allIndices(of: duplicate)
                        
                        let assets = duplicateIndexes.map { index in
                            images[index]
                        }
                        
                        outerLock.lock()
                        
                        result.append(assets)
                        
                        outerLock.unlock()
                    }
            }
            
            let finishDate = Date().timeIntervalSinceReferenceDate
            print("\nduplicate - \(finishDate - startDate)")
            
            DispatchQueue.main.async {
                queryCallback(result)
            }
        }
    }
    
    public func findDuplicateVideos(assetsArray: [PHAsset]) async -> [[PHAsset]] {
        print("❇️ Start \(#function)")
        let startDate = Date().timeIntervalSinceReferenceDate
        
        self.sendProcessCounter(0, assetsArray.count)

        var duplicateVideos: [[PHAsset]] = []
        
        var videoHashes: [String: [String]] = [:]
        
        /// if hashes array is stored - get from store
//        if let storedHashes = try? self.storageManager?.value(forKey: "duplicate_videos", as: [String: [String]].self) {
//            
//            self.sendProcessCounter(assetsArray.count, assetsArray.count)
//
//            videoHashes = storedHashes
//            
//        } else {
            
            // Проход по всем видео и вычисление хэшей
            videoHashes = await withTaskGroup(of: (Int, String, String)?.self) { group in
                
                // Словарь для хранения хэшей видео и соответствующих PHAsset объектов
                var videoHashes: [String: [String]] = [:]
                
                for (index, asset) in assetsArray.enumerated()  {
                    group.addTask {
                        // Получение хэша для видео
                        if let videoHash = await asset.getHashForVideoAsset() {
                            return (index, videoHash, asset.localIdentifier)
                        }
                        return nil
                    }
                }
                
                for await result in group {
                    
                    self.sendProcessCounter(result?.0 ?? 0, assetsArray.count)

                    if let videoHash = result?.1, let asset = result?.2 {
                        // Добавление видео в словарь по хэшу
                        if var assets = videoHashes[videoHash] {
                            assets.append(asset)
                            videoHashes[videoHash] = assets
                        } else {
                            videoHashes[videoHash] = [asset]
                        }
                    }
                }
                return videoHashes
            }
            
//            try? storageManager?.store(videoHashes, forKey: "duplicate_videos", expiration: .days(1))
//        }
        
        // Фильтрация дубликатов (видео с одинаковыми хэшами)
        for (_, ids) in videoHashes {
            if ids.count > 1 {
                let duplicateAssets = ids.compactMap ({ id in assetsArray.first(where: { $0.localIdentifier == id }) })
                duplicateVideos.append(duplicateAssets)
            }
        }
        
        let finishDate = Date().timeIntervalSinceReferenceDate
        print("\n⏰ uplicate videos - \(finishDate - startDate)")
        
        return duplicateVideos
    }
    
    private func sendProcessCounter(_ lower: Int?, _ upper: Int?) {
        DispatchQueue.main.async { [weak self] in
            self?.processCounter.send((lower ?? 0, upper ?? 0))
        }
    }
}

struct SimilarHashType<A: Codable, B: Codable>: Codable {
    
    let first: A?
    let second: B?
    
    init(first: A?, second: B?) {
        self.first = first
        self.second = second
    }

}
