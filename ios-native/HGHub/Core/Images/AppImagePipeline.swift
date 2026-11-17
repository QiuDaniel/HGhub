import Nuke

/// 统一图片管线：磁盘缓存 200MB + 封面解密解码器。
enum AppImagePipeline {
    static func install() {
        var configuration = ImagePipeline.Configuration.withDataCache(
            name: "hghub.images",
            sizeLimit: 200 * 1024 * 1024
        )
        configuration.makeImageDecoder = { _ in CoverImageDecoder() }
        ImagePipeline.shared = ImagePipeline(configuration: configuration)
    }
}
