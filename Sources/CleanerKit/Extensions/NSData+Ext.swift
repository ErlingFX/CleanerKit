//
//  NSData.swift
//  Cleaner
//

import Foundation
import CommonCrypto

extension NSData {
    
    func digest() -> NSData {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var hash = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(self.bytes, UInt32(self.length), &hash)
        return NSData(bytes: hash, length: digestLength)
    }
    
    func hexStringFromData() -> String {
        var bytes = [UInt8](repeating: 0, count: self.length)
        self.getBytes(&bytes, length: self.length)
        var hexString = ""
        
        for byte in bytes {
            hexString += String(format: "%02x", UInt8(byte))
        }
        
        return hexString
    }
    
}
