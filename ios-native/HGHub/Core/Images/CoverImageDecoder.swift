import Foundation
import Nuke

/// Nuke 解码钩子：先判断是否已是图片，否则按封面 AES 解密后再交给系统解码器。
struct CoverImageDecoder: ImageDecoding {
    func decode(_ data: Data) throws -> ImageContainer {
        let plain = ImageBytes.isKnownImage(data)
            ? data
            : try ImageBytes.decryptCover(data)
        return try ImageDecoders.Default().decode(plain)
    }
}
