// ProDockApp.swift
import SwiftUI

@main
struct ProDockApp: App {
    // Keep the view model accessible if needed elsewhere later
    @StateObject private var viewModel = PresetViewModel()

    var body: some Scene {
        WindowGroup {
            // Pass the viewModel to the ContentView
            ContentView()
                .environmentObject(viewModel) // Make VM available via environment
        }
        // Optional: Handle app termination notification here if needed
        // .commands {
        //     CommandGroup(replacing: .appTermination) {
        //         Button("Quit ProDock") {
        //             viewModel.cleanupBeforeQuit() // Call cleanup in ViewModel
        //             NSApplication.shared.terminate(nil)
        //         }
        //         .keyboardShortcut("q", modifiers: .command)
        //     }
        // }
    }
}
