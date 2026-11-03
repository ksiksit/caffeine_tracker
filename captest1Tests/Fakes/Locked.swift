//
//  Locked.swift
//  captest1Tests
//
//  페이크의 호출 기록을 여러 Task에서 안전하게 쌓기 위한 잠금 래퍼(SleepStore는 날짜별로 병렬 호출한다).
//

import Foundation

@propertyWrapper
final class Locked<Value>: @unchecked Sendable {
    private var value: Value
    private let lock = NSLock()

    init(wrappedValue: Value) {
        value = wrappedValue
    }

    var wrappedValue: Value {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }

    var projectedValue: Locked<Value> { self }

    func mutate(_ body: (inout Value) -> Void) {
        lock.withLock { body(&value) }
    }
}

struct FakeError: Error, Equatable {}
