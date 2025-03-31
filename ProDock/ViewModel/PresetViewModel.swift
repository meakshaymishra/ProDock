// PresetViewModel.swift

import SwiftUI
import Combine
import AppKit // For NSEvent (not for Accessibility API directly here)

@MainActor
internal func checkAccessibilityPermission() -> Bool {
    // Create the options dictionary using a direct string key instead of the constant
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary

    // Perform the actual permission check.
    let isTrusted = AXIsProcessTrustedWithOptions(options)
    
    // Log the result for debugging.
    print("Accessibility Check Result (Helper): \(isTrusted)")
    
    return isTrusted
}


@MainActor // ViewModel itself runs on the MainActor
class PresetViewModel: ObservableObject {

    // MARK: - Published Properties for UI Binding
    @Published var presetStore = PresetStore()
    @Published var newPresetName: String = ""
    @Published var isLoading: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String = ""
    @Published var showErrorAlert: Bool = false
    @Published var accessibilityGranted: Bool = false // Updated by the check

    // MARK: - Private Properties
    private let dockutilService = DockutilService()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    // MARK: - Initialization
    init() {
        presetStore.load()
        setupDebounceTimers() // Encapsulate debounce setup
    }

    private func setupDebounceTimers() {
        // Automatically clear status message after a delay
        $statusMessage
            .debounce(for: .seconds(5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.statusMessage = "" }
            .store(in: &cancellables)

        // Automatically clear error message after a delay (longer)
        $errorMessage
            .debounce(for: .seconds(10), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                 // Only clear if the alert isn't currently showing the message
                 if !(self?.showErrorAlert ?? false) {
                     self?.errorMessage = ""
                 }
            }
            .store(in: &cancellables)
        
        // Ensure error message is cleared when the alert is dismissed
        $showErrorAlert
            .filter { !$0 } // Only react when showErrorAlert becomes false
            .sink { [weak self] _ in
                 self?.errorMessage = ""
            }
            .store(in: &cancellables)
    }

    // MARK: - Accessibility and Global Hotkey Setup

    /// Checks for Accessibility permissions using a helper and sets up the global key listener if granted.
    /// Should be called from the main view's `.onAppear`.
    func checkAndSetupGlobalKeyListener() {
        // Ensure this setup code runs only once unless explicitly reset
        guard eventMonitor == nil else {
            print("Event monitor setup already attempted or completed.")
            return
        }
        
        // Call the dedicated @MainActor helper function to perform the check
        let appIsTrusted = checkAccessibilityPermission() // Defined in AccessibilityHelper.swift
        self.accessibilityGranted = appIsTrusted         // Update published property

        if appIsTrusted {
            print("Accessibility access granted (ViewModel).")
            
            // Setup the event monitor (also runs on MainActor context)
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                // Event handling code remains the same...
                guard let self = self else { return }
                let desiredModifiers: NSEvent.ModifierFlags = [.command, .option]
                let desiredKeyCode: UInt16 = 12 // Q key KeyCode (Find others using tools like Key Codes app)

                // Check if the event matches the shortcut
                if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == desiredModifiers && event.keyCode == desiredKeyCode {
                    print("Global Shortcut Detected!")

                    // --- Shortcut Mapping Logic ---
                    // TODO: Implement mapping from this specific shortcut to a preset
                    // For now, we just apply the first preset as a demo.
                    if let presetToApply = self.presetStore.presets.first {
                        print("Applying preset via shortcut: \(presetToApply.name)")
                        // `applyPreset` is already MainActor safe
                        self.applyPreset(presetToApply)
                    } else {
                        print("Shortcut triggered, but no presets found to apply.")
                    }
                    // --- End Shortcut Mapping Logic ---
                }
            } // End of event handler closure

            if eventMonitor == nil {
                presentError("Failed to install global event monitor even with permissions.")
            } else {
                 print("Global event monitor installed successfully.")
            }
        } else {
            // Permission denied
            print("Accessibility access denied (ViewModel). Global shortcuts will not work.")
            // UI will show warning based on `accessibilityGranted` state in ContentView
        }
    }

