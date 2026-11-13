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
        XCTAssertTrue(app.navigationBars["홈"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["오늘의 카페인"].exists)
        // 홈 상단 마감 문장 영역이 표시되는지 식별자로 확인한다
        XCTAssertTrue(app.descendants(matching: .any)["caffeineCutoffHero"].waitForExistence(timeout: 2))

        // 수면 분석 탭 전환
        app.tabBars.buttons["수면 분석"].tap()
        XCTAssertTrue(app.navigationBars["수면 분석"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["수면 분석"].exists)

        // 설정 탭 전환
        app.tabBars.buttons["설정"].tap()
        XCTAssertTrue(app.navigationBars["설정"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.staticTexts["카페인 반감기"].waitForExistence(timeout: 2)
            || app.staticTexts["카페인 대사"].exists
        )

        if !app.staticTexts["HealthKit 연동"].exists
            && !app.buttons["HealthKit 연동"].exists
            && !app.staticTexts["HealthKit 접근 요청 완료"].exists
            && !app.staticTexts["건강 데이터 사용 불가"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            app.staticTexts["HealthKit 연동"].exists
            || app.buttons["HealthKit 연동"].exists
            || app.staticTexts["HealthKit 접근 요청 완료"].exists
            || app.staticTexts["건강 데이터 사용 불가"].exists
        )
        // 알림 섹션은 화면 아래쪽에 있다 — 보일 때까지 몇 번만 스크롤한다
        let cutoffToggle = app.switches["섭취 마감 30분 전"]
        for _ in 0..<4 where !cutoffToggle.exists {
            app.swipeUp()
        }
        XCTAssertTrue(cutoffToggle.waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["알림"].exists)

        // 홈 탭으로 복귀
        app.tabBars.buttons["홈"].tap()
        XCTAssertTrue(app.navigationBars["홈"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
