# ProDock - macOS Dock Preset Manager

[![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-purple.svg)](https://developer.apple.com/xcode/swiftui/)
<!-- Optional: Add a license badge if you choose one -->
<!-- [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) -->

Stop rearranging your macOS Dock manually! ProDock is a simple macOS application built with SwiftUI that allows you to save, manage, and quickly switch between different Dock configurations (presets), perfect for optimizing your workspace for different tasks or projects.

![ProDock in Work](Assets/ProDock.gif)

## Features

*   **Save Current Dock:** Capture your current Dock layout (apps, folders, stacks - excluding recent items) and save it as a named preset.
*   **Apply Presets:** Instantly switch to any saved preset with a single click.
*   **Manage Presets:** View your list of saved presets and delete ones you no longer need.
*   **Default Reset:** Quickly reset your Dock to a predefined default configuration (customizable in code).
*   **(Experimental) Global Hotkeys:** Option to assign a global keyboard shortcut (e.g., ⌘⌥Q) to apply a specific preset instantly (requires Accessibility permissions). *Note: Reliability may vary depending on system configuration.*

## How It Works: The `dockutil` Engine

ProDock acts as a user-friendly graphical interface (GUI) for the powerful `dockutil` command-line tool created by Kyle Crawford ([kcrawford/dockutil on GitHub](https://github.com/kcrawford/dockutil)).

**All Dock manipulations** (reading the current state, removing all items, adding specific apps/folders/stacks) are performed by ProDock executing `dockutil` commands in the background via `/bin/sh -c`.

A compatible version of the `dockutil` executable is **bundled directly within the ProDock application**. This means:
✅ No separate installation of `dockutil` or Homebrew is required.
✅ ProDock uses a specific, tested version of the tool.

## Installation

ProDock is distributed as a standalone application outside the Mac App Store.

1.  **[WIP]Download:** Get the latest `ProDock_Installer.pkg` file from the [**Releases Page**](https://github.com/meakshaymishra/prodock).
2.  **Install:** Double-click the downloaded `.pkg` file and follow the on-screen installation instructions. ProDock will be installed in your `/Applications` folder.
3.  **First Launch:** The first time you open ProDock after downloading it, macOS Gatekeeper might show a confirmation dialog because it was downloaded from the internet. This is expected. Right-click (or Control-click) the ProDock icon in `/Applications`, choose "Open", and then click "Open" in the dialog box.

## Usage

1.  **Launch ProDock** from your Applications folder.
2.  **Save Current Dock:** Arrange your Dock as desired. Type a descriptive name for this layout in the "Preset Name" field and click "Save Current Dock". The app will read your *cleaned* Dock state (excluding recent items and potentially problematic duplicates) and save it.
3.  **Apply Preset:** Find the preset you want in the list and click the "Apply" button next to it. The app will clear your current Dock (user items) and apply the selected preset. The Dock will restart automatically.
4.  **Delete Preset:** Click the Trash icon next to a preset you want to remove, or swipe-to-delete on the list item.
5.  **Reset to Default:** Click the "Reset Dock to Default" button (you'll be asked to confirm) to apply the built-in default preset.
6.  **(Optional) Global Shortcuts:** If you want to use global shortcuts:
    *   You **must grant ProDock Accessibility access**. Go to `System Settings > Privacy & Security > Accessibility`. Click the `+` button, navigate to `/Applications`, select `ProDock`, and click "Open". You may need to authenticate with your password.
    *   *Note:* The current implementation assigns a fixed shortcut (e.g., ⌘⌥Q) to apply the *first* preset in your list. More advanced shortcut customization might be added later.

## Requirements

*   macOS 15.0 (Sonoma) or later.

## Building from Source (Optional)

1.  Clone the repository: `git clone https://github.com/meakshaymishra/prodock.git` 
2.  Open `ProDock.xcodeproj` in Xcode (ensure you have a compatible version, e.g., Xcode 15+ for macOS 15).
3.  Verify `dockutil`: Ensure the `dockutil` executable file is correctly referenced in the project navigator and included in the "Copy Bundle Resources" build phase for the "ProDock" target. The associated "Run Script" phase (`chmod +x ...`) must also be present to make it executable.
4.  Select the "ProDock" scheme and choose "My Mac" as the run destination.
5.  Build and run (`Cmd+R`).
6.  **Note:** The project is currently configured to run **without the App Sandbox** enabled in the `Debug` configuration (`ProDockDebug.entitlements`) for easier testing. The `Release` configuration might have different entitlements (`ProDock.entitlements`).

## Contributing

Contributions, issues, and feature requests are welcome! Please feel free to open an issue or submit a pull request.

## License

Distributed under the [**MIT License**](LICENSE.txt). *(<- Choose a license, create a LICENSE.txt file, and update this link! If no license, remove this section or state "All rights reserved.")*
