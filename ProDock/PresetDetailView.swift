
// ProDock/PresetDetailView.swift
import SwiftUI

struct PresetDetailView: View {
    let apps: [PresetAppInfo]
    // In the future, you might add a @State var selectedAppIDs: Set<UUID> = [] here

    var body: some View {
        // Using a List for potentially scrollable content
        List {
            ForEach(apps) { appInfo in
                HStack(spacing: 10) {
                    // Checkbox (currently display-only)
                    Image(systemName: "square") // Use "checkmark.square" when selected
                        .foregroundColor(.secondary)

                    // App Icon
                    if let icon = appInfo.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                    } else {
                        // Placeholder if icon is missing
                        Image(systemName: "questionmark.app")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                    }

                    // App Label
                    Text(appInfo.label ?? "Unknown")
                        .lineLimit(1)

                    Spacer() // Pushes content to the left
                }
                .padding(.vertical, 2) // Add a little vertical padding
            }
        }
        .listStyle(.plain) // Use plain style to avoid extra borders within DisclosureGroup
        .frame(maxHeight: 200) // Limit height if needed, make it scrollable
    }
}

// Preview Provider (Optional, but helpful)
struct PresetDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Create some dummy data for the preview
        let dummyApps = [
            PresetAppInfo(path: "/System/Applications/Mail.app", label: "Mail", icon: NSWorkspace.shared.icon(forFile: "/System/Applications/Mail.app")),
            PresetAppInfo(path: "/Applications/Safari.app", label: "Safari", icon: NSWorkspace.shared.icon(forFile: "/Applications/Safari.app")),
            PresetAppInfo(path: "/Applications/Notes.app", label: "Notes", icon: NSWorkspace.shared.icon(forFile: "/Applications/Notes.app")),
            PresetAppInfo(path: "/path/does/not/exist.app", label: "Invalid App", icon: NSWorkspace.shared.icon(forFile: "/path/does/not/exist.app")),
            PresetAppInfo(path: "non-app", label: "Not An App Item", icon: NSImage(systemSymbolName: "folder", accessibilityDescription: "Folder")) // Example of non-app
        ]
        PresetDetailView(apps: dummyApps)
            .frame(width: 300) // Give the preview a reasonable width
    }
}
