// ProDock/ProDock/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: PresetViewModel
    // Track which preset detail is expanded (optional, for controlling expansion)
    @State private var expandedPresetID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pro Dock")
                .font(.title)

            // List of Saved Presets using DisclosureGroup
            List {
                ForEach(viewModel.presetStore.presets) { preset in
                    DisclosureGroup(
                        isExpanded: Binding<Bool>( // Control expansion state
                            get: { self.expandedPresetID == preset.id },
                            set: { isExpanding in
                                self.expandedPresetID = isExpanding ? preset.id : nil
                            }
                        ),
                        content: { // Content shown when expanded
                            // Fetch and display the app list for the preset
                            let appInfos = viewModel.getAppsForPreset(preset)
                            if !appInfos.isEmpty {
                                PresetDetailView(apps: appInfos)
                                     // Remove default padding/inset added by DisclosureGroup content
                                     .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 0))
                            } else {
                                Text("No applications found in this preset.")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 5)
                                     .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 10, trailing: 0))
                            }
                        },
                        label: { // The clickable row for the preset
                            HStack {
                                Text(preset.name)
                                    .font(.headline) // Make preset name slightly more prominent
                                    .lineLimit(1)
                                Spacer()
                                Button("Apply") {
                                    // Prevent applying if detail is expanded (optional)
                                    if expandedPresetID != preset.id {
                                        viewModel.applyPreset(preset)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(viewModel.isLoading)
                                // Prevent disclosure group from expanding when clicking Apply
                                .onTapGesture { viewModel.applyPreset(preset) }

                                Button {
                                     // Prevent deleting if detail is expanded (optional)
                                     if expandedPresetID != preset.id {
                                         viewModel.deletePreset(preset)
                                     }
                                } label: {
                                   Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.isLoading)
                                // Prevent disclosure group from expanding when clicking Delete
                                .onTapGesture { viewModel.deletePreset(preset) }
                            }
                            .contentShape(Rectangle()) // Makes the whole HStack clickable for disclosure
                        }
                    )
                     // Add padding between disclosure groups
                     .padding(.vertical, 3)
                }
                // onDelete still works with DisclosureGroup if needed, but might be complex
                 // .onDelete(perform: viewModel.deletePresets) // Consider if this interaction is still desired
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(minHeight: 200)

            Divider()

            // Save Current Dock Section
            VStack(alignment: .leading) {
                Text("Save Current Dock as New Preset:")
                    .font(.headline)
                HStack {
                    TextField("Preset Name", text: $viewModel.newPresetName)
                        .textFieldStyle(.roundedBorder)

                    Button("Save Current Dock") {
                        viewModel.saveCurrentDock()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || viewModel.newPresetName.isEmpty)
                }
            }

            // Status/Loading Indicator & Messages
             if viewModel.isLoading {
                 ProgressView()
                     .progressViewStyle(.linear)
                     .padding(.vertical, 5)
             }

            // Combine status and error logic slightly for clarity
            let statusText = viewModel.statusMessage
            let errorText = viewModel.errorMessage
            let accessibilityWarning = !viewModel.accessibilityGranted && !errorText.contains("Accessibility")

            if !statusText.isEmpty {
                 Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

             if accessibilityWarning {
                 Text("Warning: Global shortcuts require Accessibility access (System Settings > Privacy & Security > Accessibility).")
                     .font(.caption)
                     .foregroundColor(.orange)
                     .padding(.top, 2)
             } else if !errorText.isEmpty {
                 Text(errorText)
                     .font(.caption)
                     .foregroundColor(.red)
                     .padding(.top, 2)
             }
        }
        .padding()
        .frame(minWidth: 450, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
             Button("OK", role: .cancel) { }
        } message: {
             Text(viewModel.errorMessage)
        }
        .onAppear {
            print("ContentView appeared. Setting up key listener...")
            viewModel.checkAndSetupGlobalKeyListener()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a preview VM and load some dummy data
        let previewViewModel = PresetViewModel()
        previewViewModel.presetStore.presets = [
            DockPreset(name: "Development", addCommandFragments: ["'/Applications/Xcode.app' --label 'Xcode'", "'/Applications/Visual Studio Code.app'", "'~/Downloads/' --view grid --display folder"]),
            DockPreset(name: "Design", addCommandFragments: ["'/Applications/Sketch.app'", "'/Applications/Figma.app'", "--add 'spacer-tile' --type spacer"])
        ]
        
        return ContentView()
            .environmentObject(previewViewModel)
    }
}

