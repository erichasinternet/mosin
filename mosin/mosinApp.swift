//
//  mosinApp.swift
//  mosin
//
//  Created by Eric Lawson on 8/18/25.
//

import SwiftUI
import SwiftData

@main
struct mosinApp: App {
    @StateObject private var menuBarController = MenuBarController()
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
