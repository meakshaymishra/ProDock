// PresetViewModel.swift

import AppKit
import Combine
import SwiftUI

// Define the prefix used to mark disabled items
let disabledPrefix = "DISABLED::"

// Keep the helper function outside or move to a dedicated file if preferred
@MainActor
internal func checkAccessibilityPermission() -> Bool { /* ... */
    return AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
}

// MARK: - Editable Item Representation (Unchanged)
struct PresetItemRepresentation: Identifiable, Hashable {
    let id = UUID()
    let displayName: String
    var originalFragment: String
    var isEnabled: Bool = true
}

@MainActor
class PresetViewModel: ObservableObject {

    // MARK: - Published Properties (Unchanged)
    @Published var presetStore = PresetStore()
    @Published var newPresetName: String = ""
    @Published var isLoading: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String = ""
    @Published var showErrorAlert: Bool = false
    @Published var accessibilityGranted: Bool = false
    @Published var editablePresetItems: [PresetItemRepresentation] = []
    @Published var selectedPresetForEditing: DockPreset? = nil {
        didSet { updateEditableItems(for: selectedPresetForEditing) }
    }

    // MARK: - Private Properties (Unchanged)
    private let dockutilService = DockutilService()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    // MARK: - Initialization & Setup (Unchanged)
    init() { /*...*/
        presetStore.load()
        setupDebounceTimers()
        self.accessibilityGranted = checkAccessibilityPermission()
    }
    private func setupDebounceTimers() { /*...*/
        $statusMessage.debounce(for: .seconds(5), scheduler: RunLoop.main).sink { [weak self] _ in
            self?.statusMessage = ""
        }.store(in: &cancellables)
        $errorMessage.debounce(for: .seconds(10), scheduler: RunLoop.main).sink { [weak self] _ in
            if !(self?.showErrorAlert ?? false) { self?.errorMessage = "" }
        }.store(in: &cancellables)
        $showErrorAlert.filter { !$0 }.sink { [weak self] _ in self?.errorMessage = "" }.store(
            in: &cancellables)
    }

