import Foundation

class ClaudeThemeSync {
    private let configPath: String

    init() {
        self.configPath = NSString(string: "~/.claude.json").expandingTildeInPath
    }

    func start() {
        // Sync immediately on start
        syncTheme()

        // Listen for theme changes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleThemeChange),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil
        )

        print("Claude Theme Sync started. Listening for theme changes...")

        // Keep running
        RunLoop.current.run()
    }

    @objc private func handleThemeChange() {
        print("Theme change detected")
        syncTheme()
    }

    private func syncTheme() {
        let isDarkMode = isDarkModeEnabled()
        let theme = isDarkMode ? "dark" : "light"

        print("Setting Claude Code theme to: \(theme)")

        if updateConfig(theme: theme) {
            print("Successfully updated ~/.claude.json")
        } else {
            print("Failed to update ~/.claude.json")
        }
    }

    private func isDarkModeEnabled() -> Bool {
        let key = "AppleInterfaceStyle" as CFString
        guard let value = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? String else {
            return false
        }
        return value == "Dark"
    }

    private func updateConfig(theme: String) -> Bool {
        let fileManager = FileManager.default

        // Read existing config
        guard fileManager.fileExists(atPath: configPath),
              let data = fileManager.contents(atPath: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Error: Could not read ~/.claude.json")
            return false
        }

        // Check if theme is already correct
        if let currentTheme = json["theme"] as? String, currentTheme == theme {
            print("Theme already set to \(theme), skipping update")
            return true
        }

        // Update theme
        json["theme"] = theme

        // Write back with pretty printing to preserve readability
        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else {
            print("Error: Could not serialize JSON")
            return false
        }

        // Write atomically to prevent corruption
        do {
            try updatedData.write(to: URL(fileURLWithPath: configPath), options: .atomic)
            return true
        } catch {
            print("Error writing config: \(error)")
            return false
        }
    }
}

// Main
let sync = ClaudeThemeSync()
sync.start()
