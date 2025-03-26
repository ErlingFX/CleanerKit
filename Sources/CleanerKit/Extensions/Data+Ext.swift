//
//  Data+.swift
//  Cleaner
//

import Foundation

extension Data {
    
    func sha256() -> String {
        let nsData = self as NSData
        return nsData.digest().hexStringFromData()
    }
    
}
