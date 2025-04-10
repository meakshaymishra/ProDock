// ProDock/ProDock/View/ContentView.swift
import SwiftUI
import AppKit // Needed for NSWorkspace and NSImage

struct ContentView: View {
    @EnvironmentObject private var viewModel: PresetViewModel

    // State to hold the extracted app names for the selected preset
    @State private var applicationNames: [String] = []

    var body: some View {
        HStack(spacing: 0) { // Main Horizontal Layout for two panes
            // --- Left Pane ---
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Image("ProDockIcon") // Assumes AppIcon exists in assets
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                    Text("Pro Dock")
                        .font(.title2)
                        .fontWeight(.medium)
                    Spacer()
                    Button {
                        // TODO: Implement Settings Action
                        print("Settings button tapped")
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Save Preset Area
                HStack {
                    TextField("Preset Name", text: $viewModel.newPresetName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Current Dock") {
                        viewModel.saveCurrentDock()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading || viewModel.newPresetName.isEmpty)
                    .controlSize(.regular)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)

                Divider()

                // Preset List
                List(selection: $viewModel.selectedPresetForEditing) {
                    ForEach(viewModel.presetStore.presets) { preset in
                        PresetRow(preset: preset)
                            .tag(preset) // Make the preset identifiable for selection
                    }
                }
                .listStyle(.plain)
                .frame(minWidth: 250)
            }
            .frame(maxWidth: 400)

            Divider() // Vertical divider between panes

            // --- Right Pane ---
            VStack(alignment: .leading) { // Align content to leading edge
                if let selectedPreset = viewModel.selectedPresetForEditing {
                    Text("Applications in Preset: \(selectedPreset.name)")
                        .font(.headline)
                        .padding([.top, .leading, .trailing]) // Add padding around title

                    // Display the list of extracted application names
                    if applicationNames.isEmpty {
                        Text("No applications found in this preset.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center) // Center placeholder
                    } else {
                        List {
                            ForEach(applicationNames, id: \.self) { appName in
                                Text(appName)
                            }
                        }
                        .listStyle(.plain) // Match left pane style
                    }
                    Spacer() // Push list upwards
                } else {
                    // Show placeholder when no preset is selected
                    Spacer()
                    Text("Select a preset to view its applications")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))

        } // End of Main HStack
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
             Button("OK", role: .cancel) { }
        } message: {
             Text(viewModel.errorMessage)
        }
        .onAppear {
            viewModel.checkAndSetupGlobalKeyListener()
        }
        // **Add onChange listener to update the app list when selection changes**
        .onChange(of: viewModel.selectedPresetForEditing) { _, newPreset in
            updateApplicationList(for: newPreset)
        }
    }

    // MARK: - Application List Helper

