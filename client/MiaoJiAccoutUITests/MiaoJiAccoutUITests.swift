//
//  MiaoJiAccoutUITests.swift
//  MiaoJiAccoutUITests
//
//  Created by 清眸 on 2026/6/9.
//

import XCTest

final class MiaoJiAccoutUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshot-demo-data",
            "-AppleLanguages", "(zh-Hans)",
            "-AppleLocale", "zh_CN"
        ]
        app.launch()

        capture(app, name: "01-首页-语音与手动记账")
        for (tab, name) in [
            ("统计", "02-统计-消费趋势"),
            ("历史", "03-历史-账目时间线")
        ] {
            let button = app.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 3))
            button.tap()
            capture(app, name: name)
        }

        let settingsButton = app.buttons["设置"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()
        capture(app, name: "04-设置-同步与隐私")
    }

    /// Walks the exact path App Review follows, on iPad. Build 1.0 (6) was
    /// rejected here: a wrong password surfaced only "云同步请求失败（HTTP 400）",
    /// which told the reviewer nothing. Credentials come from the environment so
    /// they never enter the repository, and the test skips when they are absent
    /// (Xcode Cloud has none). To run it locally:
    ///
    ///     TEST_RUNNER_MIAOJI_REVIEW_EMAIL=... \
    ///     TEST_RUNNER_MIAOJI_REVIEW_PASSWORD=... \
    ///     xcodebuild test -project MiaoJiAccout.xcodeproj -scheme MiaoJiAccout \
    ///       -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)'
    @MainActor
    func testReviewerCanSignInAndSeesRealErrorsOnFailure() throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let email = environment["MIAOJI_REVIEW_EMAIL"],
            let password = environment["MIAOJI_REVIEW_PASSWORD"],
            !email.isEmpty, !password.isEmpty
        else {
            // Xcode Cloud has no credentials, so this must skip rather than fail.
            throw XCTSkip("set TEST_RUNNER_MIAOJI_REVIEW_EMAIL and TEST_RUNNER_MIAOJI_REVIEW_PASSWORD to run the reviewer sign-in check")
        }

        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        // A rejected credential must name the real reason, not the HTTP status.
        openPasswordLogin(in: app, email: email, password: password + "wrong")
        XCTAssertTrue(app.buttons["登录并开始同步"].isEnabled, "sign-in stayed disabled")
        tapAfterScrollingIntoView(app.buttons["登录并开始同步"], in: app)

        let alert = app.alerts["登录失败"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        let message = alert.staticTexts.element(boundBy: 1).label
        capture(app, name: "登录失败-真实原因")
        XCTAssertTrue(
            message.contains("邮箱或密码不正确"),
            "expected the decoded reason, got: \(message)"
        )
        XCTAssertFalse(message.contains("HTTP 400"), "the raw status leaked again: \(message)")
        alert.buttons["知道了"].tap()

        // A failed sign-in must leave the app signed out, not stuck on
        // "同步失败" for an account that never existed.
        app.buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["本地模式"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "同步失败")
        ).element.exists)

        // The correct credential signs in and reaches the synced state.
        openPasswordLogin(in: app, email: email, password: password)
        tapAfterScrollingIntoView(app.buttons["登录并开始同步"], in: app)

        let signedIn = app.staticTexts[email]
        XCTAssertTrue(signedIn.waitForExistence(timeout: 30), "did not reach the signed-in state")
        capture(app, name: "登录成功")
        XCTAssertFalse(app.staticTexts["本地模式"].exists)
    }

    /// Fills the sign-in sheet top to bottom: scrolling down to the consents
    /// pushes the fields off-screen, so they must be typed first.
    private func openPasswordLogin(in app: XCUIApplication, email: String, password: String) {
        let settingsTab = app.buttons["设置"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        // The Keychain session survives a reinstall-free rerun, so start from a
        // signed-out state instead of depending on a freshly installed app.
        let signOutButton = app.buttons["退出云同步账号"]
        if signOutButton.waitForExistence(timeout: 3) {
            signOutButton.tap()
        }

        let loginButton = app.buttons["登录并开启云同步"]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        let passwordTab = app.segmentedControls.buttons["邮箱密码"]
        XCTAssertTrue(passwordTab.waitForExistence(timeout: 10))
        passwordTab.tap()

        let emailField = app.textFields["name@example.com"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        app.typeText(email)
        dismissKeyboard(in: app)

        let passwordField = app.secureTextFields["密码"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        app.typeText(password)
        dismissKeyboard(in: app)

        // Both consents are mandatory before the sign-in button enables. Match
        // them by label: an unscoped switch query also finds the Settings
        // toggles behind the sheet, which can never be hittable. On the narrower
        // iPhone sheet they also start below the fold.
        for label in ["我已阅读并同意隐私政策和用户协议", "我单独同意将邮箱"] {
            let consent = app.switches.matching(
                NSPredicate(format: "label BEGINSWITH %@", label)
            ).firstMatch
            XCTAssertTrue(consent.waitForExistence(timeout: 5), "missing consent toggle: \(label)")
            for _ in 0..<3 where consent.value as? String != "1" {
                scrollIntoView(consent, in: app)
                // The toggle's frame spans the whole row, so a centred tap lands
                // on the label and does nothing. Aim at the switch control.
                consent.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
            XCTAssertEqual(consent.value as? String, "1", "consent did not turn on: \(label)")
        }
    }

    /// Taps an element that exists but may be scrolled out of the visible area.
    private func tapAfterScrollingIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        scrollIntoView(element, in: app)
        element.tap()
    }

    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            dismissKeyboard(in: app)
            scrollableContent(of: app).swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTFail("\(element) never became hittable")
    }

    /// The keyboard can cover the consent switches and the sign-in button on the
    /// shorter iPhone sheet, which leaves them present but not hittable.
    private func dismissKeyboard(in app: XCUIApplication) {
        guard app.keyboards.element.exists else { return }
        for label in ["换行", "完成", "return", "Return", "done", "Done"] {
            let key = app.keyboards.buttons[label]
            if key.exists && key.isHittable {
                key.tap()
                return
            }
        }
        app.staticTexts["授权与跨境传输"].tap()
    }

    private func scrollableContent(of app: XCUIApplication) -> XCUIElement {
        for candidate in [app.collectionViews.firstMatch, app.tables.firstMatch, app.scrollViews.firstMatch]
        where candidate.exists {
            return candidate
        }
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
