//
//  DockPreset.swift
//  ProDock
//
//  Created by Akshay Mishra on 30/03/25.
//


import Foundation

// Represents a single Dock preset
struct DockPreset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    // Store the list of 'dockutil --add' command fragments needed to recreate the preset
    var addCommandFragments: [String]
    // New: Optional property to store a user-defined shortcut string representation
    var shortcut: String? // e.g., "⌘⌥Q", "⌃⇧A" - Not functional yet, just for display
}