    // MARK: - Accessibility & Hotkeys (Unchanged)
    // ... checkAndSetupGlobalKeyListener, setupMonitor, removeGlobalKeyListener ...
    func checkAndSetupGlobalKeyListener() { /*...*/
        guard eventMonitor == nil else {
            self.accessibilityGranted = checkAccessibilityPermission()
            return
        }
        self.accessibilityGranted = checkAccessibilityPermission()
        if accessibilityGranted { setupMonitor() }
    }
    private func setupMonitor() { /*...*/
        removeGlobalKeyListener()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            let mod: NSEvent.ModifierFlags = [.command, .option]
            let key: UInt16 = 12
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == mod
                && event.keyCode == key
            {
                if let p = self.presetStore.presets.first { self.applyPreset(p) }
            }
        }
        if eventMonitor == nil {
            presentError("Failed event monitor install.")
        } else {
            print("Event monitor installed.")
        }
    }
    func removeGlobalKeyListener() { /*...*/
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
            print("Event monitor removed.")
        }
    }

    // MARK: - Core Actions (Unchanged - Apply already checks prefix)
    // ... saveCurrentDock, applyPreset, editPreset, duplicatePreset, deletePreset, deletePresets ...
    func saveCurrentDock() { /*...*/
        let name = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            presentError("Need name.")
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        Task {
            defer { isLoading = false }
            let result = dockutilService.listItems()
            switch result {
            case .success(let items):
                let cmds = items.map { dockutilService.constructAddCommandFragment(for: $0) }
                guard !cmds.isEmpty else {
                    presentError("Dock empty?")
                    return
                }
                let newPreset = DockPreset(name: name, addCommandFragments: cmds, shortcut: nil)
                presetStore.addPreset(newPreset)
                newPresetName = ""
            case .failure(let e): presentError("Read Dock fail: \(e.localizedDescription)")
            }
        }
    }
    func applyPreset(_ preset: DockPreset) { /* Apply checks disabledPrefix */
        guard let currentPresetData = presetStore.presets.first(where: { $0.id == preset.id })
        else {
            presentError("Preset \(preset.name) not found.")
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = ""
        Task {
            defer { isLoading = false }
            let remRes = dockutilService.removeAll(noRestart: true)
            guard case .success = remRes else {
                presentError("Clear Dock fail" + extractError(remRes))
                return
            }
            var allOk = true
            for fragment in currentPresetData.addCommandFragments {
                if fragment.hasPrefix(disabledPrefix) {
                    print("Skipping disabled: \(fragment)")
                    continue
                }
                let addRes = dockutilService.addItem(commandFragment: fragment, noRestart: true)
                if case .failure = addRes {
                    presentError("Add fail (\(fragment))" + extractError(addRes))
                    allOk = false
                    break
                }
            }
            if allOk {
                let restRes = dockutilService.restartDock()
                if case .failure = restRes {
                    presentError("Restart Dock fail" + extractError(restRes))
                }
            }
        }
    }
    func editPreset(_ preset: DockPreset) { selectedPresetForEditing = preset }
    func duplicatePreset(_ preset: DockPreset) {
        var dupe = preset
        dupe.id = UUID()
        dupe.name = "\(preset.name) Copy"
        presetStore.addPreset(dupe)
    }
    func deletePreset(_ preset: DockPreset) {
        let id = preset.id
        presetStore.deletePreset(withId: id)
        if selectedPresetForEditing?.id == id { selectedPresetForEditing = nil }
    }
    func deletePresets(at offsets: IndexSet) {
        let toDel = offsets.map { presetStore.presets[$0] }
        presetStore.deletePresets(at: offsets)
        if let selId = selectedPresetForEditing?.id, toDel.contains(where: { $0.id == selId }) {
            selectedPresetForEditing = nil
        }
    }

    // MARK: - Reordering & Editing Logic

    /// updateEditableItems (Unchanged)
    private func updateEditableItems(for preset: DockPreset?) { /* Parses prefix */
        guard let selectedPreset = preset else {
            editablePresetItems = []
            return
        }
        guard
            let currentPresetData = presetStore.presets.first(where: { $0.id == selectedPreset.id })
        else {
            editablePresetItems = []
            return
        }
        editablePresetItems = currentPresetData.addCommandFragments.map { fragment in
            let isEnabled = !fragment.hasPrefix(disabledPrefix)
            let contentFragment =
                isEnabled ? fragment : String(fragment.dropFirst(disabledPrefix.count))
            return PresetItemRepresentation(
                displayName: generateDisplayName(for: contentFragment), originalFragment: fragment,
                isEnabled: isEnabled)
        }
        print(
            "Updated editable items for \(currentPresetData.name): \(editablePresetItems.count) items"
        )
    }

    /// moveItem (Unchanged)
    func moveItem(from source: IndexSet, to destination: Int) { /* Moves originalFragments */
        editablePresetItems.move(fromOffsets: source, toOffset: destination)
        let newFragmentOrder = editablePresetItems.map { $0.originalFragment }
        guard let selectedId = selectedPresetForEditing?.id,
            let indexInStore = presetStore.presets.firstIndex(where: { $0.id == selectedId })
        else {
            presentError("Preset not found to save reorder.")
            return
        }
        presetStore.presets[indexInStore].addCommandFragments = newFragmentOrder
        print("Updated fragment order for preset \(presetStore.presets[indexInStore].name)")
        presetStore.save()
    }

    /// **MODIFIED toggleItemEnabled to fix guard let**
    func toggleItemEnabled(itemID: UUID) {
        // 1. Find index in the local editable array
        guard let indexInEditable = editablePresetItems.firstIndex(where: { $0.id == itemID })
        else { return }

        // 2. Store the *original* fragment state before toggling
        let originalFragmentWithPotentialPrefix = editablePresetItems[indexInEditable]
            .originalFragment

        // 3. Toggle the local state for immediate UI feedback
        editablePresetItems[indexInEditable].isEnabled.toggle()
        let currentIsEnabled = editablePresetItems[indexInEditable].isEnabled

        // 4. Determine the new fragment string (add or remove prefix)
        var newFragment: String
        if currentIsEnabled {
            // Remove prefix if it exists
            newFragment =
                originalFragmentWithPotentialPrefix.hasPrefix(disabledPrefix)
                ? String(originalFragmentWithPotentialPrefix.dropFirst(disabledPrefix.count))
                : originalFragmentWithPotentialPrefix
        } else {
            // Add prefix if it doesn't exist
            newFragment =
                originalFragmentWithPotentialPrefix.hasPrefix(disabledPrefix)
                ? originalFragmentWithPotentialPrefix
                : disabledPrefix + originalFragmentWithPotentialPrefix
        }

        // 5. Update the originalFragment in the local editable array
        editablePresetItems[indexInEditable].originalFragment = newFragment

        // 6. Find preset/fragment index in the store using the *original* fragment
        guard let selectedId = selectedPresetForEditing?.id,
            let indexInStore = presetStore.presets.firstIndex(where: { $0.id == selectedId }),
            // **CORRECTION:** Directly unwrap the result of firstIndex using the non-optional originalFragmentWithPotentialPrefix
            let fragmentIndexInPreset = presetStore.presets[indexInStore].addCommandFragments
                .firstIndex(of: originalFragmentWithPotentialPrefix)
        else {
            // Error handling: Couldn't find the item in the store, revert local changes
            presentError("Could not find preset or fragment in store to update toggle state.")
            // Revert local array changes
            editablePresetItems[indexInEditable].isEnabled.toggle()  // Toggle back
            editablePresetItems[indexInEditable].originalFragment =
                originalFragmentWithPotentialPrefix  // Restore original fragment
            return
        }

        // 7. Update the fragment in the persistent store
        presetStore.presets[indexInStore].addCommandFragments[fragmentIndexInPreset] = newFragment
        print("Updated fragment in store: \(newFragment)")

        // 8. Save the changes
        presetStore.save()
    }

    // MARK: - Private Helpers (Unchanged - Already handle prefix awareness where needed)
    // ... presentError, extractError, generateDisplayName, extractPathFromFragment ...
    private func presentError(_ message: String) {
        print("❌ Error: \(message)")
        self.errorMessage = message
        self.showErrorAlert = true
    }
    private func extractError<T>(_ result: Result<T, DockutilError>) -> String {
        if case .failure(let e) = result { return ": \(e.localizedDescription)" }
        return "."
    }
    private func generateDisplayName(for fragment: String) -> String { /* Handles prefix */
        let contentFragment =
            fragment.hasPrefix(disabledPrefix)
            ? String(fragment.dropFirst(disabledPrefix.count)) : fragment
        if let path = extractPathFromFragment(contentFragment) {
            let fullPath = (path as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: fullPath) {
                let name = FileManager.default.displayName(atPath: fullPath)
                if name.lowercased().hasSuffix(".app") {
                    return name.replacingOccurrences(
                        of: ".app", with: "", options: .caseInsensitive)
                }
                return name
            } else {
                return (path as NSString).lastPathComponent
            }
        } else if contentFragment.contains("--type small-spacer") {
            return "Small Spacer"
        } else if contentFragment.contains("--type spacer") {
            return "Spacer"
        }
        return contentFragment.count > 30
            ? String(contentFragment.prefix(30)) + "..." : contentFragment
    }
    private func extractPathFromFragment(_ contentFragment: String) -> String?
    { /* Expects no prefix */
        let trimmed = contentFragment.trimmingCharacters(in: .whitespaces)
        if trimmed.starts(with: "''")
            && (trimmed.contains("--type spacer") || trimmed.contains("--type small-spacer"))
        {
            return nil
        }
        if trimmed.starts(with: "'") {
            guard
                let c = trimmed.range(
                    of: "'", options: .literal,
                    range: trimmed.index(after: trimmed.startIndex)..<trimmed.endIndex)
            else { return nil }
            let p = String(trimmed[trimmed.index(after: trimmed.startIndex)..<c.lowerBound])
            return p.isEmpty ? nil : p
        } else {
            if let s = trimmed.firstIndex(of: " ") {
                let p = String(trimmed[..<s])
                let eP = (p as NSString).expandingTildeInPath
                if p.contains("/") || p.lowercased().hasSuffix(".app")
                    || FileManager.default.fileExists(atPath: eP)
                {
                    return p
                } else {
                    return nil
                }
            } else {
                let eP = (trimmed as NSString).expandingTildeInPath
                if trimmed.contains("/") || trimmed.lowercased().hasSuffix(".app")
                    || FileManager.default.fileExists(atPath: eP)
                {
                    return trimmed
                } else {
                    return nil
                }
            }
        }
    }

}  // End of PresetViewModel class
