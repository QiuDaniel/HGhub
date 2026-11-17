import CryptoSwift
import Foundation

enum ImageCryptoError: LocalizedError {
    case invalidCiphertext

    var errorDescription: String? {
        switch self {
        case .invalidCiphertext:
            return "封面解密失败"
        }
    }
}

/// 封面是 AES-128-CBC 密文。与 Rust 侧 `media.rs` 的 key/iv/去 padding 行为保持一致。
enum ImageBytes {
    static let key: [UInt8] = Array("f5d965df75336270".utf8)
    static let iv: [UInt8] = Array("97b60394abc2fbe1".utf8)

    static func isKnownImage(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        if data[0] == 0xFF, data[1] == 0xD8 {
            return true
        }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return true
        }
        if data.starts(with: Array("GIF8".utf8)) {
            return true
        }
        if data.starts(with: Array("RIFF".utf8)), data.subdata(in: 8..<12) == Data("WEBP".utf8) {
            return true
        }
        return false
    }

    static func decryptCover(_ data: Data) throws -> Data {
        guard !data.isEmpty, data.count % 16 == 0 else {
            throw ImageCryptoError.invalidCiphertext
        }
        let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .noPadding)
        var plain = Data(try aes.decrypt(Array(data)))
        stripPKCS7(&plain)
        return plain
    }

    private static func stripPKCS7(_ data: inout Data) {
        guard let last = data.last else { return }
        let padding = Int(last)
        guard padding > 0, padding <= 16, data.count >= padding else { return }
        let suffix = data.suffix(padding)
        guard suffix.allSatisfy({ $0 == last }) else { return }
        data.removeLast(padding)
    }
}
