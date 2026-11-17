import XCTest

final class M0SmokeUITests: XCTestCase {
    func testFeedLoadsThroughSystemProxy() {
        let app = XCUIApplication()
        app.launch()

        let entry = app.buttons["M0 契约自检"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "首页应显示 M0 自检入口")
        entry.tap()

        let feed = app.buttons["Feed 第 1 页"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5), "自检页应有 Feed 按钮")
        feed.tap()

        let success = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH '✅'"))
            .firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 30), "Feed 应通过系统代理加载成功")
    }

    func testPlaybackLoadsThroughSystemProxy() {
        let app = XCUIApplication()
        app.launch()

        let entry = app.buttons["M0 契约自检"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10), "首页应显示 M0 自检入口")
        entry.tap()

        let playback = app.buttons["Playback 117 / 第 3 集"]
        XCTAssertTrue(playback.waitForExistence(timeout: 5), "自检页应有 Playback 按钮")
        playback.tap()

        let success = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH '✅ url='"))
            .firstMatch
        XCTAssertTrue(success.waitForExistence(timeout: 30), "Playback 应通过系统代理返回播放地址")
    }

    func testContractCheckOpens() {
        let app = XCUIApplication()
        app.launch()

        let button = app.buttons["M0 契约自检"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "首页应显示 M0 自检入口")
        button.tap()

        XCTAssertTrue(
            app.navigationBars["M0 契约自检"].waitForExistence(timeout: 5),
            "点击后应打开契约自检页"
        )
    }
}
