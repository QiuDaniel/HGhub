import Foundation
import Testing
@testable import HGHub

struct PublishParserTests {
    private let sample = #"""
    var subdomains = [
        'thu',  // 清华
        'pku',  // 北大
    ];
    var urls=[
        'xxbgwypx.cc/',
    ];
    var otherUrls = [
        'https://huangguoai.pages.dev',
    ];
    """#

    @Test
    func parsesScriptAndArrays() {
        let html = #"<link href="publish.css?1"><script src="publish.js?20261118-2"></script>"#
        #expect(PublishParser.scriptSource(in: html) == "publish.js?20261118-2")
        #expect(
            PublishParser.absolute(base: "https://huangguoai.pages.dev/", relative: "publish.js?1")
                == "https://huangguoai.pages.dev/publish.js?1"
        )
        #expect(
            PublishParser.absolute(base: "https://huangguoai.pages.dev/", relative: "/a/b.js")
                == "https://huangguoai.pages.dev/a/b.js"
        )
        #expect(PublishParser.jsArray(sample, declaration: "var urls") == ["xxbgwypx.cc/"])
        #expect(PublishParser.jsArray(sample, declaration: "var subdomains") == ["thu", "pku"])
    }

    @Test
    func buildsMirrorCartesianProduct() throws {
        let urls = try #require(PublishParser.mirrorURLs(js: sample))
        #expect(urls == ["https://thu.xxbgwypx.cc", "https://pku.xxbgwypx.cc"])
    }
}

struct VersionCompareTests {
    @Test
    func comparesNumericSegments() {
        #expect(LiveMaintenanceService.isNewer("v1.2.0", than: "1.1.9"))
        #expect(!LiveMaintenanceService.isNewer("1.0.0", than: "1.0.0"))
        #expect(!LiveMaintenanceService.isNewer("1.0", than: "1.0.1"))
        #expect(LiveMaintenanceService.versionParts("v2.10.3-beta") == [2, 10, 3, 0])
    }
}
