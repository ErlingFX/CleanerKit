//
//  StorageUsageService.swift
//  Cleaner
//
//

import Foundation
import Photos

public final class StorageUsageService: NSObject, ObservableObject {
        
    static let shared = StorageUsageService()

    @Published var totalMediaCount: Int = 0
    @Published var totalPhotoCount: Int = 0
    @Published var totalVideoCount: Int = 0
    
    @Published var totalStorageSpace: Double = 0
    
    @Published var usedStorageSpace: Double = 0
    @Published var usedPhotoSpace: Double = 0
    @Published var usedVideoSpace: Double = 0
        
    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
        fetchData()
    }
}

private extension StorageUsageService {
    
    func fetchData() {
        fetchStorageInfo()
        getTotalMediaCount()
    }
    
    func fetchStorageInfo() {
        let fileManager = FileManager.default
        let systemAttributes = try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
        
        guard
            let totalSpace = systemAttributes?[.systemSize] as? Double,
            let freeSpace = systemAttributes?[.systemFreeSize] as? Double
        else { return }
        
        let usedSpace = totalSpace - freeSpace
        
        self.totalStorageSpace = (totalSpace / 1_073_741_824.0) // Convert to GB
        self.usedStorageSpace = (usedSpace / 1_073_741_824.0)
    }
    
    func getTotalMediaCount() {
        Task(priority: .userInitiated) { @MainActor in
            let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            guard status == .authorized else {
                return
            }
            await fetchMediaCountInBackground()
        }
    }

    func fetchMediaCountInBackground() async {
        let photos = PHAsset.fetchAssets(with: .image, options: nil)
        let photosArray = photos.objects(at: IndexSet(0..<photos.count))
        
        let videos = PHAsset.fetchAssets(with: .video, options: nil)
        let videosArray = videos.objects(at: IndexSet(0..<videos.count))

        totalMediaCount = photos.count + videos.count
        totalPhotoCount = photos.count
        totalVideoCount = videos.count
        usedPhotoSpace = await photosArray.getTotalImageMegabytes()
        usedVideoSpace = await videosArray.getTotalVideoMegabytes()
    }
}

extension StorageUsageService: PHPhotoLibraryChangeObserver {
    
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        fetchData()
    }
}
