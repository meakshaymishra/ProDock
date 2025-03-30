// DockutilService.swift

import Foundation
import AppKit // Only needed if using NSWorkspace, otherwise can be removed

// MARK: - Error Definition

enum DockutilError: Error, LocalizedError {
    case toolNotFound(String)
    case executionError(Int32, String) // status code, error message from stderr or stdout
    case outputParsingError(String)
    case commandConstructionError(String) // Error constructing fragment or command

    var errorDescription: String? {
        switch self {
        case .toolNotFound(let path):
            return "dockutil command-line tool not found or not executable at expected path: \(path)."
        case .executionError(let status, let message):
            // Clean up message slightly
            let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
            let statusMsg = "dockutil (or shell) execution failed with status \(status)."
            return "\(statusMsg) \(cleanMessage.isEmpty ? "(No specific error message)" : "Error: \(cleanMessage)")"
        case .outputParsingError(let details):
            return "Failed to parse dockutil output: \(details)"
        case .commandConstructionError(let details):
            return "Failed to construct command or fragment: \(details)"
        }
    }
}

// MARK: - Parsed Item Model

/// Represents a parsed item from 'dockutil --list' output, after cleaning.
struct ParsedDockItem: Hashable {
    let label: String
    let pathOrIdentifier: String // Cleaned path/identifier (e.g., /Apps/App.app, ~/Downloads, spacer-tile)
    let options: String?         // Raw options string from dockutil --list (plist-like), used for reconstructing add options
}

// MARK: - Dockutil Service

struct DockutilService {

    // --- Configuration: Path to dockutil ---
    // Assumes bundled executable
    private var dockutilPath: String? = {
        guard let path = Bundle.main.path(forResource: "dockutil", ofType: nil) else {
            print("❌ Error: dockutil executable not found in Bundle Resources.")
            return nil
        }
        guard FileManager.default.isExecutableFile(atPath: path) else {
            print("❌ Error: Found dockutil at \(path), but it lacks execute permissions. Ensure 'chmod +x' was run in Build Phases.")
            return nil
        }
        print("✅ Found executable dockutil at: \(path)")
        return path
    }()

    // --- Core Execution Helper (Private) ---

    /// Executes a complete command string using /bin/sh -c
    private func runShellCommand(command: String) -> Result<String, DockutilError> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Arguments for sh: "-c" means "read commands from the next argument"
        process.arguments = ["-c", command]

        // Setup pipes for output/error
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            print("🐚 Executing via Shell: \(command)") // Log the command being run
            try process.run()
            process.waitUntilExit()

            // Read data from pipes
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            let trimmedError = errorString.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedOutput = outputString.trimmingCharacters(in: .whitespacesAndNewlines)

