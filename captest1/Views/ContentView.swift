//
//  ContentView.swift
//  captest1
//
//  Created by 김종범 on 3/24/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab(String(localized: "tab.home"), systemImage: "cup.and.saucer.fill", value: 0) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab(String(localized: "tab.sleepAnalysis"), systemImage: "moon.zzz.fill", value: 1) {
                NavigationStack {
                    SleepAnalysisView()
                }
            }

            Tab(String(localized: "tab.settings"), systemImage: "gearshape.fill", value: 2) {
                NavigationStack {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CaffeineRecord.self, inMemory: true)
}
