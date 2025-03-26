//
//  UIImage+.swift
//  Cleaner
//

import UIKit

extension UIImage {
    
    func sha256() -> String {
        guard let imageData = cgImage?.dataProvider?.data as? Data else {
            return ""
        }
        
        return (imageData as NSData).digest().hexStringFromData()
    }
    
    // Функция для подсчета размера одного изображения в мегабайтах
    func megabytes() -> Double? {
        guard let imageData = self.jpegData(compressionQuality: 1.0) else {
            return nil // Не удалось получить данные изображения
        }
        let bytesInMegabyte = 1024.0 * 1024.0
        let megabytes = Double(imageData.count) / bytesInMegabyte
        return megabytes
    }
}
