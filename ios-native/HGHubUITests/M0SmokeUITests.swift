import XCTest

final class M0SmokeUITests: XCTestCase {
    private func openContractCheck(_ app: XCUIApplication) {
        let more = app.buttons["更多"]
        XCTAssertTrue(more.waitForExistence(timeout: 10), "首页应显示更多菜单")
        more.tap()

        let entry = app.buttons["M0 契约自检"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "更多菜单应有 M0 自检入口")
        entry.tap()
    }

    func testHomeFeedCardsLoad() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "首页应通过代理加载视频卡片")
        XCTAssertTrue(card.isHittable, "首张卡片应可点击")
    }

    func testOpenFirstVideoShowsFeed() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30), "首页应有视频卡片")
        card.tap()

        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10), "应进入全屏 Feed")
        XCTAssertTrue(app.buttons["playerMute"].waitForExistence(timeout: 10), "播放器控件应出现")
        XCTAssertTrue(app.buttons["playerEpisodes"].exists)
        XCTAssertTrue(app.buttons["playerFullscreen"].exists)

        // 留出 HLS 起播时间，方便失败时从测试日志/截图定位。
        Thread.sleep(forTimeInterval: 12)
        XCTAssertFalse(app.buttons["playerRetry"].exists, "播放不应在 12s 内进入错误态")
    }

    func testFeedSheetsAndFullscreen() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))

        app.buttons["playerEpisodes"].tap()
        let ep2 = app.buttons["episode_2"]
        XCTAssertTrue(ep2.waitForExistence(timeout: 5), "选集面板应有第 2 集")
        ep2.tap()

        let badge = app.buttons["playerEpisodeBadge"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        XCTAssertTrue(badge.label.contains("2"), "切集后应显示第 2 集")

        app.buttons["playerComments"].tap()
        XCTAssertTrue(app.navigationBars["评论"].waitForExistence(timeout: 5))
        app.buttons["关闭"].tap()

        app.buttons["playerFullscreen"].tap()
        XCTAssertTrue(app.buttons["关闭全屏"].waitForExistence(timeout: 5), "应进入全屏")
        app.buttons["关闭全屏"].tap()
        XCTAssertTrue(app.buttons["playerMute"].waitForExistence(timeout: 5), "退出全屏应回到 Feed")
    }

    func testFeedSwipeChangesVideo() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))

        app.swipeUp()
        let second = app.staticTexts["高三爱情故事"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 10), "上滑后应切到第二条视频")
        XCTAssertTrue(app.buttons["feedClose"].exists)
        Thread.sleep(forTimeInterval: 4)
        XCTAssertFalse(app.buttons["playerRetry"].exists, "切条后播放不应进入错误态")
    }

    func testDetailCommentsAndLoginGate() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playerDetail"].waitForExistence(timeout: 10))

        app.buttons["playerDetail"].tap()
        XCTAssertTrue(app.navigationBars["详情"].waitForExistence(timeout: 10), "应打开详情面板")
        XCTAssertTrue(app.staticTexts["简介"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["已完结"].waitForExistence(timeout: 10), "详情接口应加载出连载状态")
        app.buttons["关闭"].tap()

        XCTAssertTrue(app.buttons["playerComments"].waitForExistence(timeout: 5))
        app.buttons["playerComments"].tap()
        XCTAssertTrue(app.navigationBars["评论"].waitForExistence(timeout: 10), "应打开评论面板")
        let total = app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH '条评论'")
        ).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 15), "评论列表应加载")
        let loginGate = app.buttons["commentLogin"]
        XCTAssertTrue(loginGate.waitForExistence(timeout: 5), "未登录时评论输入应显示登录入口")
        loginGate.tap()

        XCTAssertTrue(app.navigationBars["登录"].waitForExistence(timeout: 10), "评论登录拦截应弹登录")
    }

    func testPlayerLikeRequiresLogin() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["playerLike"].waitForExistence(timeout: 10))
        app.buttons["playerLike"].tap()
        XCTAssertTrue(app.navigationBars["登录"].waitForExistence(timeout: 10), "未登录点赞应先弹登录")
    }

    func testPlayerTapPausesAndDoubleTapLikes() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playerMute"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 6)

        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.tap()
        XCTAssertTrue(app.buttons["playerToggle"].waitForExistence(timeout: 5), "单击应暂停并显示播放按钮")
        app.buttons["playerToggle"].tap()
        XCTAssertTrue(app.buttons["playerToggle"].waitForNonExistence(timeout: 5), "再次点击应继续播放")

        center.doubleTap()
        XCTAssertTrue(
            app.navigationBars["登录"].waitForExistence(timeout: 10),
            "未登录双击喜欢应先弹登录"
        )
    }

    func testResumeFromHistory() {
        let app = XCUIApplication()
        app.launch()

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'videoCard_'")
        ).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playerMute"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 8)

        app.buttons["feedClose"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10), "关闭后应回首页")
        card.tap()
        XCTAssertTrue(app.buttons["feedClose"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["playerMute"].waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 8)

        let progress = app.descendants(matching: .any)
            .matching(identifier: "playerProgress")
            .firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "播放器应有进度元素")
        let value = progress.value as? String ?? ""
        XCTAssertFalse(value.hasPrefix("00:00"), "重进应按历史秒数恢复，实际进度：\(value)")
    }

    func testFeedLoadsThroughSystemProxy() {
        let app = XCUIApplication()
        app.launch()
        openContractCheck(app)

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
        openContractCheck(app)

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
        let login = app.buttons["profileLogin"]
        XCTAssertTrue(login.waitForExistence(timeout: 10), "未登录时我的页应有登录入口")
        login.tap()

        XCTAssertTrue(app.navigationBars["登录"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["loginUsername"].exists)
        XCTAssertTrue(app.secureTextFields["loginPassword"].exists)
        XCTAssertFalse(app.buttons["loginSubmit"].isEnabled, "空表单登录按钮应禁用")
        XCTAssertTrue(app.buttons["关闭"].exists)
    }

    func testContractCheckOpens() {
        let app = XCUIApplication()
        app.launch()
        openContractCheck(app)

        XCTAssertTrue(
            app.navigationBars["M0 契约自检"].waitForExistence(timeout: 5),
            "点击后应打开契约自检页"
        )
    }
}
