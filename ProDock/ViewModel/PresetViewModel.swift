// PresetViewModel.swift

import SwiftUI
import Combine
import AppKit // For NSEvent

// Keep the helper function outside or move to a dedicated file if preferred
@MainActor
internal func checkAccessibilityPermission() -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    let isTrusted = AXIsProcessTrustedWithOptions(options)
    print("Accessibility Check Result (Helper): \(isTrusted)")
    return isTrusted
}

@MainActor
class PresetViewModel: ObservableObject {

    // MARK: - Published Properties for UI Binding
    @Published var presetStore = PresetStore()
    @Published var newPresetName: String = ""
    @Published var isLoading: Bool = false
    @Published var statusMessage: String = "" // Can be displayed somewhere if needed
    @Published var errorMessage: String = ""  // Can be displayed somewhere if needed
    @Published var showErrorAlert: Bool = false
    @Published var accessibilityGranted: Bool = false // Updated by the check
    @Published var selectedPresetForEditing: DockPreset? = nil // For future edit pane

    // MARK: - Private Properties
    private let dockutilService = DockutilService()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    // MARK: - Initialization
    init() {
        presetStore.load()
        setupDebounceTimers()
        // Initial check on launch (can also be triggered from View's onAppear)
        self.accessibilityGranted = checkAccessibilityPermission()
    }

    private func setupDebounceTimers() {
        // Debounce logic for status/error messages remains,
        // but their display is removed from ContentView for now.
        // They can be re-added later, perhaps as overlays or toasts.
        $statusMessage
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.statusMessage = "" }
            .store(in: &cancellables)

