// ProDock/ProDock/ContentView.swift
import SwiftUI

struct ContentView: View {
    // Get the ViewModel from the Environment - DO NOT use @StateObject here
    @EnvironmentObject private var viewModel: PresetViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pro Dock")
                .font(.title)

            // List of Saved Presets
            List {
                // Use the viewModel from the environment
                ForEach(viewModel.presetStore.presets) { preset in
                    HStack {
                        Text(preset.name)
                            .lineLimit(1)
                        Spacer()
                        Button("Apply") {
                            viewModel.applyPreset(preset)
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isLoading)

                        Button {
                           viewModel.deletePreset(preset)
                        } label: {
                           Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoading)
                    }
                }
                .onDelete(perform: viewModel.deletePresets)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(minHeight: 200)

            Divider()

            // Save Current Dock Section
            VStack(alignment: .leading) {
                Text("Save Current Dock as New Preset:")
                    .font(.headline)
                HStack {
                    // Use the viewModel from the environment
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
            // Perform the setup when the view appears
            print("ContentView appeared. Setting up key listener...")
            // Use the viewModel from the environment
            viewModel.checkAndSetupGlobalKeyListener()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a dummy VM *only* for the preview
        ContentView()
            .environmentObject(PresetViewModel())
    }
}
