//
//  ResonaApp.swift
//  Resona
//
//  Created by Leon on 7/11/26.
//

import SwiftUI
import SwiftData

@main
struct ResonaApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            return try ResonaModelContainer.make()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