        $errorMessage
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                 if !(self?.showErrorAlert ?? false) { self?.errorMessage = "" }
            }
            .store(in: &cancellables)

        $showErrorAlert
            .filter { !$0 }
            .sink { [weak self] _ in self?.errorMessage = "" }
            .store(in: &cancellables)
    }

    // MARK: - Accessibility and Global Hotkey Setup

    func checkAndSetupGlobalKeyListener() {
        guard eventMonitor == nil else {
            print("Event monitor setup already attempted.")
            // Re-check permission in case it changed while app was running
            self.accessibilityGranted = checkAccessibilityPermission()
            // If it was just granted, try setting up monitor again (optional)
            // if self.accessibilityGranted { setupMonitor() }
            return
        }

        self.accessibilityGranted = checkAccessibilityPermission()

        if accessibilityGranted {
            print("Accessibility access granted. Setting up global monitor.")
            setupMonitor()
        } else {
            print("Accessibility access denied. Global shortcuts inactive.")
            // Optionally remind user or guide them?
        }
    }

    private func setupMonitor() {
        // Ensure previous monitor is removed if this is called again
        removeGlobalKeyListener()

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            // --- Shortcut Mapping Logic ---
            // TODO: This needs significant rework to map specific shortcuts
            //       stored in presets (DockPreset.shortcut) to actions.
            //       The current hardcoded example remains for now.

            let desiredModifiers: NSEvent.ModifierFlags = [.command, .option]
            let desiredKeyCode: UInt16 = 12 // Q key

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == desiredModifiers && event.keyCode == desiredKeyCode {
                print("Global Shortcut (Hardcoded ⌘⌥Q) Detected!")
                if let presetToApply = self.presetStore.presets.first {
                    print("Applying preset via shortcut: \(presetToApply.name)")
                    self.applyPreset(presetToApply)
                } else {
                    print("Shortcut triggered, but no presets found.")
                }
            }
            // --- End Shortcut Mapping Logic ---
        }

        if eventMonitor == nil {
            presentError("Failed to install global event monitor even with permissions.")
        } else {
             print("Global event monitor installed successfully.")
        }
    }


    func removeGlobalKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("Global event monitor removed.")
        }
    }

    // MARK: - Core Actions

    func saveCurrentDock() {
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presentError("Please enter a name for the preset.")
            return
        }
        guard !isLoading else { return }

        isLoading = true
        // statusMessage = "Reading current Dock..." // Display elsewhere if needed
        errorMessage = ""

        Task {
            defer { isLoading = false }

            let listResult = dockutilService.listItems()

            switch listResult {
            case .success(let parsedItems):
                let addCommands = parsedItems.map { dockutilService.constructAddCommandFragment(for: $0) }
                guard !addCommands.isEmpty else {
                     presentError("Could not read any items from the Dock.")
                     return
                }

                // Create preset without a shortcut for now
                let newPreset = DockPreset(name: trimmedName, addCommandFragments: addCommands, shortcut: nil)
                presetStore.addPreset(newPreset)

                // statusMessage = "Preset '\(trimmedName)' saved." // Display elsewhere
                newPresetName = ""

            case .failure(let error):
                presentError("Failed to read Dock: \(error.localizedDescription)")
            }
        }
    }

    func applyPreset(_ preset: DockPreset) {
        guard !isLoading else { return }
        selectedPresetForEditing = nil // Clear selection when applying
        isLoading = true
        // statusMessage = "Applying preset '\(preset.name)'..." // Display elsewhere
        errorMessage = ""

        Task {
             defer { isLoading = false }

            let removeResult = dockutilService.removeAll(noRestart: true)
            guard case .success = removeResult else {
                // Error handling...
                presentError("Failed to clear Dock" + extractError(removeResult))
                return
            }

            var allItemsAddedSuccessfully = true
            for (index, commandFragment) in preset.addCommandFragments.enumerated() {
                let addResult = dockutilService.addItem(commandFragment: commandFragment, noRestart: true)
                if case .failure = addResult {
                     presentError("Failed to add item (\(index+1)): \(commandFragment)" + extractError(addResult))
                     allItemsAddedSuccessfully = false
                     break // Stop adding if one fails
                 }
            }

            if allItemsAddedSuccessfully {
                let restartResult = dockutilService.restartDock()
                if case .failure = restartResult {
                    // Handle restart failure (maybe less critical)
                    presentError("Preset applied, but Dock restart failed." + extractError(restartResult))
                } else {
                     // statusMessage = "Preset '\(preset.name)' applied." // Display elsewhere
                }
            }
             // Error messages handled by presentError
        }
    }

    // Placeholder for future edit action
    func editPreset(_ preset: DockPreset) {
        print("Attempting to edit preset: \(preset.name)")
        selectedPresetForEditing = preset
        // The right pane in ContentView will react to this change
    }

    // Placeholder for future duplicate action
    func duplicatePreset(_ preset: DockPreset) {
        print("Attempting to duplicate preset: \(preset.name)")
        var duplicatedPreset = preset // Create a copy
        duplicatedPreset.id = UUID() // Assign a new ID
        duplicatedPreset.name = "\(preset.name) Copy" // Append "Copy"
        // duplicatedPreset.shortcut = nil // Decide if shortcut should be copied
        presetStore.addPreset(duplicatedPreset)
        // statusMessage = "Preset '\(preset.name)' duplicated."
    }


    func deletePreset(_ preset: DockPreset) {
        presetStore.deletePreset(withId: preset.id)
        if selectedPresetForEditing?.id == preset.id {
            selectedPresetForEditing = nil // Clear selection if deleted
        }
        // statusMessage = "Preset '\(preset.name)' deleted." // Display elsewhere
    }

    // Keep this for potential swipe-to-delete if List allows it with custom rows
    func deletePresets(at offsets: IndexSet) {
        let presetsToDelete = offsets.map { presetStore.presets[$0] }
        presetStore.deletePresets(at: offsets)
        for preset in presetsToDelete {
            if selectedPresetForEditing?.id == preset.id {
                selectedPresetForEditing = nil
                break
            }
        }
        // statusMessage = "Deleted presets."
    }

    // MARK: - Private Helpers
    private func presentError(_ message: String) {
        print("❌ Error Presented: \(message)")
        // Update published properties for alert
        self.errorMessage = message
        self.showErrorAlert = true // Trigger the alert in ContentView
        // Also potentially log to a file or analytics
    }

    // Helper to extract error description from Result
    private func extractError<T>(_ result: Result<T, DockutilError>) -> String {
        if case .failure(let error) = result {
            return ": \(error.localizedDescription)"
        }
        return "."
    }

} // End of PresetViewModel class
