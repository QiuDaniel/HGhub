import CryptoSwift
import Foundation
import Testing
@testable import HGHub

struct EdgeEnvelopeTests {
    @Test
    func encodesBodyAsBase64() throws {
        let body = Data("{\"username\":\"demo\"}".utf8)
        let envelope = EdgeEnvelope(method: "POST", path: "/api/account/loginByPassword", body: body)
        let data = try JSONEncoder().encode(envelope)
        let raw = try JSONSerialization.jsonObject(with: data)
        let object = try #require(raw as? [String: String])

        #expect(object["method"] == "POST")
        #expect(object["path"] == "/api/account/loginByPassword")
        #expect(object["body"] == body.base64EncodedString())
        #expect(object["content_type"] == "application/json")
    }

    @Test
    func emptyBodyHasEmptyContentType() throws {
        let envelope = EdgeEnvelope(method: "GET", path: "/api/videos?page=1", body: nil)
        let data = try JSONEncoder().encode(envelope)
        let raw = try JSONSerialization.jsonObject(with: data)
        let object = try #require(raw as? [String: String])

        #expect(object["body"] == "")
        #expect(object["content_type"] == "")
    }
}

struct FeedDecodingTests {
    @Test
    func decodesPagedVideoCards() throws {
        let json = """
        {
          "items": [
            { "id": 1, "title": "第一集", "cover": "https://example.com/a.jpg", "episode_count": 2 }
          ],
          "pagination": { "page": 1, "pages": 1, "size": 10, "total": 1 }
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(Paged<VideoCard>.self, from: Data(json.utf8))

        #expect(page.items.count == 1)
        #expect(page.items.first?.id == 1)
        #expect(page.items.first?.episodeCount == 2)
        #expect(page.pagination.total == 1)
    }

    @Test
    func missingPaginationFallsBack() throws {
        let json = #"{"items":[{"id":7,"title":"t","cover":"c"}]}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(Paged<VideoCard>.self, from: Data(json.utf8))

        #expect(page.pagination.page == 1)
        #expect(page.pagination.total == 1)
    }
}


struct ImageBytesTests {
    @Test
    func passesThroughKnownImages() {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0, count: 12)
        #expect(ImageBytes.isKnownImage(jpeg))
        #expect(!ImageBytes.isKnownImage(Data(repeating: 0x00, count: 16)))
    }

    @Test
    func decryptsNoPaddingCiphertext() throws {
        let plain = Data(repeating: 0x41, count: 16)
        let aes = try AES(key: ImageBytes.key, blockMode: CBC(iv: ImageBytes.iv), padding: .noPadding)
        let cipher = Data(try aes.encrypt(Array(plain)))
        let decrypted = try ImageBytes.decryptCover(cipher)
        #expect(decrypted == plain)
    }
}


private final class BundleToken {}

private enum FixtureError: Error {
    case missing(String)
}

private func fixtureData(_ name: String) throws -> Data {
    let bundle = Bundle(for: BundleToken.self)
    guard let url = bundle.url(forResource: name, withExtension: "json") else {
        throw FixtureError.missing(name)
    }
    return try Data(contentsOf: url)
}

struct RealFixtureTests {
    @Test
    func decodesRealFeed() throws {
        let data = try fixtureData("feed_page1")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(Paged<VideoCard>.self, from: data)

        #expect(page.items.count == 10)
        #expect(page.pagination.page == 1)
        #expect(page.pagination.pages > 1)
        #expect(page.items.first?.title?.isEmpty == false)
        #expect(page.items.first?.cover?.hasPrefix("https://") == true)
    }
}
