//
//  ClaudePilotApp.swift
//  ClaudePilot
//
//  Created by 刘卓明 on 2026/4/23.
//

import SwiftUI
import CoreData

@main
struct ClaudePilotApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
