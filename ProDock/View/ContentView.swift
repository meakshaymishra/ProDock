import AppKit
// ProDock/ProDock/View/ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: PresetViewModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) { /*...*/
                HStack {
                    Image("ProDockIcon").resizable().aspectRatio(contentMode: .fit).frame(
                        width: 30, height: 30)
                    Text("Pro Dock").font(.title2).fontWeight(.medium)
                    Spacer()
                    Button {
                        print("Settings tapped")
                    } label: {
                        Image(systemName: "gearshape").font(.title2)
                    }.buttonStyle(.plain)
                }.padding(.horizontal).padding(.vertical, 10)
                HStack {
                    TextField("Preset Name", text: $viewModel.newPresetName).textFieldStyle(
                        .roundedBorder)
                    Button("Save Current Dock") { viewModel.saveCurrentDock() }.buttonStyle(
                        .bordered
                    ).disabled(viewModel.isLoading || viewModel.newPresetName.isEmpty).controlSize(
                        .regular)
                }.padding(.horizontal).padding(.bottom, 10)
                Divider()
                List(selection: $viewModel.selectedPresetForEditing) {
                    ForEach(viewModel.presetStore.presets) { preset in
                        PresetRow(preset: preset).tag(preset)
                    }
                }.listStyle(.plain).frame(minWidth: 250)
            }.frame(maxWidth: 400)

            Divider()
            VStack(alignment: .leading) {
                if let selectedPreset = viewModel.selectedPresetForEditing {
                    Text("Edit Preset: \(selectedPreset.name)")
                        .font(.headline)
                        .padding([.top, .leading, .trailing])

                    if viewModel.editablePresetItems.isEmpty {
                        Text("Preset is empty.")
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        List {
                            ForEach(viewModel.editablePresetItems) { item in
                                PresetItemRow(item: item)  // PresetItemRow now includes dragger
                            }
                            .onMove(perform: viewModel.moveItem)
                        }
                        .listStyle(.plain)
                    }
                    Spacer()
                } else {
                    Spacer()
                    Text("Select a preset to view/edit items").font(.title2).foregroundColor(
                        .secondary
                    ).frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .controlBackgroundColor))

        }  // End Main HStack
        .frame(minWidth: 600, minHeight: 400)
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .onAppear { viewModel.checkAndSetupGlobalKeyListener() }
    }
}

// MARK: - Preset Row View (Left Pane)
struct PresetRow: View {
    let preset: DockPreset
    @EnvironmentObject private var viewModel: PresetViewModel
    private let applyButtonColor = Color.cyan
    private let iconButtonColor = Color.secondary
    var body: some View {
        HStack(spacing: 10) {
//            Image(systemName: "line.3.horizontal").foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name).fontWeight(.medium).lineLimit(1)
                Text(preset.shortcut ?? "No Shortcut").font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Apply") { viewModel.applyPreset(preset) }.buttonStyle(.borderedProminent)
                    .tint(applyButtonColor).controlSize(.small)
                Button {
                    viewModel.duplicatePreset(preset)
                } label: {
                    Image(systemName: "doc.on.doc").foregroundColor(iconButtonColor)
                }.buttonStyle(.plain).controlSize(.small).help("Duplicate Preset")
                Button {
                    viewModel.deletePreset(preset)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                }.buttonStyle(.plain).controlSize(.small).help("Delete Preset")
            }
        }.padding(.vertical, 6)
    }
}

// MARK: - Preset Item Row View (Right Pane)
struct PresetItemRow: View {
    let item: PresetItemRepresentation
    @EnvironmentObject private var viewModel: PresetViewModel

    // Custom binding
    private var bindingIsEnabled: Binding<Bool> {
        Binding(get: { item.isEnabled }, set: { _ in viewModel.toggleItemEnabled(itemID: item.id) })
    }

    // Content fragment
    private var contentFragment: String {
        item.originalFragment.hasPrefix(disabledPrefix)
            ? String(item.originalFragment.dropFirst(disabledPrefix.count))
            : item.originalFragment
    }

    var body: some View {
        HStack(spacing: 8) {  // Adjust spacing as needed
            // **NEW: Add the drag handle icon**
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .padding(.trailing, 4)  // Add a little space after the handle

            // Icon for the actual item
            iconForFragment(contentFragment)
                .frame(width: 20, height: 20)
                .opacity(item.isEnabled ? 1.0 : 0.5)

            // Display Name
            Text(item.displayName)
                .opacity(item.isEnabled ? 1.0 : 0.5)

            Spacer()  // Push toggle to the right

            // Toggle switch
            Toggle("", isOn: bindingIsEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Icon Generation Helper
    @ViewBuilder private func iconForFragment(_ contentFragment: String) -> some View { /* ... */
        if let path = extractPathFromFragment(contentFragment) {
            let fullPath = (path as NSString).expandingTildeInPath
            if path.lowercased().hasSuffix(".app")
                && FileManager.default.fileExists(atPath: fullPath)
            {
                let nsIcon = NSWorkspace.shared.icon(forFile: fullPath)
                Image(nsImage: nsIcon).resizable().aspectRatio(contentMode: .fit)
            } else {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory)
                    && isDirectory.boolValue
                {
                    Image(systemName: "folder").resizable().aspectRatio(contentMode: .fit)
                } else {
                    if FileManager.default.fileExists(atPath: fullPath) {
                        Image(systemName: "doc").resizable().aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "questionmark.diamond").resizable().aspectRatio(
                            contentMode: .fit)
                    }
                }
            }
        } else if contentFragment.contains("--type spacer")
            || contentFragment.contains("--type small-spacer")
        {
            Image(systemName: "rectangle.dashed").resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "questionmark.diamond").resizable().aspectRatio(contentMode: .fit)
        }
    }

    /// Extracts path from CONTENT fragment
    private func extractPathFromFragment(_ contentFragment: String) -> String? { /* ... */
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
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View { /* ... same preview code ... */
        let pVM = PresetViewModel()
        pVM.presetStore.presets = [
            DockPreset(
                name: "Work Apps",
                addCommandFragments: [
                    "'/Applications/Xcode.app'", "DISABLED::'/Applications/Slack.app'",
                    "'/System/Applications/Notes.app'", "'~/Documents' --view grid",
                    "'' --type spacer",
                ], shortcut: "⌘⌥W"),
            DockPreset(
                name: "Browsers",
                addCommandFragments: [
                    "'/Applications/Safari.app'", "'/Applications/Google Chrome.app'",
                ], shortcut: "⌘⌥B"),
            DockPreset(
                name: "Misc",
                addCommandFragments: [
                    "/System/Applications/Font Book.app", "'/non/existent/path'",
                ], shortcut: nil), DockPreset(name: "Empty", addCommandFragments: []),
            DockPreset(
                name: "Spacers",
                addCommandFragments: ["'' --type small-spacer", "'' --type spacer"]),
        ]
        pVM.selectedPresetForEditing = pVM.presetStore.presets.first
        return ContentView().environmentObject(pVM).preferredColorScheme(.dark)
    }
}
