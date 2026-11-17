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

    func testProfileSettingsAndLinePicker() {
        let app = XCUIApplication()
        app.launch()

        let profile = app.tabBars.buttons["我的"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10), "应有我的 Tab")
        profile.tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 5))

        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS '设置'")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5), "我的页应有设置入口")
        settings.tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["深色外观"].waitForExistence(timeout: 5))

        let line = app.buttons.matching(NSPredicate(format: "label CONTAINS '线路'")).firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "设置页应有线路入口")
        line.tap()
        XCTAssertTrue(app.navigationBars["线路"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["关闭"].waitForExistence(timeout: 5))
    }

    func testLoginSheetOpens() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["我的"].tap()
        let login = app.buttons["登录 / 注册"]
        XCTAssertTrue(login.waitForExistence(timeout: 10), "未登录时我的页应有登录入口")
        login.tap()

        XCTAssertTrue(app.navigationBars["登录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["关闭"].exists)
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
