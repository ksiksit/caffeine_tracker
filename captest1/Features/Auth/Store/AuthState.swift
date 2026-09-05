//
//  AuthState.swift
//  captest1
//

import Foundation

enum AuthState: Equatable {
    case checking
    case unauthenticated
    case authenticated(MeResponse)
}
