//
//  captest1UITests.swift
//  captest1UITests
//
//  Created by 김종범 on 3/24/26.
//

import XCTest

final class captest1UITests: XCTestCase {

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
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // 홈 탭이 기본으로 표시되는지 확인
        XCTAssertTrue(app.navigationBars["홈"].exists)
        XCTAssertTrue(app.staticTexts["오늘의 카페인"].exists)
        XCTAssertTrue(app.staticTexts["0 mg"].exists)

        // 수면 분석 탭 전환
        app.tabBars.buttons["수면 분석"].tap()
        XCTAssertTrue(app.navigationBars["수면 분석"].exists)
        XCTAssertTrue(app.staticTexts["수면 분석"].exists)

        // 설정 탭 전환
        app.tabBars.buttons["설정"].tap()
        XCTAssertTrue(app.navigationBars["설정"].exists)
        XCTAssertTrue(app.staticTexts["HealthKit 연동"].exists)
        XCTAssertTrue(app.staticTexts["카페인 알림 설정"].exists)

        // 홈 탭으로 복귀
        app.tabBars.buttons["홈"].tap()
        XCTAssertTrue(app.navigationBars["홈"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
