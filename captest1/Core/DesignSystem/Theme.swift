//
//  Theme.swift
//  captest1
//
//  디자인 토큰(색·글꼴·간격). 화면에서 색이나 크기를 직접 쓰지 말고 여기 값을 쓴다.
//  방향: 흰 바탕 + 구분선 + 신호색 1개("타임라인 미니멀"). 색은 Assets에 라이트/다크 쌍으로 있다.
//

import SwiftUI

enum Theme {

    // MARK: - 색

    enum Colors {
        /// 본문 텍스트·주요 버튼·차트 실선
        static let ink = Color("Ink")
        /// 보조 텍스트(라벨·캡션·단위)
        static let inkSecondary = Color("InkSecondary")
        /// 행 사이 구분선·테두리
        static let hairline = Color("Hairline")
        /// 화면 배경
        static let canvas = Color("Canvas")
        /// 입력 칸·배너 같은 옅은 면
        static let surfaceMuted = Color("SurfaceMuted")

        /// 강조색. 미니멀 방향에서는 잉크색을 강조로 쓴다(기존 EspressoBrown 자리).
        static let accent = ink
        /// 강조색 위에 올리는 글자·아이콘(라이트: 흰색, 다크: 잉크)
        static let onAccent = Color("OnAccent")

        /// 신호: 마셔도 괜찮음 / 곧 마감 / 패스·오류
        static let signalOK = Color("SignalOK")
        static let signalWarn = Color("SignalWarn")
        static let signalStop = Color("SignalStop")

        /// 수면 단계 데이터 색(단계 막대·범례 전용). 시스템 색이라 다크 모드에서 자동으로 밝아진다.
        enum SleepStage {
            static let inBed = Color.gray
            static let awake = Color.orange
            static let core = Color.blue
            static let deep = Color.indigo
            static let rem = Color.purple
            static let unspecified = Color.cyan
        }
    }

    // MARK: - 글꼴

    enum Fonts {
        /// 화면 맨 위 핵심 숫자(수면 시간·반감기)
        static let heroNumber = Font.system(size: 52, weight: .bold).monospacedDigit()
        /// 화면 맨 위 핵심 문장("오후 3:20까지 한 잔은 괜찮아요")
        static let heroTitle = Font.system(size: 28, weight: .bold)
        /// 지표 줄의 숫자
        static let metricValue = Font.system(size: 24, weight: .bold).monospacedDigit()
        /// 섹션 제목("오늘 기록")
        static let sectionTitle = Font.footnote.weight(.semibold)
        /// 라벨·단위
        static let caption = Font.caption
        /// 칸이 좁은 차트의 세로 축 라벨(히스토그램 구간 등)
        static let chartAxisDense = Font.system(size: 8)
    }

    // MARK: - 간격

    enum Spacing {
        /// 화면 좌우 여백
        static let screen: CGFloat = 24
        /// 섹션 사이
        static let section: CGFloat = 24
        /// 리스트 행 위아래
        static let row: CGFloat = 12
        /// 입력 칸·배너 안쪽 여백
        static let field: CGFloat = 12
    }

    // MARK: - 모서리

    enum Radius {
        /// 주요 버튼·아웃라인 버튼
        static let button: CGFloat = 14
        /// 선택 타일·입력 묶음 상자
        static let tile: CGFloat = 12
        /// 입력 칸·배너
        static let field: CGFloat = 10
        /// 막대 그래프 조각
        static let bar: CGFloat = 2
    }

    // MARK: - 크기

    enum Size {
        /// 주요 버튼 높이
        static let primaryButton: CGFloat = 52
        /// 최소 터치 영역(HIG)
        static let minTouch: CGFloat = 44
    }
}