    /// Updates the `applicationNames` state based on the selected preset.
    private func updateApplicationList(for preset: DockPreset?) {
        guard let selectedPreset = preset else {
            applicationNames = [] // Clear list if no preset is selected
            return
        }

        applicationNames = selectedPreset.addCommandFragments.compactMap { fragment in
            // Try extracting the path
            guard let path = extractPathFromFragment(fragment) else { return nil }

            let fullPath = (path as NSString).expandingTildeInPath

            // Check if it looks like an application bundle path
            guard path.lowercased().hasSuffix(".app") else { return nil }

            // Verify it actually exists (optional but good practice)
             var isDirectory: ObjCBool = false
             guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }

            // Get the user-friendly display name
            return FileManager.default.displayName(atPath: fullPath)
        }
         print("Updated app list for \(selectedPreset.name): \(applicationNames)")
    }

    // MARK: - Icon Helper Functions (Unchanged)
    // ... (presetIconView, appIcon, defaultIcon functions remain the same) ...
     @ViewBuilder
    private func presetIconView(for preset: DockPreset) -> some View {
        if let firstFragment = preset.addCommandFragments.first,
           let path = extractPathFromFragment(firstFragment) {
            let fullPath = (path as NSString).expandingTildeInPath
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    if path.lowercased().hasSuffix(".app") {
                        appIcon(forPath: fullPath) // Returns some View
                    } else {
                        Image(systemName: "folder")
                            .resizable().aspectRatio(contentMode: .fit).foregroundColor(.secondary)
                    }
                } else {
                     if path.lowercased().hasSuffix(".app") {
                         appIcon(forPath: fullPath) // Returns some View
                     } else {
                         defaultIcon() // Returns some View
                     }
                }
            } else {
                if firstFragment.contains("--type spacer") {
                     Image(systemName: "rectangle.dashed")
                         .resizable().aspectRatio(contentMode: .fit).foregroundColor(.secondary)
                } else {
                    defaultIcon() // Returns some View
                }
            }
        } else {
            if let firstFragment = preset.addCommandFragments.first, firstFragment.contains("--type spacer") {
                Image(systemName: "rectangle.dashed")
                    .resizable().aspectRatio(contentMode: .fit).foregroundColor(.secondary)
            } else {
                 defaultIcon() // Returns some View
            }
        }
    }

    private func appIcon(forPath path: String) -> some View {
        let icon = NSWorkspace.shared.icon(forFile: path)
        return Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private func defaultIcon() -> some View {
        Image(systemName: "square.grid.3x2")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(.secondary)
    }


    // MARK: - Path Extraction Helper (Unchanged)
    private func extractPathFromFragment(_ fragment: String) -> String? {
        let trimmed = fragment.trimmingCharacters(in: .whitespaces)
        if trimmed.starts(with: "''") && trimmed.contains("--type spacer") { return nil }
        if trimmed.starts(with: "'") {
            guard let closingQuoteRange = trimmed.range(of: "'", options: .literal, range: trimmed.index(after: trimmed.startIndex)..<trimmed.endIndex) else { return nil }
            let path = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closingQuoteRange.lowerBound])
            return path.isEmpty ? nil : path
        } else {
            if let firstSpace = trimmed.firstIndex(of: " ") {
                let potentialPath = String(trimmed[..<firstSpace])
                 let expandedPath = (potentialPath as NSString).expandingTildeInPath
                 if potentialPath.contains("/") || potentialPath.lowercased().hasSuffix(".app") || FileManager.default.fileExists(atPath: expandedPath) { return potentialPath } else { return nil }
            } else {
                 let expandedPath = (trimmed as NSString).expandingTildeInPath
                 if trimmed.contains("/") || trimmed.lowercased().hasSuffix(".app") || FileManager.default.fileExists(atPath: expandedPath) { return trimmed } else { return nil }
            }
        }
    }
}

// MARK: - Preset Row View (Unchanged)
struct PresetRow: View {
    let preset: DockPreset
    @EnvironmentObject private var viewModel: PresetViewModel

    private let applyButtonColor = Color.cyan
    private let iconButtonColor = Color.secondary

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(preset.shortcut ?? "No Shortcut")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Apply") { viewModel.applyPreset(preset) }
                    .buttonStyle(.borderedProminent).tint(applyButtonColor).controlSize(.small)
                Button { viewModel.duplicatePreset(preset) } label: { Image(systemName: "doc.on.doc").foregroundColor(iconButtonColor) }
                    .buttonStyle(.plain).controlSize(.small).help("Duplicate Preset")
                Button { viewModel.deletePreset(preset) } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.red) }
                    .buttonStyle(.plain).controlSize(.small).help("Delete Preset")
            }
        }
        .padding(.vertical, 6)
    }
}


// MARK: - Preview (Unchanged)
struct ContentView_Previews: PreviewProvider {
     static var previews: some View {
        let previewViewModel = PresetViewModel()
        previewViewModel.presetStore.presets = [
            // Add sample fragments that represent apps for preview
            DockPreset(name: "Work Apps", addCommandFragments: ["'/Applications/Xcode.app'", "'/Applications/Slack.app'", "'/System/Applications/Notes.app'", "'~/Documents' --view grid"], shortcut: "⌘⌥W"),
            DockPreset(name: "Browsers", addCommandFragments: ["'/Applications/Safari.app'", "'/Applications/Google Chrome.app'"], shortcut: "⌘⌥B"),
            DockPreset(name: "Empty", addCommandFragments: []),
            DockPreset(name: "Spacers", addCommandFragments: ["'' --type spacer"])

        ]

        return ContentView()
            .environmentObject(previewViewModel)
            .preferredColorScheme(.dark)
    }
}
