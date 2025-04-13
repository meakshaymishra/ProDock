# ProDock - macOS Dock Preset Manager

[![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-purple.svg)](https://developer.apple.com/xcode/swiftui/)
<!-- Optional: Add a license badge if you choose one -->
<!-- [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) -->

Stop rearranging your macOS Dock manually! ProDock is a macOS utility application built with SwiftUI that allows you to save, manage, and quickly switch between different Dock configurations (presets), perfect for optimizing your workspace for different tasks or projects.

![ProDock UI Demo](Assets/ProDock.gif)

## Features

*   **Save Current Dock:** Capture your current Dock layout (apps, folders, stacks - excluding recent items) and save it as a named preset.
*   **Apply Presets:** Instantly switch to any saved preset with a single click on the "Apply" button next to the preset name.
*   **Manage Presets:**
    *   **View & Select Presets:** See your list of saved presets in the left-hand pane.
    *   **Duplicate:** Quickly create a copy of an existing preset.
    *   **Delete:** Remove the presets you no longer need.
*   **Edit Preset Items:**
    *   Selecting a preset in the left list displays its contents (applications, folders, spacers) in the right-hand pane.
    *   **Reorder Items:** Visually reorder items within a preset by dragging and dropping them in the right-hand editor pane. This changes the order they appear in the Dock when the preset is applied.
    *   **Enable/Disable Items:** Use the switch in the editor pane to toggle individual items ON or OFF. Disabled items (visually dimmed) will be skipped when the preset is applied.
*   **(Coming Soon) Global Hotkeys:** Option to assign a global keyboard shortcut (e.g., ⌘⌥Q) to apply a specific preset instantly (requires Accessibility permissions). *Note: Reliability may vary; current implementation applies the *first* preset only.*

## How It Works: The `dockutil` Engine

ProDock acts as a user-friendly graphical interface (GUI) for the powerful `dockutil` command-line tool created by Kyle Crawford ([kcrawford/dockutil on GitHub](https://github.com/kcrawford/dockutil)).

**All Dock manipulations** (reading the current state, removing all items, adding specific apps/folders/stacks) are performed by ProDock executing `dockutil` commands in the background via `/bin/sh -c`.

A compatible version of the `dockutil` executable is **bundled directly within the ProDock application**. This means:
* ✅ No separate installation of `dockutil` or Homebrew is required.
* ✅ ProDock uses a specific, tested version of the tool.

## Installation

**Currently, ProDock is only available by building from source.** Official releases with installers (`.pkg` or `.dmg`) are planned but not yet available.

<!--
**(Instructions When Releases Are Available):**
1.  **[WIP]Download:** Get the latest `ProDock_Installer.pkg` or `ProDock.dmg` file from the [**Releases Page**](https://github.com/meakshaymishra/prodock). *(Link currently inactive)*
2.  **Install:** Double-click the downloaded file and follow the on-screen installation instructions. ProDock will be installed in your `/Applications` folder.
3.  **First Launch:** The first time you open ProDock after downloading it, macOS Gatekeeper might show a confirmation dialog because it was downloaded from the internet. This is expected. You may need to right-click (or Control-click) the ProDock icon in `/Applications`, choose "Open", and then click "Open" in the dialog box.
-->

See **"Building from Source"** below for the current installation method.

## Usage

1.  **Launch ProDock** from your Applications folder (after building or installing). The main window will appear.
2.  **Save Preset:** Arrange your macOS Dock as desired. In the ProDock window, type a name in the "Preset Name" field (top left) and click "Save Current Dock".
3.  **Apply Preset:** Find the desired preset in the left-hand list and click its corresponding "Apply" button (green checkmark icon).
4.  **Edit Preset:**
    *   Click on a preset name in the left list to select it.
    *   The right pane will load, showing the items in that preset.
    *   **Reorder:** Click and drag items vertically in the right pane to change their order.
    *   **Enable/Disable:** Use the toggle switch next to each item in the right pane to include or exclude it when applying the preset.
5.  **Duplicate Preset:** Click the duplicate icon (two documents) next to a preset in the left list.
6.  **Delete Preset:** Click the trash icon next to a preset in the left list.
7.  **(Coming Soon) Global Shortcuts:**
    *   Grant ProDock **Accessibility access** via `System Settings > Privacy & Security > Accessibility`.
    *   The hardcoded shortcut (⌘⌥Q) will apply the *first* preset in your list.

## Requirements

*   macOS 15.0 (Sonoma) or later.
*   Xcode 16+ (or a compatible version for macOS 15 SDK) if building from source.

## Building from Source (Current Installation Method)

1.  Clone the repository: `git clone https://github.com/meakshaymishra/prodock.git`
2.  Navigate to the directory: `cd prodock`
3.  Open `ProDock.xcodeproj` in Xcode.
4.  Verify `dockutil` bundling and permissions as described previously.
5.  Select the "ProDock" scheme and "My Mac".
6.  Build and run (`Cmd+R`). The application window should open.
7.  **Important Note on Sandboxing:** Build and run using the **`Debug`** configuration. The `Release` configuration enables the App Sandbox, which prevents `dockutil` from working. See previous README versions for more details on entitlements.

## Contributing

Contributions, issues, and feature requests are welcome! Please feel free to open an issue or submit a pull request.

## License

Distributed under the [**MIT License**](LICENSE.txt).
