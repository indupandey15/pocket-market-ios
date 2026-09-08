//
//  PocketMarketApp.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//

import SwiftUI

@main
struct PocketMarketApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
