//
//  AppContainer.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Deliberately simple constructor-injection container rather than a
//  framework — appropriate for this app's size, and every dependency here
//  is a protocol, so any of it can be swapped for a fake in tests or
//  SwiftUI previews.
//

import Foundation

@MainActor
final class AppContainer {
    static let shared = AppContainer()
}


