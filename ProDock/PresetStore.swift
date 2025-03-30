//
//  PresetStore.swift
//  ProDock
//
//  Created by Akshay Mishra on 30/03/25.
//


import Foundation

class PresetStore: ObservableObject {
    @Published var presets: [DockPreset] = []

    private static func fileURL() throws -> URL {
        // Standard location for app-specific support files
        let fileManager = FileManager.default
        let supportURL = try fileManager.url(for: .applicationSupportDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true) // Ensure directory exists
        
        // Create a subdirectory for your app
        let appSupportURL = supportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "ProDock")
        try fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)

        return appSupportURL.appendingPathComponent("presets.json")
    }

    // Load presets from JSON file
    func load() {
        do {
            let url = try Self.fileURL()
            // Ensure the file exists before trying to read
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Presets file not found, starting fresh.")
                self.presets = []
                return
            }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.presets = try decoder.decode([DockPreset].self, from: data)
            print("Loaded \(self.presets.count) presets from \(url.path)")
        } catch {
            // Handle errors gracefully (e.g., corrupted file, permissions)
            print("Error loading presets: \(error.localizedDescription)")
            // Optionally: Present an alert to the user
            self.presets = [] // Start with an empty list on error
        }
    }

    // Save presets to JSON file
    func save() {
        do {
            let url = try Self.fileURL()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted // Make it human-readable
            let data = try encoder.encode(self.presets)
            try data.write(to: url, options: [.atomicWrite]) // Atomic write is safer
            print("Saved \(self.presets.count) presets to \(url.path)")
        } catch {
            print("Error saving presets: \(error.localizedDescription)")
            // Optionally: Present an alert to the user
        }
    }
    
    // Add a preset and save
    func addPreset(_ preset: DockPreset) {
        // Avoid duplicates by name? Or allow them? For now, allow.
        presets.append(preset)
        save()
    }
    
    // Delete a preset and save
    func deletePreset(withId id: UUID) {
        presets.removeAll { $0.id == id }
        save()
    }
    
    // Delete presets using offsets (useful for List onDelete)
    func deletePresets(at offsets: IndexSet) {
         presets.remove(atOffsets: offsets)
         save()
     }
}