            if process.terminationStatus == 0 {
                // Success, log any non-fatal stderr warnings
                if !trimmedError.isEmpty { print("⚠️ Shell stderr (non-fatal): \(trimmedError)") }
                return .success(trimmedOutput) // Return stdout content
            } else {
                // Failure, log details
                print("❌ Shell command failed! Status: \(process.terminationStatus)")
                print("   Command: \(command)")
                print("   stdout: \(outputString)")
                print("   stderr: \(errorString)")
                // Return error, prioritizing stderr, then stdout, then a generic message
                let errorMessage = !trimmedError.isEmpty ? trimmedError : (!trimmedOutput.isEmpty ? trimmedOutput : "Shell command failed (\(process.terminationStatus))")
                return .failure(.executionError(process.terminationStatus, errorMessage))
            }
        } catch {
            print("❌ Failed to run shell process: \(error)")
            return .failure(.executionError(-1, "Failed to launch /bin/sh: \(error.localizedDescription)"))
        }
    }

    // --- Parsing and Command Construction Helpers ---

    /// Parses the raw multiline output string from `dockutil --list`, filtering unwanted items.
    private func parseListOutput(rawOutput: String) -> Result<[ParsedDockItem], DockutilError> {
        var items: [ParsedDockItem] = []
        let lines = rawOutput.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for (index, line) in lines.enumerated() {
            let components = line.split(separator: "\t", maxSplits: 3).map(String.init)
            guard components.count >= 2 else { continue } // Skip malformed

            let label = components[0]
            let pathOrIdRaw = components[1] // Raw path string from dockutil
            let options = components.count > 3 ? components[3] : nil

            // --- Filtering based on RAW pathOrId or options ---
            if let opts = options, opts.contains("\"tile-type\" = \"recent-tile\";") { continue } // Filter Recents
            if pathOrIdRaw.starts(with: "file:///\\'/") && pathOrIdRaw.hasSuffix("\\'") { continue } // Filter weird quoted running apps
            // Optional: Filter Finder/Trash
            // if (label == "Finder" || label == "Trash") && pathOrIdRaw.starts(with: "persistent://") { continue }
            // --- End Filtering ---

            // --- Path/Identifier Cleanup (applied only to items *not* filtered out) ---
            var cleanedPathOrId = pathOrIdRaw
            if cleanedPathOrId.hasPrefix("file://") {
                if let url = URL(string: cleanedPathOrId), url.isFileURL {
                    cleanedPathOrId = url.path.removingPercentEncoding ?? url.path
                    let homeURL: URL = FileManager.default.homeDirectoryForCurrentUser // Assumes non-optional based on user's build env
                    let homeDir: String = homeURL.path
                    if cleanedPathOrId.hasPrefix(homeDir) {
                        cleanedPathOrId = cleanedPathOrId.replacingOccurrences(of: homeDir, with: "~", options: .anchored)
                        if cleanedPathOrId == "~/" && homeDir != "/" { cleanedPathOrId = "~" }
                    }
                } else {
                    print("⚠️ Could not parse file URL: \(cleanedPathOrId), using raw value.")
                    cleanedPathOrId = pathOrIdRaw // Fallback to raw value if parsing fails
                }
            } // --- End Path Cleanup ---

            // Use the original label but the potentially cleaned path/id
            items.append(ParsedDockItem(label: label, pathOrIdentifier: cleanedPathOrId, options: options))
        }
        // Could add an error check here if items array is unexpectedly empty
        return .success(items)
    }


    /// Constructs the argument fragment string (path + options) for `dockutil --add`.
    /// This string will be saved in presets and needs quoting suitable for shell execution.
    func constructAddCommandFragment(for item: ParsedDockItem) -> String {
        var commandParts: [String] = []

        // --- 1. Handle Path or Spacer Type ---
        if item.pathOrIdentifier == "spacer-tile" || item.label == "Spacer" {
             // Use literal empty single quotes for dockutil add '' --type ...
             commandParts.append("''")
             if item.options?.contains("small-spacer-tile") == true {
                  commandParts.append("--type small-spacer")
             } else {
                  commandParts.append("--type spacer")
             }
        } else {
            // --- Path Quoting Logic for Shell Fragment String ---
            var path = item.pathOrIdentifier // Path should be cleaned by parseListOutput

            // Defensive trim again in case cleaning left artifacts
            path = path.trimmingCharacters(in: CharacterSet(charactersIn: "\"'\\"))

            let hasSpace = path.contains(" ")
            let isJustTilde = (path == "~")

            // Add literal single quotes using concatenation if path has space and isn't just "~"
            if hasSpace && !isJustTilde {
                // Escape any literal single quotes *within* the path if needed
                // path = path.replacingOccurrences(of: "'", with: "'\\''") // For paths like "App With ' Name"
                // Simple case: Assume paths don't contain single quotes for now
                path = "'" + path + "'"
            }
            commandParts.append(path)
            // --- End Path Quoting ---
        }

        // --- 2. Parse Common Options from plist string ---
        if let optionsString = item.options {
            if optionsString.contains("\"showas\" = 1;") { commandParts.append("--view grid") }
            else if optionsString.contains("\"showas\" = 2;") { commandParts.append("--view list") }
            else if optionsString.contains("\"showas\" = 3;") { commandParts.append("--view fan") }

            if optionsString.contains("file-type\" = 2;") { // Check if it's a folder tile
                if optionsString.contains("\"viewas\" = 1;") { commandParts.append("--display folder") }
                else if optionsString.contains("\"viewas\" = 2;") { commandParts.append("--display stack") }
            }

             if optionsString.contains("\"arrangement\" = 1;") { commandParts.append("--sort name") }
             else if optionsString.contains("\"arrangement\" = 2;") { commandParts.append("--sort dateadded") }
             else if optionsString.contains("\"arrangement\" = 3;") { commandParts.append("--sort datemodified") }
             else if optionsString.contains("\"arrangement\" = 4;") { commandParts.append("--sort datecreated") }
             else if optionsString.contains("\"arrangement\" = 5;") { commandParts.append("--sort kind") }
             // arrangement = 0 (None) is default
        }

        // --- 3. Reconstruct the fragment string ---
        // e.g., "'/Path/With Space.app'", or "'~/Docs' --view grid" or "'' --type spacer"
        return commandParts.joined(separator: " ")
    }


    // --- Public API Methods ---

    /// Fetches current Dock items via shell, parses, and filters them.
    func listItems() -> Result<[ParsedDockItem], DockutilError> {
        guard let cmdPath = self.dockutilPath else { return .failure(.toolNotFound("Path missing")) }
        // Quote the command path in case the bundle path has spaces (unlikely but safe)
        let listCommand = "'\(cmdPath)' --list --no-restart"
        let result = runShellCommand(command: listCommand)
        switch result {
        case .success(let output):
            return parseListOutput(rawOutput: output) // Parse the shell output
        case .failure(let error):
            print("Error listing items via shell: \(error)")
            return .failure(error) // Return the shell execution error
        }
    }

    /// Removes all user-added items from the Dock via shell.
    func removeAll(noRestart: Bool = false) -> Result<String, DockutilError> {
        guard let cmdPath = self.dockutilPath else { return .failure(.toolNotFound("Path missing")) }
        var command = "'\(cmdPath)' --remove all"
        if noRestart { command += " --no-restart" }
        return runShellCommand(command: command)
    }

    /// Adds a single item using the shell (/bin/sh -c) via a pre-formatted command fragment.
    func addItem(commandFragment: String, noRestart: Bool = false) -> Result<String, DockutilError> {
        guard let cmdPath = self.dockutilPath else { return .failure(.toolNotFound("Path missing")) }
        let trimmedFragment = commandFragment.trimmingCharacters(in: .whitespaces)

        guard !trimmedFragment.isEmpty else {
            return .failure(.commandConstructionError("Cannot add item with empty command fragment."))
        }

        // The fragment should already be properly quoted by constructAddCommandFragment
        var fullCommand = "'\(cmdPath)' --add \(trimmedFragment)"
        if noRestart {
            fullCommand += " --no-restart"
        }

        // Execute via shell
        return runShellCommand(command: fullCommand)
    }


    /// Restarts the Dock process via shell using killall.
    func restartDock() -> Result<String, DockutilError> {
        // killall path is standard, no special quoting needed typically
        let command = "/usr/bin/killall Dock"
        print("🔄 Restarting Dock via: \(command)")
        return runShellCommand(command: command)
    }

}
// End of DockutilService struct
