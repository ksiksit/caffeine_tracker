//
//  DrinkPreset.swift
//  captest1
//

import Foundation

struct DrinkPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let caffeineAmount: Int

    static let all: [DrinkPreset] = [
        DrinkPreset(name: "아메리카노", icon: "cup.and.saucer.fill", caffeineAmount: 150),
        DrinkPreset(name: "에스프레소", icon: "cup.and.saucer.fill", caffeineAmount: 75),
        DrinkPreset(name: "라떼", icon: "cup.and.saucer.fill", caffeineAmount: 150),
        DrinkPreset(name: "녹차", icon: "leaf.fill", caffeineAmount: 30),
        DrinkPreset(name: "홍차", icon: "leaf.fill", caffeineAmount: 50),
        DrinkPreset(name: "콜라", icon: "waterbottle.fill", caffeineAmount: 35),
        DrinkPreset(name: "에너지드링크", icon: "bolt.fill", caffeineAmount: 80),
    ]
}
