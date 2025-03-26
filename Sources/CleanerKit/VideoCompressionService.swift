//VideoCompressionService.swift
//Cleaner

import Foundation
import Photos
import AVFoundation

public final class VideoCompressionService {
    
    enum VideoQuality: String, CaseIterable, Hashable, Identifiable {
        
        var id: String { rawValue }
        
        case low
        case medium
        case high
        
        var presetName: String {
            switch self {
            case .low:
                return AVAssetExportPresetMediumQuality
            case .medium:
                return AVAssetExportPreset1920x1080
            case .high:
                return AVAssetExportPresetHighestQuality
            }
        }
    }
    
    static let shared = VideoCompressionService()

    private init() { }
    
    public func compressAndReplaceVideo(
        asset: PHAsset,
        quality: VideoQuality = .medium
    ) async throws {
        // Проверяем, что это видео
        guard asset.mediaType == .video else {
            throw NSError(domain: "Not a video asset", code: -1, userInfo: nil)
        }
        
        // Получаем видео в максимальном качестве
        let avAsset = try await requestAVAsset(for: asset)
        
        // Создаем временный URL для экспортированного видео
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        // Проверяем, поддерживается ли пресет
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: quality.presetName) else {
            throw NSError(domain: "Could not create export session", code: -3, userInfo: nil)
        }
        
        // Настраиваем экспорт сессии
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = true
        
        // Оборачиваем экспорт в Task для поддержки отмены
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(throwing: exportSession.error ?? NSError(domain: "Export failed", code: -4, userInfo: nil))
                default:
                    break
                }
            }
        }
        
        // Заменяем оригинальное видео сжатым
        try await replaceVideoResource(for: asset, with: outputURL)
        
        // Удаляем временный файл
        try? FileManager.default.removeItem(at: outputURL)
    }

    private func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .original
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: NSError(domain: "Could not get AVAsset", code: -2, userInfo: nil))
                }
            }
        }
    }

    private func replaceVideoResource(for asset: PHAsset, with fileURL: URL) async throws {
                
        try await withCheckedThrowingContinuation { continuation in
            
            PHPhotoLibrary.shared().performChanges({
                // Получаем тип ресурса видео
                let resourceType = PHAssetResourceType.video
                
                // Получаем ресурсы для этого ассета
                let resources = PHAssetResource.assetResources(for: asset)
                
                // Находим оригинальный видео ресурс
                guard resources.contains(where: { $0.type == resourceType }) else {
                    continuation.resume()
                    return
                }
                
                // Удаляем оригинальный ресурс
                PHAssetChangeRequest.deleteAssets([asset] as NSArray)
                
                // Создаем новый ассет с сжатым видео
                PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                
            }, completionHandler: { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: NSError(domain: "Replace failed", code: -6, userInfo: nil))
                } else {
                    continuation.resume()
                }
            })
        }
    }}