    /// Removes the global keyboard event monitor if it exists.
    /// Should be called when the application is terminating or the feature is disabled.
    func removeGlobalKeyListener() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            print("Global event monitor removed.")
        }
    }

    // MARK: - Core Actions
    // (saveCurrentDock, applyPreset, deletePreset, deletePresets remain unchanged)

    func saveCurrentDock() {
        let trimmedName = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            presentError("Please enter a name for the preset.")
            return
        }
        guard !isLoading else { return }

        isLoading = true
        statusMessage = "Reading current Dock state..."
        errorMessage = ""

        Task {
            defer { isLoading = false } // Ensure isLoading is reset using defer

            let listResult = dockutilService.listItems()

            switch listResult {
            case .success(let parsedItems):
                let addCommands = parsedItems.map { dockutilService.constructAddCommandFragment(for: $0) }
                guard !addCommands.isEmpty else {
                     presentError("Could not read any items from the Dock.")
                     return // isLoading is handled by defer
                }

                let newPreset = DockPreset(name: trimmedName, addCommandFragments: addCommands)
                presetStore.addPreset(newPreset)

                statusMessage = "Preset '\(trimmedName)' saved successfully."
                newPresetName = ""

            case .failure(let error):
                presentError("Failed to read Dock: \(error.localizedDescription)")
            }
        }
    }

    func applyPreset(_ preset: DockPreset) {
        guard !isLoading else { return }

        isLoading = true
        statusMessage = "Applying preset '\(preset.name)'..."
        errorMessage = ""

        Task {
             defer { isLoading = false } // Ensure isLoading is reset using defer

            print("Clearing current Dock items (no restart)...")
            let removeResult = dockutilService.removeAll(noRestart: true)

            guard case .success = removeResult else {
                if case .failure(let error) = removeResult { presentError("Failed to clear Dock: \(error.localizedDescription)") }
                else { presentError("Failed to clear Dock (unknown error).") }
                return // isLoading is handled by defer
            }

            print("Adding items for preset '\(preset.name)' (no restart)...")
            var allItemsAddedSuccessfully = true
            for (index, commandFragment) in preset.addCommandFragments.enumerated() {
                print("  Adding item \(index + 1)/\(preset.addCommandFragments.count): \(commandFragment)")
                let addResult = dockutilService.addItem(commandFragment: commandFragment, noRestart: true)
                if case .failure(let error) = addResult {
                     presentError("Failed to add item (\(commandFragment)): \(error.localizedDescription)")
                     allItemsAddedSuccessfully = false
                     break
                 }
                 // Optional delay if needed: try? await Task.sleep(nanoseconds: 10_000_000)
            }

            if allItemsAddedSuccessfully {
                print("All items added, restarting Dock...")
                let restartResult = dockutilService.restartDock()
                if case .failure(let error) = restartResult {
                    print("Warning: Failed to explicitly restart Dock: \(error.localizedDescription).")
                    statusMessage = "Preset '\(preset.name)' applied, but Dock restart failed (may require manual restart)."
                } else {
                     statusMessage = "Preset '\(preset.name)' applied successfully."
                }
            }
             // Error message set previously if !allItemsAddedSuccessfully
             // isLoading handled by defer
        }
    }

    func deletePreset(_ preset: DockPreset) {
        presetStore.deletePreset(withId: preset.id)
        statusMessage = "Preset '\(preset.name)' deleted."
    }

    func deletePresets(at offsets: IndexSet) {
        let namesToDelete = offsets.map { presetStore.presets[$0].name }.joined(separator: ", ")
        presetStore.deletePresets(at: offsets)
        statusMessage = "Deleted preset(s): \(namesToDelete)."
    }


    // MARK: - Private Helpers
    private func presentError(_ message: String) {
        print("❌ Error Presented: \(message)")
        // Already on MainActor due to class annotation
        self.errorMessage = message
        self.showErrorAlert = true
    }

} // End of PresetViewModel class
